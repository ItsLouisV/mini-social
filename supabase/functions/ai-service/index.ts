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
    // Chuyển hashtag thành không dấu và loại bỏ các ký tự đặc biệt không hợp lệ
    const cleanTagContent = removeAccents(tagContent).replace(/[^a-zA-Z0-9_]/g, "");
    const unaccentedHashtag = `#${cleanTagContent}`;
    hashtags.push(unaccentedHashtag);
    return unaccentedHashtag;
  });

  return { caption: processedCaption, hashtags };
}

async function fetchFromGemini({
  prompt,
  imageBase64,
  imageMimeType,
}: {
  prompt: string;
  imageBase64?: string;
  imageMimeType?: string;
}): Promise<string> {
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

/**
 * AI SERVICE EDGE FUNCTION
 * Chuyên dụng cho việc SÁNG TẠO NỘI DUNG & TẠO CAPTION bài viết (Có dấu) + Hashtag (KHÔNG DẤU).
 * Phục vụ 4 trường hợp:
 * 1. Có input text, KHÔNG có ảnh
 * 2. Có ảnh, KHÔNG có input text
 * 3. Có CẢ ảnh VÀ input text
 * 4. KHÔNG có gì hết (Sáng tạo tự do)
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { action, text, imageBase64, imageMimeType, targetLanguage, userId } = body;

    // Upstash Redis Rate Limiting (ĐƯỢC SỬ DỤNG TẠI ĐÂY)
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

    // ── XỬ LÝ CHÍNH: TẠO CAPTION & SÁNG TẠO NỘI DUNG (4 TRƯỜNG HỢP) ──
    if (!action || action === "generate_caption" || action === "create_content") {
      const hasText = Boolean(text && typeof text === "string" && text.trim().length > 0);
      const hasImage = Boolean(imageBase64 && typeof imageBase64 === "string" && imageBase64.trim().length > 0);

      let prompt = "";

      // TRƯỜNG HỢP 1: Có ảnh VÀ có input text
      if (hasImage && hasText) {
        prompt = `Bạn là chuyên gia sáng tạo nội dung mạng xã hội. 
Hãy phân tích bức ảnh đính kèm kết hợp với ý tưởng/chủ đề người dùng cung cấp: "${text.trim()}".
Viết một caption dựa trên sự phân tích bức ảnh và ý tưởng/chủ đề người dùng cung cấp (viết tiếng Việt CÓ DẤU bình thường) và kèm theo 3 đến 5 hashtag liên quan KHÔNG DẤU ở cuối (ví dụ: #cuocsong #banbe).

YÊU CẦU BẮT BUỘC:
1. Nội dung caption viết CÓ DẤU bình thường. Tuy nhiên, toàn bộ HASHTAG (#...) ở cuối BẮT BUỘC KHÔNG DẤU.
2. Chỉ trả về duy nhất nội dung caption kèm hashtag. KHÔNG trả về bất kỳ lời chào, lời dẫn đầu (như "Đây là caption của bạn:", "Chắc chắn rồi!"), hay ghi chú giải thích nào.`;
      } 
      // TRƯỜNG HỢP 2: Có ảnh nhưng KHÔNG có input text
      else if (hasImage && !hasText) {
        prompt = `Bạn là chuyên gia sáng tạo nội dung mạng xã hội.
Hãy phân tích nội dung bức ảnh đính kèm và viết một caption bài viết dựa trên sự phân tích của bức ảnh (viết tiếng Việt CÓ DẤU bình thường), kèm 3-5 hashtag KHÔNG DẤU ở cuối (ví dụ: #khoankhak #cuocsong).

YÊU CẦU BẮT BUỘC:
1. Nội dung caption viết CÓ DẤU bình thường. Tuy nhiên, toàn bộ HASHTAG (#...) ở cuối BẮT BUỘC KHÔNG DẤU.
2. Chỉ trả về duy nhất nội dung caption kèm hashtag. KHÔNG trả về bất kỳ lời chào, lời dẫn đầu (như "Đây là caption của bạn:", "Chắc chắn rồi!"), hay ghi chú giải thích nào.`;
      } 
      // TRƯỜNG HỢP 3: Có input text nhưng KHÔNG có ảnh
      else if (!hasImage && hasText) {
        prompt = `Bạn là chuyên gia sáng tạo nội dung mạng xã hội.
Dựa trên ý tưởng/chủ đề người dùng cung cấp: "${text.trim()}", hãy viết một caption bài viết dựa trên sự phân tích của ý tưởng (viết tiếng Việt CÓ DẤU bình thường), kèm 3-5 hashtag KHÔNG DẤU ở cuối (ví dụ: #khoankhak #cuocsong).

YÊU CẦU BẮT BUỘC:
1. Nội dung caption viết CÓ DẤU bình thường. Tuy nhiên, toàn bộ HASHTAG (#...) ở cuối BẮT BUỘC KHÔNG DẤU.
2. Chỉ trả về duy nhất nội dung caption kèm hashtag. KHÔNG trả về bất kỳ lời chào, lời dẫn đầu (như "Đây là caption của bạn:", "Chắc chắn rồi!"), hay ghi chú giải thích nào.`;
      } 
      // TRƯỜNG HỢP 4: Không có ảnh VÀ Không có input text (Ngẫu nhiên / Sáng tạo tự do)
      else {
        prompt = `Bạn là chuyên gia sáng tạo nội dung mạng xã hội.
Hãy tự do nghĩ ra một caption mạng xã hội ngẫu nhiên thật hay, tươi vui, bắt hot trend (viết tiếng Việt CÓ DẤU bình thường), kèm theo 3-5 hashtag KHÔNG DẤU ở cuối bài.

YÊU CẦU BẮT BUỘC:
1. Nội dung caption viết CÓ DẤU bình thường. Tuy nhiên, toàn bộ HASHTAG (#...) ở cuối BẮT BUỘC KHÔNG DẤU.
2. Chỉ trả về duy nhất nội dung caption kèm hashtag. KHÔNG trả về bất kỳ lời chào, lời dẫn đầu (như "Đây là caption của bạn:", "Chắc chắn rồi!"), hay ghi chú giải thích nào.`;
      }

      const rawAiResponse = await fetchFromGemini({ prompt, imageBase64, imageMimeType });

      // Làm sạch lời dẫn đầu và bỏ ngoặc kép thừa
      const cleaned = rawAiResponse
        .replace(/^["'„“«]+|["'”»]+$/g, "")
        .replace(/^(Đây là caption|Here is your caption|Caption|Gợi ý caption)[:\s]*/i, "")
        .trim();

      // Giữ nguyên DẤU cho caption, và LỌC KHÔNG DẤU cho các Hashtag (#...)
      const { caption, hashtags } = processCaptionAndHashtags(cleaned);

      return new Response(
        JSON.stringify({
          caption,
          hashtags,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── FALLBACK CHO DỊCH VĂN BẢN ──
    if (action === "translate") {
      const lang = targetLanguage || "vi";
      const isEn = String(lang).toLowerCase().includes("en");
      const prompt = isEn
        ? `Translate into English. Return ONLY the translation:\n"${text}"`
        : `Dịch sang tiếng Việt. Chỉ trả về duy nhất bản dịch:\n"${text}"`;
      const raw = await fetchFromGemini({ prompt });
      const clean = raw.replace(/^["'„“«]+|["'”»]+$/g, "").trim();
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
