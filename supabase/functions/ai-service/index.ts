import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.8";
import { Redis } from "npm:@upstash/redis@1.28.4";
import { Ratelimit } from "npm:@upstash/ratelimit@1.0.1";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
const UPSTASH_REDIS_REST_URL = Deno.env.get("UPSTASH_REDIS_REST_URL") || "";
const UPSTASH_REDIS_REST_TOKEN = Deno.env.get("UPSTASH_REDIS_REST_TOKEN") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

let redis: Redis | null = null;
let ratelimit: Ratelimit | null = null;

if (UPSTASH_REDIS_REST_URL && UPSTASH_REDIS_REST_TOKEN) {
  try {
    redis = new Redis({
      url: UPSTASH_REDIS_REST_URL,
      token: UPSTASH_REDIS_REST_TOKEN,
    });
    ratelimit = new Ratelimit({
      redis,
      limiter: Ratelimit.slidingWindow(20, "60 s"),
      analytics: true,
    });
  } catch (err) {
    console.error("Upstash Redis init error:", err);
  }
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

async function fetchFromGemini({ prompt, imageBase64, imageMimeType }: { prompt: string; imageBase64?: string; imageMimeType?: string }): Promise<string> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

  const contents: any[] = [];
  const parts: any[] = [{ text: prompt }];

  if (imageBase64) {
    parts.push({
      inline_data: {
        mime_type: imageMimeType || "image/jpeg",
        data: imageBase64,
      },
    });
  }

  contents.push({ parts });

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents }),
  });

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`Gemini API Error: ${errText}`);
  }

  const json = await res.json();
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text || "";
  return text.trim();
}

async function fetchGeminiEmbedding(text: string): Promise<number[]> {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/text-embedding-004:embedContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      model: "models/text-embedding-004",
      content: { parts: [{ text }] },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini Embedding Error: ${await res.text()}`);
  }

  const json = await res.json();
  return json.embedding?.values || [];
}

// Check Banned Keywords v2 (zero_tolerance & flag_for_review)
async function checkBannedKeywords(text: string): Promise<{ isViolated: boolean; severity?: string; reason?: string }> {
  if (!text) return { isViolated: false };
  try {
    const { data: keywords } = await supabase.from("banned_keywords").select("*").eq("is_active", true);
    if (!keywords || keywords.length === 0) return { isViolated: false };

    const lower = text.toLowerCase();
    for (const k of keywords) {
      if (k.match_type === "exact") {
        if (lower.includes(k.pattern.toLowerCase())) {
          return { isViolated: true, severity: k.severity, reason: `Từ khóa cấm: ${k.pattern}` };
        }
      } else if (k.match_type === "regex") {
        try {
          const re = new RegExp(k.pattern, "i");
          if (re.test(text)) {
            return { isViolated: true, severity: k.severity, reason: `Pattern cấm: ${k.pattern}` };
          }
        } catch (_) { }
      }
    }
  } catch (err) {
    console.error("checkBannedKeywords error:", err);
  }
  return { isViolated: false };
}

// Log Moderation Action v2
async function logModerationAction({
  contentType,
  postId,
  commentId,
  messageId,
  userId,
  actionType,
  reason,
  isAutomated = true,
}: {
  contentType: "post" | "comment" | "message";
  postId?: string;
  commentId?: string;
  messageId?: string;
  userId?: string;
  actionType: string;
  reason: string;
  isAutomated?: boolean;
}) {
  try {
    await supabase.from("moderation_actions").insert([{
      content_type: contentType,
      post_id: postId || null,
      comment_id: commentId || null,
      message_id: messageId || null,
      target_user_id: userId || null,
      action_type: actionType,
      reason,
      is_automated: isAutomated,
    }]);
  } catch (err) {
    console.error("logModerationAction error:", err);
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, text, imageBase64, imageMimeType, targetLanguage, contentId, contentType = "post", userId, postId, commentId, messageId } = body;

    // Rate limiter
    if (ratelimit) {
      const identifier = userId || req.headers.get("x-forwarded-for") || "anonymous";
      const { success } = await ratelimit.limit(`ratelimit:${identifier}`);
      if (!success) {
        return new Response(JSON.stringify({ error: "Quá nhiều yêu cầu. Vui lòng thử lại sau." }), { status: 429, headers: corsHeaders });
      }
    }

    // TRANSLATE
    if (action === "translate") {
      const lang = targetLanguage || "tiếng Việt";
      const prompt = `Dịch đoạn văn bản sau sang ${lang}. Chỉ trả về duy nhất bản dịch, không giải thích gì thêm:\n"${text}"`;
      const response = await fetchFromGemini({ prompt });
      return new Response(JSON.stringify({ translatedText: response }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // GENERATE CAPTION
    if (action === "generate_caption") {
      const prompt = `Hãy đóng vai nhà sáng tạo nội dung mạng xã hội. Viết một caption tươi vui ngắn gọn cho bài viết: "${text || ''}".`;
      const response = await fetchFromGemini({ prompt, imageBase64, imageMimeType });
      return new Response(JSON.stringify({ caption: response }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // GENERATE EMBEDDING
    if (action === "generate_embedding") {
      const embedding = await fetchGeminiEmbedding(text || "");
      return new Response(JSON.stringify({ embedding }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ASYNC POST SCAN v2 (Background Scan)
    if (action === "async_post_scan") {
      const targetPostId = postId || contentId;
      const targetCommentId = commentId;
      const targetMessageId = messageId;
      const type: "post" | "comment" | "message" = contentType as any || "post";

      const kwCheck = await checkBannedKeywords(text || "");
      let riskScore = 0;
      let targetStatus: "published" | "shadow_limited" | "under_review" | "hidden" | "removed" = "published";
      let actionType = "auto_block";

      if (kwCheck.isViolated) {
        if (kwCheck.severity === "zero_tolerance") {
          targetStatus = "removed";
          actionType = "auto_block";
          riskScore = 100;
        } else {
          targetStatus = "shadow_limited";
          actionType = "auto_shadow_limit";
          riskScore = 70;
        }
      } else {
        const aiPrompt = `Bạn là hệ thống kiểm duyệt an toàn mạng xã hội. Đánh giá đoạn văn bản: "${text || ''}". Trả về JSON: {"risk_score": 0_den_100}`;
        try {
          const aiRaw = await fetchFromGemini({ prompt: aiPrompt, imageBase64 });
          const match = aiRaw.match(/\{[\s\S]*\}/);
          if (match) {
            const parsed = JSON.parse(match[0]);
            riskScore = parsed.risk_score || 0;
            if (riskScore >= 90) {
              targetStatus = "hidden";
              actionType = "auto_block";
            } else if (riskScore >= 60) {
              targetStatus = "under_review";
              actionType = "auto_shadow_limit";
            }
          }
        } catch (_) { }
      }

      // Cập nhật bảng nội dung tương ứng
      if (type === "post" && targetPostId) {
        await supabase.from("posts").update({ moderation_status: targetStatus, ai_moderation_score: riskScore / 100.0, moderated_at: new Date().toISOString() }).eq("id", targetPostId);
      } else if (type === "comment" && targetCommentId) {
        await supabase.from("comments").update({ moderation_status: targetStatus, ai_moderation_score: riskScore / 100.0, moderated_at: new Date().toISOString() }).eq("id", targetCommentId);
      } else if (type === "message" && targetMessageId) {
        await supabase.from("messages").update({ moderation_status: targetStatus, ai_moderation_score: riskScore / 100.0, moderated_at: new Date().toISOString() }).eq("id", targetMessageId);
      }

      if (targetStatus !== "published") {
        await logModerationAction({
          contentType: type,
          postId: targetPostId,
          commentId: targetCommentId,
          messageId: targetMessageId,
          userId,
          actionType,
          reason: kwCheck.reason || `AI Risk Score: ${riskScore}`,
          isAutomated: true,
        });
      }

      return new Response(JSON.stringify({ status: targetStatus, riskScore }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    // ADMIN AI ANALYZE v2
    if (action === "admin_ai_analyze") {
      const { contentCaption, reasonLevel1 } = body;
      const aiPrompt = `Phân tích báo cáo vi phạm nội dung: "${contentCaption || ''}". Lý do báo cáo: ${reasonLevel1 || 'Khác'}. Trả về JSON: {"risk_score": 0_den_100, "recommendation": "allow" | "hide" | "remove", "recommendation_reason": "Lý do ngắn gọn"}`;
      const aiRaw = await fetchFromGemini({ prompt: aiPrompt });
      let parsed = { risk_score: 50, recommendation: "allow", recommendation_reason: "Cần xem xét thủ công." };
      try {
        const match = aiRaw.match(/\{[\s\S]*\}/);
        if (match) parsed = { ...parsed, ...JSON.parse(match[0]) };
      } catch (_) { }

      return new Response(JSON.stringify({ data: parsed }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), { status: 400, headers: corsHeaders });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || String(err) }), { status: 500, headers: corsHeaders });
  }
});
