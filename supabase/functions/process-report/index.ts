import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================
// LỚP 2 — BỊ ĐỘNG (PROCESS-REPORT EDGE FUNCTION)
// Chạy khi có người dùng báo cáo (Report) nội dung của người khác.
// Tự động tính điểm ưu tiên (Priority Score) cho Hàng đợi Admin kiểm duyệt.
// ============================================================

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const TABLE_MAP: Record<string, { table: string; idColumn: string }> = {
  post: { table: "posts", idColumn: "post_id" },
  comment: { table: "comments", idColumn: "comment_id" },
  message: { table: "messages", idColumn: "message_id" },
};

const WEIGHT_AI_SCORE = 60;
const WEIGHT_DUPLICATE_REPORTS = 6;
const WEIGHT_LOW_TRUST_REPORTER = 10;
const MAX_DUPLICATE_COUNT = 5;
const AUTO_ESCALATE_THRESHOLD = 90;

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { report_id } = await req.json();
    if (!report_id) {
      return new Response(JSON.stringify({ error: "Thiếu report_id" }), { status: 400, headers: corsHeaders });
    }

    // 1. Lấy thông tin bản ghi báo cáo từ bảng reports
    const { data: report, error: reportErr } = await supabase
      .from("reports")
      .select("id, content_type, target_id, reporter_id, created_at")
      .eq("id", report_id)
      .single();
    if (reportErr) throw reportErr;

    const mapping = TABLE_MAP[report.content_type as keyof typeof TABLE_MAP];
    if (!mapping) throw new Error(`content_type không hợp lệ: ${report.content_type}`);
    const { table, idColumn } = mapping;

    // 2. Điểm AI đã chấm sẵn từ Lớp 1 (moderate-content) — không gọi lại Gemini để tiết kiệm chi phí
    const { data: item, error: itemErr } = await supabase
      .from(table)
      .select("ai_moderation_score, ai_moderation_labels")
      .eq("id", report.target_id)
      .single();
    if (itemErr) throw itemErr;

    const aiScore = item.ai_moderation_score ?? 0;

    // 3. Đếm số lượng báo cáo trùng lặp cho cùng 1 nội dung trong 24 giờ qua
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const { count: duplicateCount, error: countErr } = await supabase
      .from("reports")
      .select("id", { count: "exact", head: true })
      .eq("content_type", report.content_type)
      .eq("target_id", report.target_id)
      .gte("created_at", since);
    if (countErr) throw countErr;

    // 4. Lấy điểm uy tín (trust_score) của người báo cáo từ bảng profiles
    const { data: reporter, error: reporterErr } = await supabase
      .from("profiles") // Đã sửa từ 'users' thành 'profiles' cho chuẩn với Database
      .select("trust_score")
      .eq("id", report.reporter_id)
      .single();
    if (reporterErr) throw reporterErr;

    const trustScore = reporter.trust_score ?? 0.5;

    // 5. Tính toán điểm ưu tiên (Priority Score 0 - 100)
    const duplicateFactor = Math.min(duplicateCount ?? 0, MAX_DUPLICATE_COUNT);
    const priorityRaw =
      aiScore * WEIGHT_AI_SCORE +
      duplicateFactor * WEIGHT_DUPLICATE_REPORTS +
      (1 - trustScore) * WEIGHT_LOW_TRUST_REPORTER;
    const priority = Math.min(Math.round(priorityRaw), 100);

    // 6. Cập nhật kết quả vào bảng reports cho hàng đợi Admin
    const { error: updateErr } = await supabase
      .from("reports")
      .update({
        ai_severity_score: aiScore,
        ai_labels: item.ai_moderation_labels,
        priority,
        updated_at: new Date().toISOString(),
      })
      .eq("id", report_id);
    if (updateErr) throw updateErr;

    // 7. Nếu Priority >= 90: Tự động bóp tương tác khẩn cấp (Shadow Limit) trong lúc chờ Admin duyệt
    if (priority >= AUTO_ESCALATE_THRESHOLD) {
      await supabase
        .from(table)
        .update({ moderation_status: "shadow_limited" })
        .eq("id", report.target_id)
        .eq("moderation_status", "published");

      await supabase.from("moderation_actions").insert({
        content_type: report.content_type,
        [idColumn]: report.target_id,
        report_id,
        action_type: "auto_shadow_limit",
        reason: `Priority ${priority} vượt ngưỡng tự động — ${duplicateFactor} report/24h, AI score ${aiScore}`,
        is_automated: true,
      });
    }

    return new Response(
      JSON.stringify({ report_id, priority, aiScore, duplicateCount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    console.error("Process Report Error:", err);
    return new Response(JSON.stringify({ error: err.message || String(err) }), {
      status: 500, headers: corsHeaders,
    });
  }
});
