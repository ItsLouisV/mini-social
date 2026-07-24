import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * MEDIA MODERATOR EDGE FUNCTION (Chuyên dụng kiểm duyệt Ảnh & Video bằng Gemini 2.5 / 3.6 Flash)
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { mediaBase64, mediaMimeType, mediaType } = await req.json();

    if (!mediaBase64 || mediaBase64.trim().length === 0) {
      return new Response(
        JSON.stringify({
          isSafe: true,
          decision: "ALLOW",
          riskScore: 0,
          violations: [],
          reason: "Không có file media đính kèm để kiểm duyệt.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const mime = mediaMimeType || (mediaType === "video" ? "video/mp4" : "image/jpeg");
    const isVideo = mediaType === "video" || mime.startsWith("video/");

    // Prompt kiểm duyệt hình ảnh & video chuyên sâu (Visual Safety Benchmark)
    const prompt = `Bạn là hệ thống AI kiểm duyệt thị giác (Visual Moderation Guard) chuyên nghiệp hàng đầu cho các mạng xã hội lớn (TikTok, Instagram, Facebook).
Nhiệm vụ: Phân tích kỹ bức ảnh / video đính kèm và đánh giá nghiêm ngặt các tiêu chuẩn an toàn thị giác.

DANH MỤC KIỂM TRA BẮT BUỘC:
1. NUDITY_EXPLICIT: Khỏa thân, khiêu dâm, đồi trụy, bộ phận nhạy cảm, hở hang khiêu khích (NSFW/Pornography).
2. VIOLENCE_GORE: Bạo lực, máu me, kinh dị, hành hạ con người/động vật, tai nạn thảm khốc.
3. ILLEGAL_SUBSTANCES: Ma túy, chất cấm, vũ khí hạng nặng, súng đạn, hành vi nguy hiểm.
4. HATE_SYMBOLS: Biểu tượng thù ghét, phân biệt chủng tộc, khủng bố.
5. CHILD_SAFETY: Bất kỳ dấu hiệu bóc lột hoặc gây nguy hiểm cho trẻ em.

YÊU CẦU ĐÁNH GIÁ (RISK SCORE 0 - 100):
- Nudity/Explicit hoặc CSAM -> RiskScore = 100 (Bắt buộc REJECT).
- Violence/Gore hoặc Vũ khí/Chất cấm -> RiskScore = 90 - 100 (Bắt buộc REJECT).
- Hở hang mức nhẹ, ảnh gây tranh cãi hoặc giật gân -> RiskScore = 40 - 60 (SHADOW_BAN hoặc HUMAN_REVIEW).
- An toàn hoàn toàn -> RiskScore = 0 - 15 (ALLOW).

CHỈ TRẢ VỀ DUY NHẤT ĐỊNH DẠNG JSON HỢP LỆ THEO SCHEMA:
{
  "isSafe": true_hoac_false,
  "decision": "ALLOW" | "SHADOW_BAN" | "HUMAN_REVIEW" | "REJECT",
  "riskScore": 0_den_100,
  "violations": ["Tên danh mục vi phạm nếu có"],
  "reason": "Giải thích ngắn gọn lý do bằng tiếng Việt nếu không an toàn"
}`;

    const aiResponse = await fetchFromGeminiVision({
      prompt,
      mediaBase64,
      mimeType: mime,
    });

    let parsed = {
      isSafe: true,
      decision: "ALLOW",
      riskScore: 0,
      violations: [],
      reason: "",
    };

    try {
      const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        parsed = JSON.parse(jsonMatch[0]);
      }
    } catch (_) {
      parsed = {
        isSafe: true,
        decision: "ALLOW",
        riskScore: 0,
        violations: [],
        reason: "",
      };
    }

    return new Response(JSON.stringify(parsed), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function fetchFromGeminiVision({
  prompt,
  mediaBase64,
  mimeType,
}: {
  prompt: string;
  mediaBase64: string;
  mimeType: string;
}): Promise<string> {
  if (!GEMINI_API_KEY) {
    return JSON.stringify({
      isSafe: true,
      decision: "ALLOW",
      riskScore: 0,
      violations: [],
      reason: "",
    });
  }

  const contents = [
    {
      parts: [
        {
          inline_data: {
            mime_type: mimeType,
            data: mediaBase64,
          },
        },
        { text: prompt },
      ],
    },
  ];

  // Sử dụng Gemini Flash Multimodal Endpoint cao cấp
  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ contents }),
  });

  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text || "";
}
