const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") || "";

const PROBABILITY_SCORE: Record<string, number> = {
  NEGLIGIBLE: 0.05,
  LOW: 0.35,
  MEDIUM: 0.65,
  HIGH: 0.95,
};

const CATEGORY_TO_REASON: Record<string, string> = {
  HARM_CATEGORY_HARASSMENT: "harassment",
  HARM_CATEGORY_HATE_SPEECH: "hate_speech",
  HARM_CATEGORY_SEXUALLY_EXPLICIT: "nudity_sexual",
  HARM_CATEGORY_DANGEROUS_CONTENT: "violence_gore",
};

export async function checkGeminiSafety(text: string, imageBase64?: string, imageMimeType?: string) {
  if (!GEMINI_API_KEY) {
    return { severityScore: 0, labels: {} };
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${GEMINI_API_KEY}`;

  const parts: any[] = [{ text: text || "" }];
  if (imageBase64) {
    parts.push({ inline_data: { mime_type: imageMimeType || "image/jpeg", data: imageBase64 } });
  }

  const safetySettings = [
    "HARM_CATEGORY_HARASSMENT",
    "HARM_CATEGORY_HATE_SPEECH",
    "HARM_CATEGORY_SEXUALLY_EXPLICIT",
    "HARM_CATEGORY_DANGEROUS_CONTENT",
  ].map((category) => ({ category, threshold: "BLOCK_LOW_AND_ABOVE" }));

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contents: [{ parts }],
      safetySettings,
      generationConfig: { maxOutputTokens: 1 },
    }),
  });

  if (!res.ok) {
    throw new Error(`Gemini safety check error: ${res.status} ${await res.text()}`);
  }

  const json = await res.json();
  const feedback = json.promptFeedback;

  if (feedback?.blockReason) {
    return { severityScore: 1.0, labels: { blocked_by_gemini: feedback.blockReason } };
  }

  const ratings = json.candidates?.[0]?.safetyRatings ?? feedback?.safetyRatings ?? [];
  const labels: Record<string, number> = {};
  let maxScore = 0;

  for (const r of ratings) {
    const score = PROBABILITY_SCORE[r.probability] ?? 0;
    const reasonKey = CATEGORY_TO_REASON[r.category] ?? r.category;
    labels[reasonKey] = score;
    if (score > maxScore) maxScore = score;
  }

  return { severityScore: maxScore, labels };
}
