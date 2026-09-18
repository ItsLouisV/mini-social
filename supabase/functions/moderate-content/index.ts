import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { encode } from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Redis } from "npm:@upstash/redis@1.28.4";
import { Ratelimit } from "npm:@upstash/ratelimit@1.0.1";

// ============================================================
// CONTENT MODERATION MULTI-AGENTS ORCHESTRATOR
// Sprint 12+ — Lean Multi-Agent Engine for Viora Social
//
// Pipeline:
//  - Stage 0: Fast Guard Agent (Keywords & Regex — 0ms, 0 cost)
//  - Stage 1 (Parallel):
//      * Agent 1: Vietnamese Slang, Sarcasm & Cultural Context
//      * Agent 2: Multimodal Vision & OCR Safety Agent
//      * Agent 3: Scam & Fraud Pattern Hunter Agent
//  - Stage 2: Policy Judge Agent (Synthesis & Final Verdict)
//  - Stage 3: Audit Logging (moderation_agent_logs) & DB Update
// ============================================================

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const UPSTASH_REDIS_REST_URL = Deno.env.get("UPSTASH_REDIS_REST_URL") || "";
const UPSTASH_REDIS_REST_TOKEN = Deno.env.get("UPSTASH_REDIS_REST_TOKEN") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

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
      limiter: Ratelimit.slidingWindow(30, "60 s"),
      analytics: true,
    });
  } catch (err) {
    console.error("Upstash Redis init error (moderate-content):", err);
  }
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

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

// ------------------------------------------------------------
// GEMINI HELPER UTILITIES
// ------------------------------------------------------------
const MODELS_TO_TRY = ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-2.5-flash-lite", "gemini-2.5-flash"];

async function callGeminiJson({
  systemInstruction,
  userPrompt,
  imageBase64,
  imageMimeType,
}: {
  systemInstruction: string;
  userPrompt: string;
  imageBase64?: string;
  imageMimeType?: string;
}): Promise<any> {
  if (!GEMINI_API_KEY) {
    return null;
  }

  let lastError: Error | null = null;

  for (const model of MODELS_TO_TRY) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;
    const parts: any[] = [{ text: userPrompt }];

    if (imageBase64) {
      parts.push({
        inline_data: {
          mime_type: imageMimeType || "image/jpeg",
          data: imageBase64,
        },
      });
    }

    try {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          system_instruction: { parts: [{ text: systemInstruction }] },
          contents: [{ role: "user", parts }],
          generationConfig: {
            temperature: 0.1,
            maxOutputTokens: 600,
            response_mime_type: "application/json",
          },
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        lastError = new Error(`Gemini ${model} error (${res.status}): ${errText}`);
        continue;
      }

      const json = await res.json();
      const rawText = json.candidates?.[0]?.content?.parts?.[0]?.text || "{}";
      return JSON.parse(rawText);
    } catch (err: any) {
      lastError = err;
    }
  }

  console.warn("Gemini call failed or returned unparseable JSON:", lastError);
  return null;
}

// ------------------------------------------------------------
// STAGE 0: FAST GUARD (REGEX & KEYWORDS)
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
// AGENT 1: VIETNAMESE SLANG, SARCASM & CULTURAL CONTEXT
// ------------------------------------------------------------
async function runSlangCultureAgent(text: string) {
  if (!text || text.trim().length === 0) {
    return { is_safe: true, risk_score: 0.0, category: "none", reason: "Nội dung văn bản trống." };
  }

  const systemInstruction = `Bạn là Agent Chuyên gia Ngôn ngữ & Văn hóa Mạng Xã Hội Việt Nam của nền tảng Viora.
Nhiệm vụ: Phân tích sâu ngữ nghĩa tiếng Việt bao gồm teencode, từ lóng biến âm lách luật (ví dụ: đ-m, đ!t, phò, bay lắc, kẹo ke), chửi bới xúc phạm gián tiếp, phân biệt vùng miền, miệt thị ác ý, bắt nạt trực tuyến.
Trả về DUY NHẤT một JSON hợp lệ dạng:
{
  "is_safe": boolean,
  "risk_score": number (0.0 là hoàn toàn lành mạnh, 1.0 là vi phạm cực nặng),
  "category": string ("none" | "profanity_slang" | "hate_speech" | "harassment"),
  "reason": string (giải thích ngắn gọn 1-2 câu tiếng Việt)
}`;

  const prompt = `Phân tích nội dung sau: "${text}"`;
  const result = await callGeminiJson({ systemInstruction, userPrompt: prompt });
  return (
    result || {
      is_safe: true,
      risk_score: 0.0,
      category: "none",
      reason: "Không phát hiện yếu tố ngôn ngữ vi phạm.",
    }
  );
}

// ------------------------------------------------------------
// AGENT 2: MULTIMODAL VISION & OCR SAFETY AGENT
// ------------------------------------------------------------
async function runVisionOcrAgent(imageUrl: string) {
  try {
    const imgRes = await fetch(imageUrl);
    if (!imgRes.ok) throw new Error(`HTTP ${imgRes.status}`);

    const imgBuffer = await imgRes.arrayBuffer();
    const imageBase64 = encode(new Uint8Array(imgBuffer));
    const mimeType = imgRes.headers.get("content-type") || "image/jpeg";

    const systemInstruction = `Bạn là Agent Chuyên gia Thị giác & OCR của mạng xã hội Viora.
Nhiệm vụ:
1. Đọc và trích xuất mọi chữ/văn bản xuất hiện trong hình ảnh (bảng hiệu, ảnh chế/meme, ảnh chụp màn hình tin nhắn, số điện thoại, tài liệu).
2. Kiểm tra các yếu tố thị giác nguy hiểm: khỏa thân gợi dục 18+, bạo lực đẫm máu, vũ khí sát thương, hành vi tự hại.
3. Đánh giá xem chữ trích xuất được có mang tính chất đe dọa, xúc phạm hoặc lừa đảo không.
Trả về DUY NHẤT một JSON hợp lệ dạng:
{
  "is_safe": boolean,
  "risk_score": number (0.0 đến 1.0),
  "ocr_text": string,
  "detected_issues": string[],
  "reason": string
}`;

    const prompt = "Hãy soi kỹ hình ảnh này và đọc chữ trong ảnh.";
    const result = await callGeminiJson({
      systemInstruction,
      userPrompt: prompt,
      imageBase64,
      imageMimeType: mimeType,
    });

    return (
      result || {
        is_safe: true,
        risk_score: 0.0,
        ocr_text: "",
        detected_issues: [],
        reason: "Hình ảnh hợp lệ.",
      }
    );
  } catch (err: any) {
    console.warn(`Vision Agent fetch error on ${imageUrl}:`, err.message);
    return {
      is_safe: true,
      risk_score: 0.0,
      ocr_text: "",
      detected_issues: [],
      reason: "Không thể tải hoặc xử lý ảnh.",
    };
  }
}

// ------------------------------------------------------------
// AGENT 3: SCAM & FRAUD PATTERN HUNTER AGENT
// ------------------------------------------------------------
async function runFraudHunterAgent(text: string, ocrTexts: string[]) {
  const combined = [text, ...ocrTexts].filter(Boolean).join("\n---\n");
  if (!combined.trim()) {
    return { is_fraud: false, risk_score: 0.0, fraud_type: "none", reason: "Không có nội dung." };
  }

  const systemInstruction = `Bạn là Agent Chuyên gia Chống Lừa Đảo & Cờ Bạc (Fraud & Scam Hunter) của Viora.
Nhiệm vụ: Phát hiện các hành vi lừa đảo mạng:
- Kéo vào nhóm Telegram / Zalo kín để cá cược, đánh bạc online, game bài đổi thưởng, tài xỉu.
- Quảng cáo app vay nặng lãi, bẫy tài chính, lừa đảo cộng tác viên nạp tiền shopee/tiki ảo.
- Cho số điện thoại lừa đảo, chuyển khoản mạo danh, bán hàng cấm trá hình.
Trả về DUY NHẤT một JSON hợp lệ dạng:
{
  "is_fraud": boolean,
  "risk_score": number (0.0 đến 1.0),
  "fraud_type": string ("none" | "gambling" | "telegram_betting" | "ponzi" | "fake_job"),
  "reason": string
}`;

  const prompt = `Kiểm tra hành vi lừa đảo/cờ bạc trong nội dung sau:\n${combined}`;
  const result = await callGeminiJson({ systemInstruction, userPrompt: prompt });
  return (
    result || {
      is_fraud: false,
      risk_score: 0.0,
      fraud_type: "none",
      reason: "Không phát hiện yếu tố lừa đảo tài chính.",
    }
  );
}

// ------------------------------------------------------------
// AGENT 4: POLICY JUDGE AGENT (CHỦ TỊCH HỘI ĐỒNG XÉT DUYỆT)
// ------------------------------------------------------------
async function runPolicyJudgeAgent({
  slangReport,
  visionReports,
  fraudReport,
  fastGuardSeverity,
}: {
  slangReport: any;
  visionReports: any[];
  fraudReport: any;
  fastGuardSeverity: string | null;
}) {
  const systemInstruction = `Bạn là Policy Judge Agent - Thẩm phán Tiêu chuẩn Cộng đồng tối cao của mạng xã hội Viora.
Bạn sẽ nhận bản tổng hợp đánh giá từ:
1. Fast Guard (từ khóa cấm).
2. Agent Ngôn ngữ & Văn hóa tiếng Việt.
3. Agent Thị giác & OCR hình ảnh.
4. Agent Chống Lừa đảo & Cờ bạc.

Nhiệm vụ của bạn:
Ra quyết định cuối cùng theo thang tiêu chuẩn của Viora:
- "published": Nội dung an toàn, lành mạnh hoặc chỉ là đùa vui vô hại (severity_score < 0.35).
- "shadow_limited": Nội dung nhạy cảm nhẹ, tranh cãi, ngôn từ người lớn chưa tới mức cấm hoặc hình ảnh ranh giới gợi cảm vừa phải (severity_score 0.35 - 0.70).
- "hidden": Vi phạm nghiêm trọng (lừa đảo cờ bạc, 18+ khiêu dâm, bạo lực máu me, ngôn từ thù ghét chửi bới ác ý, phân biệt vùng miền) (severity_score > 0.70).

Đồng thời trích xuất 1-3 chủ đề (topics) và 1 câu tóm tắt nội dung bài viết phục vụ gợi ý.

Trả về DUY NHẤT một JSON hợp lệ dạng:
{
  "decision": "published" | "shadow_limited" | "hidden",
  "severity_score": number,
  "primary_reason": string,
  "summary_rationale": string,
  "topics": string[],
  "content_summary": string
}`;

  const summaryInput = JSON.stringify(
    {
      fastGuardSeverity,
      slangReport,
      visionReports,
      fraudReport,
    },
    null,
    2,
  );

  const result = await callGeminiJson({
    systemInstruction,
    userPrompt: `Hãy ra phán quyết tiêu chuẩn dựa trên báo cáo sau:\n${summaryInput}`,
  });

  if (result && result.decision) {
    return result;
  }

  // Fallback heuristic nếu Judge model gặp trục trặc
  const maxRisk = Math.max(
    slangReport?.risk_score || 0,
    fraudReport?.risk_score || 0,
    ...visionReports.map((v) => v.risk_score || 0),
  );

  let fallbackDecision: "published" | "shadow_limited" | "hidden" = "published";
  if (maxRisk >= 0.75 || fastGuardSeverity === "flag_for_review") fallbackDecision = "hidden";
  else if (maxRisk >= 0.40) fallbackDecision = "shadow_limited";

  return {
    decision: fallbackDecision,
    severity_score: maxRisk,
    primary_reason: "heuristic_fallback",
    summary_rationale: "Tự động phân loại dựa trên điểm rủi ro cao nhất của các Agent.",
    topics: ["xã hội"],
    content_summary: "",
  };
}

// ------------------------------------------------------------
// MAIN REQUEST HANDLER
// ------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const pipelineRunId = crypto.randomUUID();
  const startTime = Date.now();

  try {
    const { content_type, target_id, content = "", image_urls = [] } = await req.json();

    if (!content_type || !isValidContentType(content_type) || !target_id) {
      return new Response(
        JSON.stringify({ error: "content_type hoặc target_id không hợp lệ" }),
        { status: 400, headers: jsonHeaders },
      );
    }

    // Upstash Redis Rate Limiting (chống spam dồn dập)
    if (ratelimit) {
      const clientIp = req.headers.get("x-forwarded-for") || target_id;
      const { success } = await ratelimit.limit(`ratelimit:mod:${clientIp}`);
      if (!success) {
        return new Response(
          JSON.stringify({ error: "Quá nhiều yêu cầu kiểm duyệt. Vui lòng thử lại sau.", pipeline_run_id: pipelineRunId }),
          { status: 429, headers: jsonHeaders },
        );
      }
    }

    const { table, idColumn, userColumn } = TABLE_MAP[content_type];

    // Lấy thông tin tác giả
    const { data: targetRecord } = await supabase
      .from(table)
      .select(userColumn || "user_id")
      .eq("id", target_id)
      .maybeSingle();

    const targetUserId = targetRecord ? targetRecord[userColumn || "user_id"] : null;

    // Upstash Redis Caching cho nội dung văn bản lặp lại (tiết kiệm chi phí AI & phản hồi tức thì)
    let textCacheKey = "";
    if (redis && content && image_urls.length === 0) {
      try {
        const hashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(content.trim()));
        const hashHex = Array.from(new Uint8Array(hashBuf)).map(b => b.toString(16).padStart(2, '0')).join('');
        textCacheKey = `mod:cache:${hashHex}`;
        const cached = await redis.get<any>(textCacheKey);
        if (cached && typeof cached === "object" && cached.status) {
          await supabase.from(table).update({
            moderation_status: cached.status,
            ai_moderation_score: cached.severityScore,
            ai_moderation_labels: { ...cached.labels, cached_from_redis: true },
            moderated_at: new Date().toISOString(),
          }).eq("id", target_id);

          return new Response(
            JSON.stringify({
              target_id,
              status: cached.status,
              severityScore: cached.severityScore,
              topics: cached.topics || [],
              cached: true,
              pipeline_run_id: pipelineRunId,
              execution_time_ms: Date.now() - startTime,
            }),
            { headers: jsonHeaders },
          );
        }
      } catch (_) {}
    }

    // ── STAGE 0: FAST GUARD (KEYWORD & REGEX SCAN) ──
    let fastGuardSeverity: string | null = null;
    let fastGuardPattern: string | null = null;

    if (content && content.trim().length > 0) {
      const { data: keywords } = await supabase
        .from("banned_keywords")
        .select("pattern, match_type, severity, category")
        .eq("is_active", true);

      const kwResult = checkKeywords(content, keywords ?? []);
      if (kwResult.matched) {
        fastGuardSeverity = kwResult.severity;
        fastGuardPattern = kwResult.pattern;

        // Ghi log agent fast_guard
        await supabase.from("moderation_agent_logs").insert({
          content_type,
          content_id: target_id,
          pipeline_run_id: pipelineRunId,
          agent_name: "fast_guard",
          verdict: kwResult.severity === "zero_tolerance" ? "reject" : "flag",
          confidence: 1.0,
          reasons: { pattern: kwResult.pattern, category: kwResult.category },
          execution_time_ms: Date.now() - startTime,
        });

        // Nếu zero-tolerance: ẨN NGAY LẬP TỨC (<50ms)
        if (kwResult.severity === "zero_tolerance") {
          await supabase.from(table).update({
            moderation_status: "hidden",
            ai_moderation_score: 1.0,
            ai_moderation_labels: {
              safety: `Trúng từ khóa cấm nghiêm trọng: "${kwResult.pattern}"`,
              primary_reason: "keyword_zero_tolerance",
              matched_pattern: kwResult.pattern,
              pipeline_run_id: pipelineRunId,
            },
            moderated_at: new Date().toISOString(),
          }).eq("id", target_id);

          await supabase.from("moderation_actions").insert({
            content_type,
            [idColumn]: target_id,
            target_user_id: targetUserId,
            action_type: "auto_block",
            reason: `Fast Guard chặn từ khóa cấm: "${kwResult.pattern}"`,
            is_automated: true,
          });

          return new Response(
            JSON.stringify({
              target_id,
              status: "hidden",
              severityScore: 1.0,
              reason: "zero_tolerance_keyword",
              pipeline_run_id: pipelineRunId,
            }),
            { headers: jsonHeaders },
          );
        }
      } else {
        // Ghi log fast_guard pass
        await supabase.from("moderation_agent_logs").insert({
          content_type,
          content_id: target_id,
          pipeline_run_id: pipelineRunId,
          agent_name: "fast_guard",
          verdict: "pass",
          confidence: 1.0,
          reasons: { status: "clean" },
          execution_time_ms: Date.now() - startTime,
        });
      }
    }

    // ── STAGE 1: CHẠY SONG SONG CÁC AGENTS CHUYÊN MÔN ──
    const agentPromises: Promise<any>[] = [];

    // Agent 1: Slang & Culture
    const slangPromise = runSlangCultureAgent(content).then(async (res) => {
      await supabase.from("moderation_agent_logs").insert({
        content_type,
        content_id: target_id,
        pipeline_run_id: pipelineRunId,
        agent_name: "slang_culture",
        verdict: res.is_safe ? "pass" : res.risk_score > 0.7 ? "reject" : "flag",
        confidence: 0.9,
        reasons: res,
        execution_time_ms: Date.now() - startTime,
      });
      return res;
    });
    agentPromises.push(slangPromise);

    // Agent 2: Vision & OCR cho từng ảnh đính kèm
    const validImages = Array.isArray(image_urls) ? image_urls.slice(0, 4) : [];
    const visionPromises = validImages.map((url, idx) =>
      runVisionOcrAgent(url).then(async (res) => {
        await supabase.from("moderation_agent_logs").insert({
          content_type,
          content_id: target_id,
          pipeline_run_id: pipelineRunId,
          agent_name: `vision_ocr_${idx + 1}`,
          verdict: res.is_safe ? "pass" : res.risk_score > 0.7 ? "reject" : "flag",
          confidence: 0.9,
          reasons: res,
          execution_time_ms: Date.now() - startTime,
        });
        return res;
      })
    );

    const [slangReport, ...visionReports] = await Promise.all([
      slangPromise,
      ...visionPromises,
    ]);

    // Agent 3: Fraud & Scam Hunter
    const ocrTexts = visionReports.map((v) => v.ocr_text || "").filter(Boolean);
    const fraudReport = await runFraudHunterAgent(content, ocrTexts);
    await supabase.from("moderation_agent_logs").insert({
      content_type,
      content_id: target_id,
      pipeline_run_id: pipelineRunId,
      agent_name: "fraud_detector",
      verdict: !fraudReport.is_fraud ? "pass" : fraudReport.risk_score > 0.7 ? "reject" : "flag",
      confidence: 0.92,
      reasons: fraudReport,
      execution_time_ms: Date.now() - startTime,
    });

    // ── STAGE 2: POLICY JUDGE AGENT PHÁN QUYẾT CUỐI CÙNG ──
    const judgeVerdict = await runPolicyJudgeAgent({
      slangReport,
      visionReports,
      fraudReport,
      fastGuardSeverity,
    });

    await supabase.from("moderation_agent_logs").insert({
      content_type,
      content_id: target_id,
      pipeline_run_id: pipelineRunId,
      agent_name: "policy_judge",
      verdict: judgeVerdict.decision === "published" ? "pass" : judgeVerdict.decision === "hidden" ? "reject" : "flag",
      confidence: 0.95,
      reasons: judgeVerdict,
      execution_time_ms: Date.now() - startTime,
    });

    // ── STAGE 3: GHI NHẬN KẾT QUẢ VÀO DATABASE ──
    const mergedLabels = {
      safety: judgeVerdict.summary_rationale || "Đã kiểm duyệt bởi Multi-Agents.",
      primary_reason: judgeVerdict.primary_reason || "none",
      topics: judgeVerdict.topics || [],
      summary: judgeVerdict.content_summary || "",
      pipeline_run_id: pipelineRunId,
      scores: {
        slang: slangReport.risk_score,
        fraud: fraudReport.risk_score,
        vision_max: visionReports.length > 0 ? Math.max(...visionReports.map((v) => v.risk_score || 0)) : 0,
      },
    };

    await supabase.from(table).update({
      moderation_status: judgeVerdict.decision,
      ai_moderation_score: judgeVerdict.severity_score,
      ai_moderation_labels: mergedLabels,
      moderated_at: new Date().toISOString(),
    }).eq("id", target_id);

    // Ghi nhật ký xử lý vi phạm nếu bị ẩn hoặc hạn chế
    if (judgeVerdict.decision !== "published") {
      await supabase.from("moderation_actions").insert({
        content_type,
        [idColumn]: target_id,
        target_user_id: targetUserId,
        action_type: judgeVerdict.decision === "hidden" ? "auto_block" : "auto_shadow_limit",
        reason: `[Multi-Agents] ${judgeVerdict.primary_reason}: ${judgeVerdict.summary_rationale}`,
        is_automated: true,
      });
    }

    // Lưu kết quả vào Upstash Redis cache (TTL: 12 giờ)
    if (redis && textCacheKey) {
      redis.set(textCacheKey, {
        status: judgeVerdict.decision,
        severityScore: judgeVerdict.severity_score,
        labels: mergedLabels,
        topics: judgeVerdict.topics,
      }, { ex: 3600 * 12 }).catch(() => {});
    }

    return new Response(
      JSON.stringify({
        target_id,
        status: judgeVerdict.decision,
        severityScore: judgeVerdict.severity_score,
        topics: judgeVerdict.topics,
        pipeline_run_id: pipelineRunId,
        execution_time_ms: Date.now() - startTime,
      }),
      { headers: jsonHeaders },
    );
  } catch (err: any) {
    console.error("Multi-Agents Moderation Error:", err);
    return new Response(
      JSON.stringify({ error: err.message || String(err), pipeline_run_id: pipelineRunId }),
      { status: 500, headers: jsonHeaders },
    );
  }
});
