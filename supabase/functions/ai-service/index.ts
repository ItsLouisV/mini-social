import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, text, imageBase64, imageMimeType, targetLanguage } = await req.json();

    if (action === "translate") {
      const lang = targetLanguage || "tiếng Việt";
      const prompt = lang.includes("nếu")
        // Smart auto-detect mode (từ chat): phát hiện ngôn ngữ và dịch ngược lại
        ? `Hãy xác định ngôn ngữ của đoạn văn bản sau, sau đó dịch sang ngôn ngữ đối lập (nếu tiếng Việt → dịch sang tiếng Anh, nếu tiếng Anh hoặc tiếng nước ngoài khác → dịch sang tiếng Việt). Chỉ trả về bản dịch, không giải thích:\n"${text}"`
        // Fixed target mode (từ feed post)
        : `Dịch đoạn văn bản sau sang ${lang}. Chỉ trả về duy nhất bản dịch, không giải thích gì thêm:\n"${text}"`;

      const response = await fetchFromGemini({ prompt });
      return new Response(JSON.stringify({ translatedText: response }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "generate_caption") {
      const outputInstruction = "CHỈ TRẢ VỀ NỘI DUNG CAPTION VÀ HASHTAG TRỰC TIẾP. KHÔNG ĐƯỢC CHÈN LỜI CHÀO, DẪN DẮT HAY GIẢI THÍCH (như 'Chào bạn...', 'Đây là caption...').";

      // Hướng dẫn thả thính có điều kiện — để AI tự phán đoán ngữ cảnh
      const vibeInstruction = `
Về phong cách viết: Hãy đọc kỹ nội dung/ảnh và tự phán đoán tâm trạng, bối cảnh trước khi quyết định phong cách.
- Nếu bối cảnh vui vẻ, lãng mạn, tự tin, đang khoe bản thân, hay có đôi: có thể pha nhẹ "vibe thả thính" — tinh tế, duyên dáng, ngọt ngào, KHÔNG sến sẩm hay gượng ép.
- Nếu bối cảnh buồn, nhớ nhung, chia tay, mất mát, cô đơn, tâm sự, hay có chủ đề nghiêm túc (thiên tai, xã hội, sức khỏe, ẩm thực review thực chất, du lịch một mình theo phong cách trải nghiệm, ...): KHÔNG áp dụng thả thính — viết chân thành, đúng cảm xúc với bối cảnh đó.
- Nếu bối cảnh trung lập hoặc không rõ ràng: ưu tiên phong cách tươi tắn, tự nhiên, không cố gắng thêm vào gì.
`.trim();

      let prompt = "";
      if (imageBase64 && text) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Nhìn vào bức ảnh này và kết hợp với ý tưởng: "${text}". Viết một caption hấp dẫn, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${outputInstruction}`;
      } else if (imageBase64) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Phân tích bối cảnh, đối tượng và cảm xúc trong bức ảnh này, sau đó viết một caption sinh động, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${outputInstruction}`;
      } else if (text) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Dựa trên ý tưởng: "${text}", viết một caption ấn tượng, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${outputInstruction}`;
      } else {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Viết một caption tươi vui, chill và đáng yêu về một khoảnh khắc trong ngày, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${outputInstruction}`;
      }

      const response = await fetchFromGemini({
        prompt,
        imageBase64,
        imageMimeType: imageMimeType || "image/jpeg",
      });

      return new Response(JSON.stringify({ caption: response }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "moderate") {
      const prompt = `Phân tích xem đoạn văn bản sau có chứa từ ngữ thù ghét, xúc phạm, khiêu dâm, bạo lực hay vi phạm tiêu chuẩn cộng đồng mạng xã hội không:\n"${text}"\n\nChỉ trả về định dạng JSON hợp lệ: {"isSafe": true/false, "reason": "Lý do nếu vi phạm"}`;

      const response = await fetchFromGemini({ prompt });
      let parsed = { isSafe: true, reason: "" };
      try {
        const jsonMatch = response.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          parsed = JSON.parse(jsonMatch[0]);
        }
      } catch (_) {
        parsed = { isSafe: true, reason: "" };
      }

      return new Response(JSON.stringify(parsed), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Action không hợp lệ" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

async function fetchFromGemini({
  prompt,
  imageBase64,
  imageMimeType,
}: {
  prompt: string;
  imageBase64?: string;
  imageMimeType?: string;
}): Promise<string> {
  if (!GEMINI_API_KEY) {
    if (prompt.includes("Dịch")) {
      return "[Bản dịch AI]: " + prompt.split('"')[1];
    }
    if (prompt.includes("nhà sáng tạo")) {
      return imageBase64
        ? "Một góc nhìn thật tuyệt vời qua ống kính hôm nay! 📸✨ #MiniSocial #PhotoOfTheDay"
        : "Khoảnh khắc tuyệt vời ngày hôm nay! ✨ #MiniSocial #LifeMoment";
    }
    return JSON.stringify({ isSafe: true, reason: "" });
  }

  const parts: any[] = [{ text: prompt }];

  if (imageBase64) {
    // Đưa dữ liệu ảnh dạng Base64 vào Gemini Multi-modal Part
    parts.unshift({
      inline_data: {
        mime_type: imageMimeType || "image/jpeg",
        data: imageBase64,
      },
    });
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts }],
    }),
  });

  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text || "";
}
