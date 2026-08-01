import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { Redis } from "npm:@upstash/redis@1.28.4";
import { Ratelimit } from "npm:@upstash/ratelimit@1.0.1";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const UPSTASH_REDIS_REST_URL = Deno.env.get("UPSTASH_REDIS_REST_URL") || "";
const UPSTASH_REDIS_REST_TOKEN = Deno.env.get("UPSTASH_REDIS_REST_TOKEN") || "";

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

/**
 * Loại bỏ toàn bộ dấu tiếng Việt và dấu phụ của mọi ngôn ngữ (Unaccented String Generator)
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
    .replace(/ô/g, "o")
    .replace(/ư/g, "u")
    .replace(/ơ/g, "o")
    .replace(/ă/g, "a")
    .replace(/â/g, "a")
    .replace(/ê/g, "e");
}

/**
 * Chuẩn hóa Caption: Giữ nguyên DẤU của nội dung Caption,
 * nhưng tự động chuyển đổi TOÀN BỘ HASHTAG (#...) thành KHÔNG DẤU.
 */
function processCaptionAndHashtags(rawText: string): { caption: string; hashtags: string[] } {
  const hashtags: string[] = [];

  const processedCaption = rawText.replace(/#([^\s#]+)/g, (fullMatch, tagContent) => {
    const cleanTagContent = removeAccents(tagContent).replace(/[^a-zA-Z0-9_]/g, "");
    const unaccentedHashtag = `#${cleanTagContent}`;
    hashtags.push(unaccentedHashtag);
    return unaccentedHashtag;
  });

  return { caption: processedCaption, hashtags };
}

// ------------------------------------------------------------
// LUẬT ĐỊNH DẠNG CHUNG — nằm trong system_instruction
// ------------------------------------------------------------
const FORMAT_RULES = `
YÊU CẦU BẮT BUỘC:
1. Nội dung caption viết CÓ DẤU tiếng Việt bình thường. Toàn bộ HASHTAG (#...) ở cuối BẮT BUỘC KHÔNG DẤU, ví dụ: #khoanhkhac #cuocsong #banbe.
2. Caption phải có ĐỘ DÀI TỐI THIỂU 4-6 câu (không tính hashtag): mở đầu gây chú ý, phần thân mô tả/kể chuyện sinh động dựa trên chi tiết trực quan thực tế trong ảnh (hoặc ý tưởng thật), kết thúc bằng một câu chốt hài hước hoặc cảm xúc. TUYỆT ĐỐI KHÔNG viết caption sáo rỗng chung chung 1-2 câu.
3. NẾU ẢNH CÓ CHỨA CHỮ HOẶC VĂN BẢN (bảng hiệu, sách, ảnh trích dẫn/quote, meme, tài liệu): ĐỌC VÀ TRÍCH XUẤT/ĐỌC HIỂU NỘI DUNG CHỮ TRONG ẢNH, sau đó viết caption phản ánh trực tiếp và chính xác nội dung/thông điệp của chữ đó.
4. NẾU ẢNH CÓ CHỨA CHÓ/MÈO/THÚ CƯNG: viết theo văn phong trend mạng xã hội Việt Nam (gọi thú cưng là 'boss', 'hoàng thượng', 'ông chủ/bà chủ', xưng người nuôi là 'con sen', 'nô tài'; giọng văn hài hước, nuông chiều, đáng yêu).
5. Chỉ trả về duy nhất caption kèm hashtag. KHÔNG thêm lời chào, lời dẫn đầu (như "Đây là caption của bạn:"), hay ghi chú giải thích.
6. TUYỆT ĐỐI KHÔNG tạo caption cho ảnh có nội dung khỏa thân, gợi dục, 18+, hoặc bạo lực. Nếu gặp ảnh nhạy cảm/18+, CHỈ TRẢ VỀ DUY NHẤT CHUỖI KÝ TỰ SAU: [[UNSAFE_CONTENT]]
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
  // Dùng model chính thức gemini-1.5-flash (hỗ trợ Multimodal + Vision OCR + Safety)
  const modelsToTry = ["gemini-3.5-flash-lite", "gemini-3.1-flash-lite", "gemini-1.5-flash", "gemini-2.0-flash"];

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
          safetySettings: [
            { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_LOW_AND_ABOVE" },
            { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
            { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_MEDIUM_AND_ABOVE" },
          ],
          generationConfig: {
            temperature: 0.9,
            maxOutputTokens: 500,
          },
        }),
      });

      if (!res.ok) {
        const errText = await res.text();
        console.error(`Gemini API Model ${model} Error (${res.status}):`, errText);
        lastError = new Error(`Gemini API Error (${res.status}): ${errText}`);
        continue; // Try fallback model if any
      }

      const json = await res.json();

      // Gemini tự chặn ở tầng prompt (ảnh nhạy cảm / 18+)
      if (json.promptFeedback?.blockReason) {
        throw new GeminiBlockedError(json.promptFeedback.blockReason);
      }

      const candidate = json.candidates?.[0];

      // Chặn ở tầng output (nếu model bắt đầu sinh nội dung không an toàn)
      if (candidate?.finishReason === "SAFETY" || candidate?.finishReason === "RECITATION") {
        throw new GeminiBlockedError(candidate.finishReason);
      }

      const text = candidate?.content?.parts?.[0]?.text || "";
      if (!text) {
        throw new GeminiBlockedError("EMPTY_RESPONSE");
      }

      // Lớp phòng thủ 2: Model tự báo cáo ảnh 18+/nhạy cảm
      if (text.trim().includes(UNSAFE_TOKEN)) {
        throw new GeminiBlockedError("MODEL_SELF_FLAGGED");
      }

      return text.trim();
    } catch (err) {
      if (err instanceof GeminiBlockedError) {
        throw err; // Re-throw safety block immediately, don't fall back
      }
      lastError = err as Error;
    }
  }

  throw lastError || new Error("Không thể kết nối đến AI Service.");
}

/**
 * AI SERVICE EDGE FUNCTION
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, text, imageBase64, imageMimeType, targetLanguage, userId } = body;

    // Upstash Redis Rate Limiting
    if (ratelimit) {
      const identifier = userId || req.headers.get("x-forwarded-for") || "anonymous";
      const { success } = await ratelimit.limit(`ratelimit:ai:${identifier}`);
      if (!success) {
        return new Response(
          JSON.stringify({ error: "Quá nhiều yêu cầu tạo AI. Vui lòng thử lại sau 1 phút." }),
          { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // ── TẠO CAPTION & SÁNG TẠO NỘI DUNG ──
    if (!action || action === "generate_caption" || action === "create_content") {
      const hasText = Boolean(text && typeof text === "string" && text.trim().length > 0);
      const hasImage = Boolean(imageBase64 && typeof imageBase64 === "string" && imageBase64.trim().length > 0);

      let systemInstruction = "";
      let userText = "";

      if (hasImage && hasText) {
        systemInstruction = buildSystemInstruction(
          "Hãy phân tích kỹ hình ảnh đính kèm (màu sắc, chi tiết, vật thể, chữ trong ảnh nếu có, thú cưng nếu có) kết hợp với ý tưởng/chủ đề người dùng cung cấp để tạo caption hấp dẫn.",
        );
        userText = `Ý tưởng/chủ đề người dùng: "${text.trim()}"`;
      } else if (hasImage && !hasText) {
        systemInstruction = buildSystemInstruction(
          "Hãy quan sát kỹ bức ảnh đính kèm. Phân tích chi tiết vật thể, cảnh vật, chữ/văn bản xuất hiện trong ảnh (nếu có), hoặc thú cưng (chó/mèo) để viết 1 caption thật sống động, hài hước và bắt trend.",
        );
        userText = "Hãy phân tích hình ảnh này và viết caption bài viết thật hay.";
      } else if (!hasImage && hasText) {
        systemInstruction = buildSystemInstruction(
          "Hãy sáng tạo 1 caption hấp dẫn dựa trên ý tưởng/chủ đề do người dùng cung cấp.",
        );
        userText = `Ý tưởng/chủ đề: "${text.trim()}"`;
      } else {
        systemInstruction = buildSystemInstruction(
          "Hãy tự do sáng tạo 1 caption ngẫu nhiên thật hay, tươi vui, bắt hot trend mạng xã hội.",
        );
        userText = "Hãy tạo 1 caption ngẫu nhiên.";
      }

      let cleaned: string;
      try {
        const rawAiResponse = await fetchFromGemini({ systemInstruction, userText, imageBase64, imageMimeType });
        cleaned = rawAiResponse
          .replace(/^["'„“«]+|["'”»]+$/g, "")
          .replace(/^(Đây là caption|Here is your caption|Caption|Gợi ý caption)[:\s]*/i, "")
          .trim();
      } catch (err) {
        if (err instanceof GeminiBlockedError) {
          return new Response(
            JSON.stringify({
              error: "Nội dung hoặc ảnh nhạy cảm/18+ không phù hợp tiêu chuẩn để tạo caption. Vui lòng chọn ảnh khác.",
              code: "CONTENT_BLOCKED",
            }),
            { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        throw err;
      }

      const { caption, hashtags } = processCaptionAndHashtags(cleaned);

      return new Response(
        JSON.stringify({ caption, hashtags }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── DỊCH VĂN BẢN ──
    if (action === "translate") {
      const lang = targetLanguage || "vi";
      const isEn = String(lang).toLowerCase().includes("en");

      const systemInstruction = isEn
        ? "Translate the user's message into English. Return ONLY the translation, no preamble, no quotes."
        : "Dịch tin nhắn của người dùng sang tiếng Việt. Chỉ trả về duy nhất bản dịch, không thêm lời dẫn, không thêm dấu ngoặc kép.";

      let clean: string;
      try {
        const raw = await fetchFromGemini({ systemInstruction, userText: text ?? "" });
        clean = raw.replace(/^["'„“«]+|["'”»]+$/g, "").trim();
      } catch (err) {
        if (err instanceof GeminiBlockedError) {
          return new Response(
            JSON.stringify({ error: "Nội dung không phù hợp để dịch.", code: "CONTENT_BLOCKED" }),
            { status: 422, headers: { ...corsHeaders, "Content-Type": "application/json" } },
          );
        }
        throw err;
      }

      return new Response(
        JSON.stringify({ translatedText: clean }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    return new Response(JSON.stringify({ error: "Unknown action" }), { status: 400, headers: corsHeaders });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || String(err) }), { status: 500, headers: corsHeaders });
  }
});