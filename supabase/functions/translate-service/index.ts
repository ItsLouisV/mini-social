import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { Redis } from "npm:@upstash/redis@1.28.4";
import { Ratelimit } from "npm:@upstash/ratelimit@1.0.1";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL =
  Deno.env.get("GEMINI_TRANSLATE_MODEL") ?? "gemini-3.5-flash-lite";

const UPSTASH_REDIS_REST_URL =
  Deno.env.get("UPSTASH_REDIS_REST_URL") ?? "";

const UPSTASH_REDIS_REST_TOKEN =
  Deno.env.get("UPSTASH_REDIS_REST_TOKEN") ?? "";

const MAX_TEXT_LENGTH = 10_000;
const CACHE_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 ngày
const GEMINI_TIMEOUT_MS = 15_000;

type SupportedLanguage = "vi" | "en";

interface TranslateRequest {
  text?: unknown;

  /**
   * Ngôn ngữ hiện tại của ứng dụng:
   * vi, vi-VN, vi_VN, en, en-US, en_US...
   */
  targetLanguage?: unknown;

  /**
   * Không bắt buộc.
   * UI có thể truyền ngôn ngữ đã phát hiện của văn bản.
   */
  sourceLanguage?: unknown;

  userId?: unknown;
}

interface GeminiResponse {
  candidates?: Array<{
    content?: {
      parts?: Array<{
        text?: string;
      }>;
    };
  }>;

  promptFeedback?: {
    blockReason?: string;
  };
}

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const jsonHeaders = {
  ...corsHeaders,
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

let redis: Redis | null = null;
let ratelimit: Ratelimit | null = null;

if (UPSTASH_REDIS_REST_URL && UPSTASH_REDIS_REST_TOKEN) {
  redis = new Redis({
    url: UPSTASH_REDIS_REST_URL,
    token: UPSTASH_REDIS_REST_TOKEN,
  });

  ratelimit = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(30, "60 s"),

    // Tắt nếu bạn không cần biểu đồ analytics.
    // analytics=true tạo thêm thao tác lưu analytics.
    analytics: false,

    prefix: "translate_ratelimit",
  });
}

function createJsonResponse(
  data: Record<string, unknown>,
  status = 200,
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: jsonHeaders,
  });
}

/**
 * Chỉ chấp nhận ngôn ngữ đích là vi hoặc en.
 */
function normalizeTargetLanguage(value: unknown): SupportedLanguage | null {
  if (typeof value !== "string") {
    return null;
  }

  const normalized = value
    .trim()
    .toLowerCase()
    .replaceAll("_", "-");

  if (
    normalized === "vi" ||
    normalized.startsWith("vi-") ||
    normalized === "vietnamese" ||
    normalized === "tiếng việt" ||
    normalized === "tieng viet"
  ) {
    return "vi";
  }

  if (
    normalized === "en" ||
    normalized.startsWith("en-") ||
    normalized === "english" ||
    normalized === "tiếng anh" ||
    normalized === "tieng anh"
  ) {
    return "en";
  }

  return null;
}

function normalizeSourceLanguage(
  value: unknown,
): SupportedLanguage | null {
  return normalizeTargetLanguage(value);
}

/**
 * Hash SHA-256 để không đưa toàn bộ nội dung bài viết vào Redis key.
 */
async function sha256(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest("SHA-256", bytes);

  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

async function createCacheKey(
  text: string,
  targetLanguage: SupportedLanguage,
): Promise<string> {
  const hash = await sha256(`${targetLanguage}:${text}`);

  // v1 giúp sau này thay prompt/model có thể đổi thành v2.
  return `translate:v1:${targetLanguage}:${hash}`;
}

function buildTranslationPrompt(
  text: string,
  targetLanguage: SupportedLanguage,
): string {
  const targetName =
    targetLanguage === "vi" ? "Vietnamese" : "English";

  return [
    `Translate the content below into ${targetName}.`,
    `If it is already written in ${targetName}, return it unchanged.`,
    "Preserve meaning, tone, emojis, mentions, hashtags, line breaks, and URLs.",
    "Do not explain.",
    "Return only the final text.",
    "",
    "<content>",
    text,
    "</content>",
  ].join("\n");
}

function cleanTranslation(value: string): string {
  let result = value.trim();

  // Chỉ xóa code fence nếu model tự thêm.
  result = result
    .replace(/^```(?:text|plaintext)?\s*/i, "")
    .replace(/\s*```$/i, "")
    .trim();

  // Chỉ xóa một cặp ngoặc bao toàn bộ kết quả.
  const quotePairs: Array<[string, string]> = [
    ['"', '"'],
    ["'", "'"],
    ["“", "”"],
    ["„", "“"],
    ["«", "»"],
  ];

  for (const [opening, closing] of quotePairs) {
    if (
      result.startsWith(opening) &&
      result.endsWith(closing) &&
      result.length >= opening.length + closing.length
    ) {
      result = result
        .slice(opening.length, result.length - closing.length)
        .trim();

      break;
    }
  }

  return result;
}

async function fetchFromGemini(
  text: string,
  targetLanguage: SupportedLanguage,
): Promise<string> {
  if (!GEMINI_API_KEY) {
    throw new Error("Server chưa cấu hình GEMINI_API_KEY.");
  }

  const controller = new AbortController();
  const timeoutId = setTimeout(
    () => controller.abort(),
    GEMINI_TIMEOUT_MS,
  );

  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=` +
    `${encodeURIComponent(GEMINI_API_KEY)}`;

  try {
    const response = await fetch(url, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [
              {
                text: buildTranslationPrompt(
                  text,
                  targetLanguage,
                ),
              },
            ],
          },
        ],

        generationConfig: {
          temperature: 0,
          topP: 0.1,

          // Điều chỉnh theo độ dài text nếu cần.
          maxOutputTokens: Math.min(
            2048,
            Math.max(128, Math.ceil(text.length * 1.5)),
          ),

          responseMimeType: "text/plain",
        },
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();

      console.error("Gemini API error:", {
        status: response.status,
        body: errorText,
      });

      throw new Error(
        `Gemini API trả về trạng thái ${response.status}.`,
      );
    }

    const data = await response.json() as GeminiResponse;

    const translatedText = data.candidates?.[0]?.content?.parts
      ?.map((part) => part.text ?? "")
      .join("")
      .trim();

    if (!translatedText) {
      const blockReason = data.promptFeedback?.blockReason;

      if (blockReason) {
        throw new Error(
          `Không thể dịch nội dung: ${blockReason}.`,
        );
      }

      throw new Error("Gemini không trả về nội dung bản dịch.");
    }

    return cleanTranslation(translatedText);
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error("Yêu cầu dịch quá thời gian cho phép.");
    }

    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

function getRateLimitIdentifier(
  req: Request,
  userId: unknown,
): string {
  /*
   * userId từ request body có thể bị giả mạo.
   * Tạm thời có thể dùng, nhưng production nên lấy user id từ JWT.
   */
  if (
    typeof userId === "string" &&
    userId.trim().length > 0 &&
    userId.length <= 100
  ) {
    return `user:${userId.trim()}`;
  }

  const forwardedFor = req.headers
    .get("x-forwarded-for")
    ?.split(",")[0]
    ?.trim();

  return `ip:${forwardedFor || "anonymous"}`;
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return createJsonResponse(
      { error: "Method not allowed." },
      405,
    );
  }

  const requestStartedAt = performance.now();

  try {
    let body: TranslateRequest;

    try {
      body = await req.json() as TranslateRequest;
    } catch {
      return createJsonResponse(
        { error: "Request body không phải JSON hợp lệ." },
        400,
      );
    }

    if (typeof body.text !== "string") {
      return createJsonResponse(
        { error: "Trường text phải là chuỗi." },
        400,
      );
    }

    const text = body.text.trim();

    if (!text) {
      return createJsonResponse({
        translatedText: "",
        targetLanguage: null,
        cached: false,
      });
    }

    if (text.length > MAX_TEXT_LENGTH) {
      return createJsonResponse(
        {
          error:
            `Văn bản vượt quá giới hạn ${MAX_TEXT_LENGTH} ký tự.`,
        },
        413,
      );
    }

    /*
     * Không âm thầm mặc định sang một ngôn ngữ khác.
     * UI bắt buộc phải gửi locale hiện tại của ứng dụng.
     */
    const targetLanguage = normalizeTargetLanguage(
      body.targetLanguage,
    );

    if (!targetLanguage) {
      return createJsonResponse(
        {
          error:
            "targetLanguage chỉ hỗ trợ vi hoặc en.",
        },
        400,
      );
    }

    /*
     * Nếu UI đã phát hiện ngôn ngữ nguồn và nó giống ngôn ngữ app,
     * không cần gọi Redis/Gemini.
     */
    const sourceLanguage = normalizeSourceLanguage(
      body.sourceLanguage,
    );

    if (sourceLanguage === targetLanguage) {
      return createJsonResponse({
        translatedText: text,
        targetLanguage,
        cached: true,
        skipped: true,
        durationMs: Math.round(
          performance.now() - requestStartedAt,
        ),
      });
    }

    const cacheKey = redis
      ? await createCacheKey(text, targetLanguage)
      : null;

    /*
     * Kiểm tra cache trước rate limit.
     * Bản dịch đã có không cần tiếp tục tiêu tốn Gemini.
     */
    if (redis && cacheKey) {
      try {
        const cachedTranslation =
          await redis.get<string>(cacheKey);

        if (
          typeof cachedTranslation === "string" &&
          cachedTranslation.length > 0
        ) {
          return createJsonResponse({
            translatedText: cachedTranslation,
            targetLanguage,
            cached: true,
            durationMs: Math.round(
              performance.now() - requestStartedAt,
            ),
          });
        }
      } catch (error) {
        // Redis lỗi không nên làm chức năng dịch hỏng hoàn toàn.
        console.error("Translation cache read error:", error);
      }
    }

    /*
     * Chỉ rate-limit những request thật sự phải gọi Gemini.
     */
    if (ratelimit) {
      const identifier = getRateLimitIdentifier(
        req,
        body.userId,
      );

      const result = await ratelimit.limit(identifier);

      if (!result.success) {
        return new Response(
          JSON.stringify({
            error:
              "Quá nhiều yêu cầu dịch. Vui lòng thử lại sau.",
          }),
          {
            status: 429,
            headers: {
              ...jsonHeaders,
              "X-RateLimit-Limit": String(result.limit),
              "X-RateLimit-Remaining": String(
                result.remaining,
              ),
              "X-RateLimit-Reset": String(result.reset),
            },
          },
        );
      }
    }

    const geminiStartedAt = performance.now();

    const translatedText = await fetchFromGemini(
      text,
      targetLanguage,
    );

    const geminiDurationMs = Math.round(
      performance.now() - geminiStartedAt,
    );

    /*
     * Không bắt người dùng đợi ghi cache xong mới nhận kết quả.
     */
    if (redis && cacheKey && translatedText) {
      EdgeRuntime.waitUntil(
        redis
          .set(cacheKey, translatedText, {
            ex: CACHE_TTL_SECONDS,
          })
          .catch((error) => {
            console.error(
              "Translation cache write error:",
              error,
            );
          }),
      );
    }

    return createJsonResponse({
      translatedText,
      targetLanguage,
      cached: false,
      geminiDurationMs,
      durationMs: Math.round(
        performance.now() - requestStartedAt,
      ),
    });
  } catch (error) {
    console.error("Translate function error:", error);

    const message = error instanceof Error
      ? error.message
      : "Đã xảy ra lỗi không xác định.";

    const isTimeout = message.includes(
      "quá thời gian",
    );

    return createJsonResponse(
      { error: message },
      isTimeout ? 504 : 500,
    );
  }
});