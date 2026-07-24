import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-client@2.39.8";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function getActionTypeId(actionName: string): Promise<string | null> {
  try {
    const { data } = await supabase
      .from("moderation_action_types")
      .select("id")
      .eq("name", actionName.toLowerCase())
      .single();
    return data?.id || null;
  } catch (_) {
    return null;
  }
}

/**
 * REPORT SERVICE EDGE FUNCTION (Chuyên dụng tạo báo cáo vi phạm & Tự động hóa đánh giá tài khoản)
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { 
      reporterId, 
      contentId, 
      contentType, 
      categoryName, 
      description,
      reasonLevel1,
      reasonLevel2,
      reasonLevel3,
      urgencyLevel,
      reportScope,
      shouldBlockUser,
      shouldHideContent,
      shouldDeleteConversation
    } = await req.json();

    if (!reporterId || !contentId || !contentType) {
      return new Response(JSON.stringify({ error: "Thiếu thông số reporterId, contentId hoặc contentType" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. Tìm thông tin tác giả bị báo cáo (reported_user_id) từ DB
    let reportedUserId = "";
    try {
      if (contentType === "post") {
        const { data } = await supabase.from("posts").select("user_id").eq("id", contentId).single();
        reportedUserId = data?.user_id || "";
      } else if (contentType === "comment") {
        const { data } = await supabase.from("comments").select("user_id").eq("id", contentId).single();
        reportedUserId = data?.user_id || "";
      } else if (contentType === "message") {
        const { data } = await supabase.from("messages").select("sender_id").eq("id", contentId).single();
        reportedUserId = data?.sender_id || "";
      } else if (contentType === "profile") {
        reportedUserId = contentId;
      }
    } catch (err) {
      return new Response(JSON.stringify({ error: "Không tìm thấy nội dung bị báo cáo: " + err.message }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!reportedUserId) {
      return new Response(JSON.stringify({ error: "Không xác định được tác giả của nội dung bị báo cáo" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Tìm ID danh mục báo cáo (category_id)
    let categoryId = null;
    if (categoryName) {
      try {
        const { data } = await supabase.from("moderation_categories").select("id").eq("name", categoryName).single();
        categoryId = data?.id || null;
      } catch (_) {
        // Skip if not matches
      }
    }

    // 3. Tạo báo cáo vi phạm trong bảng moderation_reports
    const { data: reportData, error: reportError } = await supabase
      .from("moderation_reports")
      .insert({
        reporter_id: reporterId,
        reported_user_id: reportedUserId,
        content_id: contentId,
        content_type: contentType,
        category_id: categoryId,
        description: description || "",
        reason_level1: reasonLevel1 || "Chưa chọn",
        reason_level2: reasonLevel2 || "Chưa chọn",
        reason_level3: reasonLevel3,
        urgency_level: urgencyLevel,
        report_scope: reportScope,
        should_block_user: shouldBlockUser || false,
        should_hide_content: shouldHideContent || false,
        should_delete_conversation: shouldDeleteConversation || false,
        status: "pending",
      })
      .select("id")
      .single();

    if (reportError) {
      return new Response(JSON.stringify({ error: "Lỗi lưu báo cáo: " + reportError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. THỰC THI CHẶN NGƯỜI DÙNG TỰ ĐỘNG
    if (shouldBlockUser && reportedUserId) {
      try {
        await supabase.from("chat_blocks").insert({
          blocker_id: reporterId,
          blocked_id: reportedUserId,
        });
      } catch (_) {
        // Bỏ qua lỗi khóa chính nếu đã chặn trước đó
      }
    }

    // 5. THỰC THI XÓA CUỘC HỘI THOẠI TỰ ĐỘNG (cho Chat)
    if (shouldDeleteConversation && contentType === "message") {
      try {
        const { data: msg } = await supabase.from("messages").select("conversation_id").eq("id", contentId).single();
        if (msg?.conversation_id) {
          await supabase.from("conversations").delete().eq("id", msg.conversation_id);
        }
      } catch (_) {
        // Bỏ qua lỗi
      }
    }

    // 6. KIỂM TRA ĐIỂM DANH TIẾNG TỰ ĐỘNG (Auto Reputation Engine)
    // Đếm tổng số báo cáo chưa xử lý đối với tác giả này
    const { count: reportCount } = await supabase
      .from("moderation_reports")
      .select("id", { count: "exact", head: true })
      .eq("reported_user_id", reportedUserId)
      .eq("status", "pending");

    let autoActionTriggered = "none";
    const totalReports = reportCount || 0;

    // Nếu bị báo cáo >= 5 lần: Tự động đưa profile vào case xử lý và cảnh báo
    if (totalReports >= 5) {
      try {
        const actionId = await getActionTypeId("review");

        // Thêm case kiểm duyệt tự động cho tài khoản
        await supabase.from("moderation_cases").insert({
          content_id: reportedUserId,
          content_type: "profile",
          user_id: reportedUserId,
          risk_score: 85,
          status: "review",
          final_action_id: actionId,
        });

        autoActionTriggered = "flag_profile_review";
      } catch (_) {
        // Bỏ qua lỗi để không ngắt luồng
      }
    }

    return new Response(JSON.stringify({
      success: true,
      reportId: reportData.id,
      reportedUserId,
      totalPendingReports: totalReports,
      autoAction: autoActionTriggered,
    }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
