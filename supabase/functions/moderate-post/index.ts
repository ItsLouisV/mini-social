import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ============================================================
// MODERATE-POST EDGE FUNCTION (SINGLE FILE STANDALONE VERSION)
// Dễ dàng deploy bằng CLI hoặc Copy-Paste trực tiếp lên Supabase Dashboard Web UI
// ============================================================

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ------------------------------------------------------------
// 1. TABLE MAPPING & HELPERS
// ------------------------------------------------------------

export interface TableMapItem {
  table: string;
  idColumn: string;
  userColumn: string;
}

const TABLE_MAP: Record<string, TableMapItem> = {
  post: { table: "posts", idColumn: "post_id", userColumn: "user_id" },
  comment: { table: "comments", idColumn: "comment_id", userColumn: "user_id" },
  message: { table: "messages", idColumn: "message_id", userColumn: "sender_id" },
};

function isValidContentType(type: string): type is keyof typeof TABLE_MAP {
  return type in TABLE_MAP;
}

const THRESHOLD_AUTO_BLOCK = 0.85;
const THRESHOLD_SHADOW_LIMIT = 0.5;

function decideStatus(score: number): "published" | "shadow_limited" | "hidden" {
  if (score >= THRESHOLD_AUTO_BLOCK) return "hidden";
  if (score >= THRESHOLD_SHADOW_LIMIT) return "shadow_limited";
  return "published";
}

// ------------------------------------------------------------
// 2. KEYWORD FILTER
// ------------------------------------------------------------

function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFC")
    .replace(/[.\-_*+~`'"!@#$%^&()[\]{}|\\/:;<>,?=]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

interface KeywordRow {
  pattern: string;
  match_type: "exact" | "regex";
  severity: "zero_tolerance" | "flag_for_review";
  category: string;
}

function checkKeywords(rawText: string, keywords: KeywordRow[]) {
  const normalized = normalizeText(rawText);
  for (const kw of keywords) {
    let isMatch = false;
    if (kw.match_type === "exact") {
      isMatch = normalized.includes(normalizeText(kw.pattern));
    } else {
      try {
        isMatch = new RegExp(kw.pattern, "i").test(rawText);
      } catch (err) {
        console.error(`Invalid regex pattern: "${kw.pattern}"`, err);
      }
    }
    if (isMatch) {
      return { matched: true, severity: kw.severity, pattern: kw.pattern, category: kw.category };
    }
  }
  return { matched: false, severity: null, pattern: null, category: null };
}

// ------------------------------------------------------------
// 3. GEMINI AI SAFETY CHECK
// ------------------------------------------------------------

const PROBABILITY_SCORE: Record<string, number> = {
  NEGLIGIBLE: 0.05,
  LOW: 0.35,
  MEDIUM: 0.65,
  HIGH: 0.95,
};

const CATEGORY_TO_REASON: Record<string, string> = {
  HARM_CATEGORY_HARASSMENT: "harassment",
  HARM_CATEGORY_HATE_SPEECH: "hate_speech",
  HARM_CATEGORY_SEXUALLY_EXPLICIT: "nudity_sexual",
  HARM_CATEGORY_DANGEROUS_CONTENT: "violence_gore",
};

async function checkGeminiSafety(text: string, imageBase64?: string, imageMimeType?: string) {
  if (!GEMINI_API_KEY) {
    return { severityScore: 0, labels: {} };
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

  const parts: any[] = [{ text: text || "" }];
  if (imageBase64) {
    parts.push({ inline_data: { mime_type: imageMimeType || "image/jpeg", data: imageBase64 } });
  }

  const safetySettings = [
    "HARM_CATEGORY_HARASSMENT",
    "HARM_CATEGORY_HATE_SPEECH",
    "HARM_CATEGORY_SEXUALLY_EXPLICIT",
    "HARM_CATEGORY_DANGEROUS_CONTENT",
  ].map((category) => ({ category, threshold: "BLOCK_LOW_AND_ABOVE" }));

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts }],
      safetySettings,
      generationConfig: { maxOutputTokens: 1 },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini safety check error: ${res.status} ${await res.text()}`);
  }

  const json = await res.json();
  const feedback = json.promptFeedback;

  if (feedback?.blockReason) {
    return { severityScore: 1.0, labels: { blocked_by_gemini: feedback.blockReason } };
  }

  const ratings = json.candidates?.[0]?.safetyRatings ?? feedback?.safetyRatings ?? [];
  const labels: Record<string, number> = {};
  let maxScore = 0;

  for (const r of ratings) {
    const score = PROBABILITY_SCORE[r.probability] ?? 0;
    const reasonKey = CATEGORY_TO_REASON[r.category] ?? r.category;
    labels[reasonKey] = score;
    if (score > maxScore) maxScore = score;
  }

  return { severityScore: maxScore, labels };
}

// ------------------------------------------------------------
// 4. MAIN HANDLER
// Body: { content_type: 'post'|'comment'|'message', target_id: string,
//         content?: string, image_urls?: string[] }
// ------------------------------------------------------------

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const { content_type, target_id, content, image_urls = [] } = await req.json();

    if (!content_type || !isValidContentType(content_type) || !target_id) {
      return new Response(JSON.stringify({ error: "content_type hoặc target_id không hợp lệ" }), {
        status: 400, headers: corsHeaders,
      });
    }
    if (!content && image_urls.length === 0) {
      return new Response(JSON.stringify({ error: "Không có nội dung để kiểm duyệt" }), {
        status: 400, headers: corsHeaders,
      });
    }

    const { table, idColumn, userColumn } = TABLE_MAP[content_type];

    // Lấy ID người dùng sở hữu nội dung (phục vụ ghi log vi phạm)
    const { data: targetRecord } = await supabase
      .from(table)
      .select(userColumn || "user_id")
      .eq("id", target_id)
      .maybeSingle();

    const targetUserId = targetRecord ? targetRecord[userColumn || "user_id"] : null;

    // ---- Bước 1: Keyword filter (rẻ, tức thì) ----
    if (content && content.trim().length > 0) {
      const { data: keywords } = await supabase
        .from("banned_keywords")
        .select("pattern, match_type, severity, category")
        .eq("is_active", true);

      const kwResult = checkKeywords(content, keywords ?? []);

      if (kwResult.matched && kwResult.severity === "zero_tolerance") {
        await supabase.from(table).update({
          moderation_status: "hidden",
          ai_moderation_score: 1.0,
          ai_moderation_labels: { keyword_match: kwResult.pattern },
          moderated_at: new Date().toISOString(),
        }).eq("id", target_id);

        await supabase.from("moderation_actions").insert({
          content_type,
          [idColumn]: target_id,
          target_user_id: targetUserId,
          action_type: "auto_block",
          reason: `Trúng từ khóa cấm: "${kwResult.pattern}"`,
          is_automated: true,
        });

        return new Response(
          JSON.stringify({ target_id, status: "hidden", reason: "keyword_match" }),
          { headers: { ...corsHeaders, "Content-Type": "application/json" } },
        );
      }
    }

    // ---- Bước 2: Gemini safety check (text + ảnh song song, xử lý lỗi an toàn) ----
    const checks: Promise<{ severityScore: number; labels: Record<string, number> }>[] = [];

    if (content && content.trim().length > 0) {
      checks.push(checkGeminiSafety(content));
    }

    for (const imgUrl of image_urls) {
      checks.push(
        (async () => {
          try {
            const imgRes = await fetch(imgUrl);
            if (!imgRes.ok) throw new Error(`HTTP ${imgRes.status}`);
            
            const imgBuffer = await imgRes.arrayBuffer();
            const imgBase64 = encode(new Uint8Array(imgBuffer));
            const mimeType = imgRes.headers.get("content-type") || "image/jpeg";
            
            return await checkGeminiSafety("", imgBase64, mimeType);
          } catch (err) {
            console.error(`Không thể tải/xử lý ảnh ${imgUrl}:`, err);
            return { severityScore: 0, labels: {} };
          }
        })(),
      );
    }

    const results = await Promise.all(checks);
    let severityScore = 0;
    let labels: Record<string, number> = {};

    for (const r of results) {
      severityScore = Math.max(severityScore, r.severityScore);
      labels = { ...labels, ...r.labels };
    }

    const status = decideStatus(severityScore);

    // Cập nhật trạng thái bài đăng/bình luận/tin nhắn
    await supabase.from(table).update({
      moderation_status: status,
      ai_moderation_score: severityScore,
      ai_moderation_labels: labels,
      moderated_at: new Date().toISOString(),
    }).eq("id", target_id);

    // Lưu nhật ký nếu bị ẩn hoặc bị shadow limit
    if (status !== "published") {
      await supabase.from("moderation_actions").insert({
        content_type,
        [idColumn]: target_id,
        target_user_id: targetUserId,
        action_type: status === "hidden" ? "auto_block" : "auto_shadow_limit",
        reason: `Gemini safety score ${severityScore.toFixed(3)} — ${JSON.stringify(labels)}`,
        is_automated: true,
      });
    }

    return new Response(
      JSON.stringify({ target_id, status, severityScore, labels }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    console.error("Moderate Post Error:", err);
    return new Response(JSON.stringify({ error: err.message || String(err) }), {
      status: 500, headers: corsHeaders,
    });
  }
});
