import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.8";

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

// Khởi tạo Supabase client dùng Service Role Key để bypass RLS cấu hình kiểm duyệt
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// ============================================================================
// FALLBACK RULES (Luật dự phòng nếu không kết nối được Database hoặc DB rỗng)
// ============================================================================
const FALLBACK_BLACKLIST_WORDS: string[] = [
  "đồ ngu", "con điên", "đm", "vãi đái",
  "gamebaidoithuong", "nhatvip", "hitclub", "go88", "sunwin", "vay tien nhanh",
];

const FALLBACK_BLACKLIST_PATTERNS: RegExp[] = [
  /(?:03|05|07|08|09)\d[\s.-]?\d{3}[\s.-]?\d{4}\b/g,
  /https?:\/\/(?:www\.)?(?:bit\.ly|tinyurl\.com|t\.me|cutt\.ly|shorturl\.at)/i,
];

// ============================================================================
// STAGE 1: INPUT VALIDATION
// ============================================================================
function validateInput(text?: string, imageBase64?: string): { isValid: boolean; reason: string } {
  const hasText = text && text.trim().length > 0;
  const hasImage = imageBase64 && imageBase64.trim().length > 0;

  if (!hasText && !hasImage) {
    return { isValid: false, reason: "Bài viết phải có ít nhất văn bản hoặc hình ảnh đính kèm." };
  }

  if (hasText && text!.length > 5000) {
    return { isValid: false, reason: "Văn bản bài viết quá dài (tối đa 5000 ký tự)." };
  }

  return { isValid: true, reason: "" };
}

// ============================================================================
// STAGE 2: NORMALIZATION (Anti-teencode, zero-width strip, accent removal)
// ============================================================================
function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .replace(/[\u200B-\u200D\uFEFF]/g, "")
    .normalize("NFD")
    .replace(/[\u0300-\u06ef]/g, "")
    .replace(/[\s._\-*,+=@#$%/\\|:;!"'()?{}[\]<>]/g, "");
}

// ============================================================================
// STAGE 2.5: WHITELIST BYPASS CHECK (Database Driven)
// ============================================================================
async function isWhitelisted(text: string): Promise<boolean> {
  try {
    const { data: whitelist } = await supabase
      .from("moderation_whitelist")
      .select("keyword");

    if (!whitelist || whitelist.length === 0) return false;

    const lowerText = text.toLowerCase();
    for (const item of whitelist) {
      if (lowerText.includes(item.keyword.toLowerCase())) {
        return true;
      }
    }
  } catch (_) {
    // Ignore error, proceed to moderation check
  }
  return false;
}

// ============================================================================
// STAGE 3: DATABASE-DRIVEN HARD RULE ENGINE (With Fallback)
// ============================================================================
async function runHardRuleEngine(text: string): Promise<{ isViolated: boolean; reason: string }> {
  if (!text || text.trim().length === 0) return { isViolated: false, reason: "" };

  const rawLower = text.toLowerCase();
  const normalized = normalizeText(text);

  try {
    // 1. Kiểm tra Keywords từ Database
    const { data: dbKeywords } = await supabase
      .from("moderation_keywords")
      .select("keyword, severity")
      .eq("is_active", true);

    if (dbKeywords && dbKeywords.length > 0) {
      for (const item of dbKeywords) {
        const word = item.keyword;
        const normWord = normalizeText(word);
        if (rawLower.includes(word.toLowerCase()) || normalized.includes(normWord)) {
          return {
            isViolated: true,
            reason: `Nội dung chứa từ ngữ vi phạm quy định cộng đồng (${word}).`,
          };
        }
      }
    } else {
      // Dùng Fallback local blacklist
      for (const word of FALLBACK_BLACKLIST_WORDS) {
        const normWord = normalizeText(word);
        if (rawLower.includes(word) || normalized.includes(normWord)) {
          return {
            isViolated: true,
            reason: `Nội dung chứa từ ngữ vi phạm quy định cộng đồng (${word}).`,
          };
        }
      }
    }

    // 2. Kiểm tra Regex Patterns từ Database
    const { data: dbRegex } = await supabase
      .from("moderation_regex_rules")
      .select("pattern")
      .eq("is_active", true);

    if (dbRegex && dbRegex.length > 0) {
      for (const item of dbRegex) {
        try {
          const regex = new RegExp(item.pattern, "i");
          if (regex.test(text)) {
            return {
              isViolated: true,
              reason: "Nội dung vi phạm cấu trúc quảng cáo hoặc spam độc hại.",
            };
          }
        } catch (_) {
          // Skip invalid regex pattern
        }
      }
    } else {
      // Dùng Fallback local regex patterns
      for (const pattern of FALLBACK_BLACKLIST_PATTERNS) {
        if (pattern.test(text)) {
          return {
            isViolated: true,
            reason: "Nội dung chứa số điện thoại hoặc liên kết quảng cáo rác không cho phép.",
          };
        }
      }
    }

    // 3. Kiểm tra Blocked Domains từ Database
    const { data: dbDomains } = await supabase
      .from("moderation_domains")
      .select("domain");

    if (dbDomains && dbDomains.length > 0) {
      for (const item of dbDomains) {
        const domainPattern = new RegExp(`https?:\\/\\/(?:www\\.)?${item.domain.replace(".", "\\.")}`, "i");
        if (domainPattern.test(text)) {
          return {
            isViolated: true,
            reason: `Liên kết tên miền bị chặn bởi hệ thống: ${item.domain}`,
          };
        }
      }
    }

    // 4. Kiểm tra Blocked Phones từ Database
    const { data: dbPhones } = await supabase
      .from("moderation_phones")
      .select("phone")
      .eq("status", "blocked");

    if (dbPhones && dbPhones.length > 0) {
      for (const item of dbPhones) {
        if (text.includes(item.phone)) {
          return {
            isViolated: true,
            reason: `Số điện thoại nằm trong danh sách đen quảng cáo rác.`,
          };
        }
      }
    }
  } catch (err) {
    console.error("Database hard rule query failed, fallback used: ", err);
    // Fallback toàn bộ nếu lỗi kết nối database
    for (const word of FALLBACK_BLACKLIST_WORDS) {
      const normWord = normalizeText(word);
      if (rawLower.includes(word) || normalized.includes(normWord)) {
        return { isViolated: true, reason: `Nội dung vi phạm tiêu chuẩn (${word}).` };
      }
    }
    for (const pattern of FALLBACK_BLACKLIST_PATTERNS) {
      if (pattern.test(text)) {
        return { isViolated: true, reason: "Nội dung chứa liên kết quảng cáo hoặc số điện thoại rác." };
      }
    }
  }

  return { isViolated: false, reason: "" };
}

// ============================================================================
// STAGE 4: SPAM DETECTION (Heuristic rules & pattern analysis)
// ============================================================================
function detectSpam(text: string): { isSpam: boolean; spamRisk: number; reason: string } {
  if (!text || text.trim().length === 0) {
    return { isSpam: false, spamRisk: 0, reason: "" };
  }

  let risk = 0;
  const reasons: string[] = [];

  const hashtags = text.match(/#[\w\u00C0-\u024F]+/g) || [];
  if (hashtags.length > 10) {
    risk += 35;
    reasons.push("Spam chèn quá nhiều hashtag");
  }

  if (text.length > 30 && text === text.toUpperCase() && /[A-Z]/.test(text)) {
    risk += 25;
    reasons.push("Sử dụng chữ in hoa toàn bộ (ALL CAPS)");
  }

  if (/(.)\1{6,}/i.test(text)) {
    risk += 30;
    reasons.push("Lặp lại ký tự bất thường");
  }

  const urls = text.match(/https?:\/\/[^\s]+/g) || [];
  if (urls.length > 3) {
    risk += 40;
    reasons.push("Chèn quá nhiều đường liên kết (link spam)");
  }

  return {
    isSpam: risk >= 50,
    spamRisk: risk,
    reason: reasons.join("; "),
  };
}

// ============================================================================
// HELPER TO SAVE MODERATION CASE & RESULTS TO DATABASE
// ============================================================================
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

async function logModerationCase({
  contentId,
  contentType,
  userId,
  riskScore,
  status,
  decision,
  aiToxicityScore,
  aiHateScore,
  aiSexualScore,
  aiViolenceScore,
  rawResponse,
}: {
  contentId?: string;
  contentType?: string;
  userId?: string;
  riskScore: number;
  status: string;
  decision: string;
  aiToxicityScore: number;
  aiHateScore: number;
  aiSexualScore: number;
  aiViolenceScore: number;
  rawResponse: any;
}) {
  if (!contentId || !contentType) return;

  try {
    let actionName = "allow";
    if (decision === "REJECT") actionName = "block";
    else if (decision === "HUMAN_REVIEW") actionName = "review";
    else if (decision === "SHADOW_BAN") actionName = "shadow_ban";

    const actionId = await getActionTypeId(actionName);

    // 1. Insert case
    const { data: caseData, error: caseError } = await supabase
      .from("moderation_cases")
      .insert({
        content_id: contentId,
        content_type: contentType,
        user_id: userId || null,
        risk_score: riskScore,
        status: status,
        final_action_id: actionId,
      })
      .select("id")
      .single();

    if (caseError || !caseData) {
      console.error("Error creating moderation case:", caseError);
      return;
    }

    // 2. Insert detailed scores into moderation_results
    const { error: resError } = await supabase
      .from("moderation_results")
      .insert({
        case_id: caseData.id,
        model_name: "gemini-3.5-flash-lite",
        toxicity_score: aiToxicityScore,
        hate_score: aiHateScore,
        scam_score: decision === "REJECT" && rawResponse.includes("scam") ? 1.0 : 0.0,
        sexual_score: aiSexualScore,
        violence_score: aiViolenceScore,
        raw_response: { raw: rawResponse },
      });

    if (resError) {
      console.error("Error creating moderation results:", resError);
    }
  } catch (err) {
    console.error("Failed to log moderation case:", err);
  }
}

// ============================================================================
// EDGE FUNCTION MAIN HANDLER
// ============================================================================
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, text, imageBase64, imageMimeType, targetLanguage, contentId, contentType, userId } = await req.json();

    // TRANSLATE
    if (action === "translate") {
      const lang = targetLanguage || "tiếng Việt";
      const prompt = lang.includes("nếu")
        ? `Hãy xác định ngôn ngữ của đoạn văn bản sau, sau đó dịch sang ngôn ngữ đối lập (nếu tiếng Việt → dịch sang tiếng Anh, nếu tiếng Anh hoặc tiếng nước ngoài khác → dịch sang tiếng Việt). Chỉ trả về bản dịch, không giải thích:\n"${text}"`
        : `Dịch đoạn văn bản sau sang ${lang}. Chỉ trả về duy nhất bản dịch, không giải thích gì thêm:\n"${text}"`;

      const response = await fetchFromGemini({ prompt });
      return new Response(JSON.stringify({ translatedText: response }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // GENERATE CAPTION
    if (action === "generate_caption") {
      const outputInstruction = "CHỈ TRẢ VỀ NỘI DUNG CAPTION VÀ HASHTAG TRỰC TIẾP. KHÔNG ĐƯỢC CHÈN LỜI CHÀO, LỜI KHUYÊN, DẪN DẮT HAY GIẢI THÍCH (như 'Chào bạn...', 'Đây là caption...').";

      const vibeInstruction = `
Về phong cách viết: Hãy đọc kỹ nội dung/ảnh và tự phán đoán tâm trạng, bối cảnh trước khi quyết định phong cách.
- Nếu bối cảnh vui vẻ, lãng mạn, tự tin, đang khoe bản thân, hay có đôi: có thể pha nhẹ "vibe thả thính" — tinh tế, duyên dáng, ngọt ngào, KHÔNG sến sẩm hay gượng ép.
- Nếu bối cảnh buồn, nhớ nhung, chia tay, mất mát, cô đơn, tâm sự, hay có chủ đề nghiêm túc (thiên tai, xã hội, sức khỏe, ẩm thực review thực chất, du lịch một mình theo phong cách trải nghiệm, ...): KHÔNG áp dụng thả thính — viết chân thành, đúng cảm xúc với bối cảnh đó.
- Nếu bối cảnh trung lập hoặc không rõ ràng: ưu tiên phong cách tươi tắn, tự nhiên, không cố gắng thêm vào gì.
`.trim();

      const hashtagRule = "QUAN TRỌNG: Hashtag PHẢI viết không dấu, không khoảng trắng, và chỉ dùng chữ cái Latin hoặc số (ví dụ đúng: #CafeSang, #HoiAn, #OiGioi, #CuocSong — ví dụ SAI: #CàPhéSáng, #HộiAn, #ÔiGiời).";

      let prompt = "";
      if (imageBase64 && text) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Nhìn vào bức ảnh này và kết hợp với ý tưởng: "${text}". Viết một caption hấp dẫn, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${hashtagRule} ${outputInstruction}`;
      } else if (imageBase64) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Phân tích bối cảnh, đối tượng và cảm xúc trong bức ảnh này, sau đó viết một caption sinh động, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${hashtagRule} ${outputInstruction}`;
      } else if (text) {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Dựa trên ý tưởng: "${text}", viết một caption ấn tượng, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${hashtagRule} ${outputInstruction}`;
      } else {
        prompt = `Hãy đóng vai một nhà sáng tạo nội dung mạng xã hội. Viết một caption tươi vui, chill và đáng yêu về một khoảnh khắc trong ngày, tối đa 10 câu kèm 2-4 hashtag. ${vibeInstruction} ${hashtagRule} ${outputInstruction}`;
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

    // MODERATE (6-STAGE MODERATION PIPELINE - DATABASE POWERED)
    if (action === "moderate") {
      // 📌 STAGE 1: INPUT VALIDATION
      const inputVal = validateInput(text, imageBase64);
      if (!inputVal.isValid) {
        return new Response(JSON.stringify({
          isSafe: false,
          decision: "REJECT",
          riskScore: 100,
          reason: inputVal.reason,
        }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 📌 STAGE 2.5: WHITELIST BYPASS CHECK
      const bypass = await isWhitelisted(text || "");
      if (bypass) {
        return new Response(JSON.stringify({
          isSafe: true,
          decision: "ALLOW",
          riskScore: 0,
          reason: "Nội dung thuộc danh sách trắng cho phép.",
        }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 📌 STAGE 3: HARD RULE ENGINE (DB-Driven)
      const hardCheck = await runHardRuleEngine(text || "");
      if (hardCheck.isViolated) {
        // Log direct reject case to db
        await logModerationCase({
          contentId,
          contentType,
          userId,
          riskScore: 100,
          status: "blocked",
          decision: "REJECT",
          aiToxicityScore: 1.0,
          aiHateScore: 0.0,
          aiSexualScore: 0.0,
          aiViolenceScore: 0.0,
          rawResponse: "Hard rule block: " + hardCheck.reason,
        });

        return new Response(JSON.stringify({
          isSafe: false,
          decision: "REJECT",
          riskScore: 100,
          reason: hardCheck.reason,
        }), {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      // 📌 STAGE 4: SPAM DETECTION
      const spamCheck = detectSpam(text || "");

      // 📌 STAGE 5: AI MODERATION (Gemini Multi-modal Deep Inspection)
      let aiRiskScore = 0;
      let aiReason = "";
      let aiViolated = false;
      let scoreToxicity = 0.0;
      let scoreHate = 0.0;
      let scoreSexual = 0.0;
      let scoreViolence = 0.0;

      const aiPrompt = `Bạn là hệ thống kiểm duyệt tiêu chuẩn cộng đồng mạng xã hội chuyên nghiệp (giống Facebook, Instagram, TikTok).
Nhiệm vụ: Phân tích bức ảnh (nếu có) VÀ đoạn văn bản: "${text || ''}".

Hãy đánh giá và cho điểm rủi ro (Risk Score từ 0 đến 100) theo các danh mục:
1. Nội dung khiêu dâm, khỏa thân, đồi trụy (Nudity/Explicit/NSFW) -> Đặt RiskScore = 100, scoreSexual = 1.0.
2. Bạo lực, máu me, kinh dị (Violence/Gore) -> Đặt RiskScore = 90 - 100, scoreViolence = 1.0.
3. Từ ngữ thù ghét, quấy rối, thô tục nặng, cá độ, ma túy -> Đặt RiskScore = 80 - 100, scoreHate = 1.0.
4. Spam nhẹ, giật gân, nhạy cảm mức trung bình -> Đặt RiskScore = 40 - 60.
5. An sau -> Đặt RiskScore = 0 - 20.

Trả về duy nhất định dạng JSON hợp lệ:
{
  "riskScore": 0_den_100, 
  "isSafe": true_hoac_false, 
  "scoreToxicity": 0.0_den_1.0,
  "scoreHate": 0.0_den_1.0,
  "scoreSexual": 0.0_den_1.0,
  "scoreViolence": 0.0_den_1.0,
  "reason": "Lý do ngắn gọn nếu có rủi ro"
}`;

      const aiResponse = await fetchFromGemini({
        prompt: aiPrompt,
        imageBase64,
        imageMimeType: imageMimeType || "image/jpeg",
      });

      try {
        const jsonMatch = aiResponse.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          const parsed = JSON.parse(jsonMatch[0]);
          aiRiskScore = typeof parsed.riskScore === "number" ? parsed.riskScore : (parsed.isSafe === false ? 100 : 0);
          aiReason = parsed.reason || "";
          aiViolated = parsed.isSafe === false;
          scoreToxicity = parsed.scoreToxicity || 0.0;
          scoreHate = parsed.scoreHate || 0.0;
          scoreSexual = parsed.scoreSexual || 0.0;
          scoreViolence = parsed.scoreViolence || 0.0;
        }
      } catch (_) {
        aiRiskScore = 0;
        aiReason = "";
      }

      // 📌 STAGE 6: RISK SCORING & DECISION ROUTING
      const totalRiskScore = Math.min(100, Math.max(aiRiskScore, spamCheck.spamRisk));

      let decision: "ALLOW" | "SHADOW_BAN" | "HUMAN_REVIEW" | "REJECT" = "ALLOW";
      let finalReason = aiReason || spamCheck.reason || "";
      let isSafe = true;
      let status = "approved";

      if (totalRiskScore >= 90 || aiViolated) {
        decision = "REJECT";
        isSafe = false;
        status = "blocked";
        if (!finalReason) finalReason = "Vi phạm tiêu chuẩn cộng đồng về an toàn nội dung.";
      } else if (totalRiskScore >= 70) {
        decision = "HUMAN_REVIEW";
        isSafe = false;
        status = "review";
        if (!finalReason) finalReason = "Nội dung cần được ban quản trị xem xét thủ công trước khi hiển thị.";
      } else if (totalRiskScore >= 35 || spamCheck.isSpam) {
        decision = "SHADOW_BAN";
        isSafe = true; // Cho đăng bài nhưng status = shadow_banned
        status = "review"; // Hoặc status phù hợp
        if (!finalReason) finalReason = "Bài viết bị giảm phân phối do có dấu hiệu spam.";
      }

      // Ghi log vào Database các ca kiểm duyệt
      await logModerationCase({
        contentId,
        contentType,
        userId,
        riskScore: totalRiskScore,
        status: status,
        decision: decision,
        aiToxicityScore: scoreToxicity,
        aiHateScore: scoreHate,
        aiSexualScore: scoreSexual,
        aiViolenceScore: scoreViolence,
        rawResponse: aiResponse,
      });

      return new Response(JSON.stringify({
        isSafe,
        decision,
        riskScore: totalRiskScore,
        reason: finalReason,
      }), {
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
    return JSON.stringify({ riskScore: 0, isSafe: true, reason: "" });
  }

  const parts: any[] = [{ text: prompt }];

  if (imageBase64) {
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
