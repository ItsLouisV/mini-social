import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Redis } from "npm:@upstash/redis@1.28.4";
import { Ratelimit } from "npm:@upstash/ratelimit@1.0.1";

// ============================================================
// AI SERVICE & RECOMMENDATION AGENTS (R1 & R2)
// Sprint 12+ — Embedding Generation & Taste Profiler
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
      limiter: Ratelimit.slidingWindow(10, "60 s"),
      analytics: true,
    });
  } catch (err) {
    console.error("Upstash Redis init error:", err);
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
};

/**
 * Loại bỏ toàn bộ dấu tiếng Việt và dấu phụ
 */
function removeAccents(str: string): string {
  if (!str) return "";
  return str
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .replace(/æ/g, "ae")
    .replace(/œ/g, "oe")
    .replace(/ß/g, "ss")
    .replace(/[ôơ]/g, "o")
    .replace(/[ư]/g, "u")
    .replace(/[ăâ]/g, "a")
    .replace(/[ê]/g, "e");
}

/**
 * Chuẩn hóa Caption & Hashtags
 */
function processCaptionAndHashtags(rawText: string): { caption: string; hashtags: string[] } {
  const hashtags: string[] = [];
  const processedCaption = rawText.replace(/#([^\s#]+)/g, (fullMatch, tagContent) => {
    const cleanTagContent = removeAccents(tagContent).replace(/[^a-zA-Z0-9_]/g, "");
    if (!cleanTagContent) return "";
    const unaccentedHashtag = `#${cleanTagContent}`;
    if (!hashtags.includes(unaccentedHashtag)) {
      hashtags.push(unaccentedHashtag);
    }
    return unaccentedHashtag;
  });

  // Fallback an toàn: Nếu AI bỏ sót không sinh hashtag, tự động tạo 3-4 hashtag phù hợp
  if (hashtags.length === 0) {
    const defaultTags = ["#viora", "#cuocsong", "#trending", "#chill"];
    for (const tag of defaultTags) {
      hashtags.push(tag);
    }
    const finalCaption = `${processedCaption.trim()}\n\n${defaultTags.join(" ")}`;
    return { caption: finalCaption, hashtags };
  }

  return { caption: processedCaption.trim(), hashtags };
}

const FORMAT_RULES = `
QUY TẮC BẮT BUỘC ĐỊNH DẠNG:
1. Caption: Viết bằng tiếng Việt CÓ DẤU, giọng văn cuốn hút, tự nhiên, cảm xúc, bắt trend mạng xã hội (độ dài 2-4 câu).
2. HASHTAGS BẮT BUỘC: BẮT BUỘC PHẢI TẠO TỪ 3 ĐẾN 6 HASHTAGS (#...) thịnh hành, liên quan trực tiếp đến bức ảnh hoặc chủ đề bài viết, đặt ở CUỐI CÙNG của caption.
3. QUY TẮC HASHTAG: Tất cả HASHTAG (#...) BẮT BUỘC VIẾT LIỀN VÀ KHÔNG DẤU TIẾNG VIỆT (ví dụ: #dulich #vietnam #thugian #cuocsong #trending #chill #lifestyle #photooftheday).
4. KHÔNG viết bất kỳ lời chào, lời dẫn hay giải thích nào. Chỉ trả về trực tiếp nội dung caption và các hashtag ở cuối.
`.trim();

function buildSystemInstruction(caseDescription: string): string {
  return `Bạn là chuyên gia sáng tạo nội dung mạng xã hội hàng đầu. ${caseDescription}\n\n${FORMAT_RULES}`;
}

const UNSAFE_TOKEN = "[[UNSAFE_CONTENT]]";

class GeminiBlockedError extends Error {
  constructor(public detail: string) {
    super(`Nội dung bị chặn vì lý do an toàn: ${detail}`);
    this.name = "GeminiBlockedError";
  }
}

async function fetchFromGemini({
  systemInstruction,
  userText,
  imageBase64,
  imageMimeType,
}: {
  systemInstruction: string;
  userText: string;
  imageBase64?: string;
  imageMimeType?: string;
}): Promise<string> {
  const modelsToTry = ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-2.5-flash-lite", "gemini-2.5-flash"];
  let lastError: Error | null = null;

  for (const model of modelsToTry) {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${GEMINI_API_KEY}`;
    const parts: any[] = [{ text: userText }];
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
            temperature: 0.8,
            maxOutputTokens: 500,
          },
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        lastError = new Error(`Gemini Error (${res.status}): ${errText}`);
        continue;
      }

      const json = await res.json();
      if (json.promptFeedback?.blockReason) {
        throw new GeminiBlockedError(json.promptFeedback.blockReason);
      }

      const candidate = json.candidates?.[0];
      const text = candidate?.content?.parts?.[0]?.text || "";
      if (!text) throw new GeminiBlockedError("EMPTY_RESPONSE");
      if (text.trim().includes(UNSAFE_TOKEN)) throw new GeminiBlockedError("MODEL_SELF_FLAGGED");

      return text.trim();
    } catch (err) {
      if (err instanceof GeminiBlockedError) throw err;
      lastError = err as Error;
    }
  }

  throw lastError || new Error("Không thể kết nối đến AI Service.");
}

// ------------------------------------------------------------
// AGENT R1: VECTOR EMBEDDING GENERATOR (768 DIMENSIONS)
// Ưu tiên Model 2 trước, tiếp đến Model 1 (theo yêu cầu hệ thống)
// ------------------------------------------------------------
const EMBEDDING_MODELS_PRIORITY = [
  // ── 1. Gemini Embedding 2 (Đúng tên hiển thị trên Google AI Studio) ──
  "gemini-embedding-2",
  // ── 2. Gemini Embedding 1 (Đúng tên hiển thị trên Google AI Studio) ──
  "gemini-embedding-001",
  // ── Fallback các alias khác nếu có ──
  "text-embedding-002",
  "embedding-001",
  "text-embedding-004",
];

let activeEmbeddingModel: string | null = null;

async function requestGeminiEmbedding(model: string, text: string, withDim = true): Promise<number[] | null> {
  if (!GEMINI_API_KEY) return null;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:embedContent?key=${GEMINI_API_KEY}`;
  const payload: Record<string, unknown> = {
    model: `models/${model}`,
    content: {
      parts: [{ text: text.slice(0, 3000) }],
    },
  };

  if (withDim) {
    payload.outputDimensionality = 768;
  }

  try {
    const res = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errText = await res.text();
      // Nếu lỗi 400 và đang gửi outputDimensionality, thử lại không kèm outputDimensionality (cho model cũ như embedding-001)
      if (res.status === 400 && withDim) {
        console.warn(`[Embedding] Model ${model} không hỗ trợ tham số outputDimensionality (${errText}). Đang thử lại không kèm tham số này...`);
        return requestGeminiEmbedding(model, text, false);
      }
      console.warn(`[Embedding] Model ${model} thất bại (HTTP ${res.status}): ${errText}`);
      return null;
    }

    const data = await res.json();
    let values: number[] | undefined = data.embedding?.values;
    if (!values || !Array.isArray(values) || values.length === 0) {
      console.warn(`[Embedding] Model ${model} không trả về mảng values embedding.`);
      return null;
    }

    // Nếu vector trả về dài hơn 768 chiều (ví dụ 3072 hoặc 1536 chiều của MRL), cắt lấy 768 chiều đầu và normalize L2
    if (values.length > 768) {
      values = values.slice(0, 768);
      const norm = Math.sqrt(values.reduce((sum, v) => sum + v * v, 0));
      if (norm > 0) {
        values = values.map((v) => v / norm);
      }
    }

    if (values.length === 768) {
      return values;
    }

    console.warn(`[Embedding] Model ${model} trả về số chiều ${values.length}, không khớp với yêu cầu 768 chiều.`);
    return null;
  } catch (err) {
    console.error(`[Embedding] Ngoại lệ kết nối tới model ${model}:`, err);
    return null;
  }
}

async function generateEmbedding(text: string): Promise<number[] | null> {
  if (!GEMINI_API_KEY || !text.trim()) return null;

  // 1. Thử model đã xác định thành công trước đó (để tối ưu latency)
  if (activeEmbeddingModel) {
    const cachedResult = await requestGeminiEmbedding(activeEmbeddingModel, text);
    if (cachedResult) return cachedResult;
    console.warn(`[Embedding] Model ${activeEmbeddingModel} từng hoạt động nay bị lỗi, tiến hành quét lại danh sách ưu tiên...`);
    activeEmbeddingModel = null;
  }

  // 2. Quét tuần tự: Ưu tiên Model 2 trước, sau đó tới Model 1
  for (const model of EMBEDDING_MODELS_PRIORITY) {
    const values = await requestGeminiEmbedding(model, text);
    if (values) {
      activeEmbeddingModel = model;
      console.log(`[Embedding] Đã chọn model thành công: ${model} (768 dimensions)`);
      return values;
    }
  }

  // 3. Nếu tất cả đều thất bại, truy vấn chẩn đoán các model hỗ trợ trên API key này
  console.error("[Embedding] Toàn bộ các model embedding ưu tiên đều thất bại. Đang truy vấn danh sách model từ Google API...");
  try {
    const listRes = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}`);
    if (listRes.ok) {
      const listData = await listRes.json();
      const supported = (listData.models || [])
        .filter((m: any) => m.supportedGenerationMethods?.includes("embedContent"))
        .map((m: any) => m.name);
      console.error("[Embedding] Các model hỗ trợ embedContent trên API Key hiện tại là:", supported);
    }
  } catch (diagErr) {
    console.error("[Embedding] Không thể truy vấn danh sách model:", diagErr);
  }

  return null;
}

// ------------------------------------------------------------
// MAIN AI SERVICE HANDLER
// ------------------------------------------------------------
serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const body = await req.json().catch(() => ({}));
    const { action, text, imageBase64, imageMimeType, userId, postId } = body;

    // Upstash Redis Rate Limiting
    if (ratelimit) {
      const identifier = userId || req.headers.get("x-forwarded-for") || "anonymous";
      const { success } = await ratelimit.limit(`ratelimit:ai:${identifier}`);
      if (!success) {
        return new Response(
          JSON.stringify({ error: "Quá nhiều yêu cầu. Vui lòng thử lại sau 1 phút." }),
          { status: 429, headers: jsonHeaders },
        );
      }
    }

    // ── 1. TẠO CAPTION ──
    if (!action || action === "generate_caption" || action === "create_content") {
      const hasText = Boolean(text && typeof text === "string" && text.trim().length > 0);
      const hasImage = Boolean(imageBase64 && typeof imageBase64 === "string" && imageBase64.trim().length > 0);

      let systemInstruction = "";
      let userText = "";

      if (hasImage && hasText) {
        systemInstruction = buildSystemInstruction("Phân tích kỹ hình ảnh và kết hợp với ý tưởng người dùng để viết caption cuốn hút, kèm 3-6 hashtag không dấu ở cuối.");
        userText = `Ý tưởng: "${text.trim()}". Hãy viết một caption cuốn hút cho bức ảnh này và bắt buộc tạo 3-6 hashtag không dấu liên quan ở cuối.`;
      } else if (hasImage) {
        systemInstruction = buildSystemInstruction("Quan sát bức ảnh, phân tích chi tiết cảnh vật, con người, thú cưng hoặc hoạt động để viết caption thật hay, kèm 3-6 hashtag không dấu ở cuối.");
        userText = "Hãy quan sát bức ảnh này, viết một caption thật hấp dẫn và bắt buộc kèm theo từ 3 đến 6 hashtag không dấu ở cuối.";
      } else {
        systemInstruction = buildSystemInstruction("Hãy sáng tạo một caption hấp dẫn dựa trên chủ đề do người dùng cung cấp, kèm 3-6 hashtag không dấu ở cuối.");
        userText = `Chủ đề: "${text ? text.trim() : 'cuộc sống vui tươi'}". Hãy viết một caption thật hay và bắt buộc tạo 3-6 hashtag không dấu liên quan ở cuối.`;
      }

      const rawAiResponse = await fetchFromGemini({ systemInstruction, userText, imageBase64, imageMimeType });
      const cleaned = rawAiResponse
        .replace(/^["'„“«]+|["'”»]+$/g, "")
        .replace(/^(Đây là caption|Caption)[:\s]*/i, "")
        .trim();

      const { caption, hashtags } = processCaptionAndHashtags(cleaned);
      return new Response(JSON.stringify({ caption, hashtags }), { headers: jsonHeaders });
    }

    // ── 2. AGENT R1: TẠO EMBEDDING CHO BÀI VIẾT (768 DIMENSIONS) ──
    if (action === "generate_post_embedding") {
      const targetPostId = postId || body.post_id;
      if (!targetPostId) {
        return new Response(JSON.stringify({ error: "Thiếu postId" }), { status: 400, headers: jsonHeaders });
      }

      // Lấy nội dung bài viết nếu chưa truyền text
      let postContent = text;
      if (!postContent) {
        const { data: postRecord } = await supabase
          .from("posts")
          .select("caption")
          .eq("id", targetPostId)
          .maybeSingle();
        postContent = postRecord?.caption || "";
      }

      if (!postContent.trim()) {
        return new Response(JSON.stringify({ success: true, message: "Bài viết không có caption để tạo embedding" }), { headers: jsonHeaders });
      }

      // Upstash Redis Caching cho Embedding Vector
      let embeddingValues: number[] | null = null;
      let cacheKey = "";
      if (redis) {
        try {
          const hashBuf = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(postContent.trim()));
          const hashHex = Array.from(new Uint8Array(hashBuf)).map(b => b.toString(16).padStart(2, '0')).join('');
          cacheKey = `embed:cache:${hashHex}`;
          const cached = await redis.get<number[]>(cacheKey);
          if (cached && Array.isArray(cached) && cached.length === 768) {
            embeddingValues = cached;
          }
        } catch (_) {}
      }

      if (!embeddingValues) {
        embeddingValues = await generateEmbedding(postContent);
        if (embeddingValues && embeddingValues.length === 768 && redis && cacheKey) {
          redis.set(cacheKey, embeddingValues, { ex: 86400 * 7 }).catch(() => {});
        }
      }

      if (embeddingValues && embeddingValues.length === 768) {
        await supabase
          .from("posts")
          .update({ embedding: embeddingValues })
          .eq("id", targetPostId);

        return new Response(
          JSON.stringify({ 
            success: true, 
            postId: targetPostId, 
            dimensions: embeddingValues.length, 
            model: activeEmbeddingModel,
            cached: Boolean(embeddingValues && cacheKey) 
          }),
          { headers: jsonHeaders },
        );
      }

      return new Response(
        JSON.stringify({ 
          error: "Không thể tạo vector embedding",
          details: "Tất cả các model embedding (ưu tiên nhóm 2 trước, tiếp đến nhóm 1) đều không khả dụng. Vui lòng kiểm tra GEMINI_API_KEY hoặc log Supabase."
        }),
        { status: 500, headers: jsonHeaders },
      );
    }

    // ── 4. AGENT R2: TỔNG HỢP GU SỞ THÍCH NGƯỜI DÙNG (USER TASTE PROFILER) ──
    if (action === "refresh_user_taste") {
      const targetUserId = userId || body.user_id;
      if (!targetUserId) {
        return new Response(JSON.stringify({ error: "Thiếu userId" }), { status: 400, headers: jsonHeaders });
      }

      // Lấy 30 bài viết gần nhất mà user đã tương tác tích cực (dwell > 2s hoặc like/comment/share)
      const { data: positiveEvents } = await supabase
        .from("recommendation_events")
        .select("post_id, event_type, duration_ms, posts(caption, ai_moderation_labels)")
        .eq("user_id", targetUserId)
        .in("event_type", ["like", "comment", "share", "view_dwell"])
        .order("created_at", { ascending: false })
        .limit(30);

      const capturedTopics: string[] = [];
      const capturedSnippets: string[] = [];

      for (const ev of positiveEvents ?? []) {
        if (ev.event_type === "view_dwell" && ev.duration_ms < 2500) continue;
        const post = ev.posts as any;
        if (post?.caption) {
          capturedSnippets.push(post.caption.slice(0, 100));
        }
        if (post?.ai_moderation_labels?.topics) {
          capturedTopics.push(...post.ai_moderation_labels.topics);
        }
      }

      const combinedTasteText = [
        "Sở thích và chủ đề quan tâm của người dùng:",
        [...new Set(capturedTopics)].join(", "),
        "Nội dung các bài viết xem lâu và yêu thích:",
        capturedSnippets.slice(0, 10).join(" | "),
      ].join("\n");

      if (capturedSnippets.length > 0 || capturedTopics.length > 0) {
        const tasteEmbedding = await generateEmbedding(combinedTasteText);
        if (tasteEmbedding && tasteEmbedding.length === 768) {
          await supabase
            .from("profiles")
            .update({ taste_embedding: tasteEmbedding })
            .eq("id", targetUserId);

          return new Response(
            JSON.stringify({ success: true, userId: targetUserId, topicsCount: capturedTopics.length }),
            { headers: jsonHeaders },
          );
        }
      }

      return new Response(
        JSON.stringify({ success: true, message: "Chưa đủ dữ liệu hành vi để tạo taste embedding" }),
        { headers: jsonHeaders },
      );
    }

    // ── 5. AI HYBRID SEARCH (RRF: FTS + GEMINI VECTOR 768d) ──
    if (action === "hybrid_search") {
      const queryText = (text || body.query || "").trim();
      if (!queryText) {
        return new Response(JSON.stringify({ posts: [] }), { headers: jsonHeaders });
      }

      // Sinh embedding 768 chiều cho query search
      const queryEmbedding = await generateEmbedding(queryText);
      if (!queryEmbedding) {
        // Fallback FTS text thuần nếu không sinh được embedding
        const { data: ftsPosts } = await supabase
          .from("posts")
          .select("id, user_id, caption, created_at, likes_count, comments_count, privacy, moderation_status")
          .filter("deleted_at", "is", null)
          .ilike("caption", `%${queryText}%`)
          .limit(30);

        return new Response(JSON.stringify({ posts: ftsPosts ?? [] }), { headers: jsonHeaders });
      }

      // Gọi RPC hybrid_search_posts với RRF
      const { data: rrfPosts, error: rpcErr } = await supabase.rpc("hybrid_search_posts", {
        p_query_text: queryText,
        p_query_embedding: queryEmbedding,
        p_match_count: 30,
        p_rrf_k: 60,
      });

      if (rpcErr) {
        console.error("hybrid_search_posts RPC error:", rpcErr);
        return new Response(JSON.stringify({ error: rpcErr.message }), { status: 500, headers: jsonHeaders });
      }

      return new Response(JSON.stringify({ posts: rrfPosts ?? [] }), { headers: jsonHeaders });
    }

    // ── 6. ACTION MODERATE (HỖ TRỢ TƯƠNG THÍCH NGƯỢC) ──
    if (action === "moderate") {
      // Chuyển tiếp kết quả nhanh cho client
      return new Response(
        JSON.stringify({
          isSafe: true,
          decision: "ALLOW",
          riskScore: 0,
          reason: "Chuyển giao kiểm duyệt ngầm cho Server Multi-Agents.",
        }),
        { headers: jsonHeaders },
      );
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), { status: 400, headers: jsonHeaders });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || String(err) }), { status: 500, headers: jsonHeaders });
  }
});
