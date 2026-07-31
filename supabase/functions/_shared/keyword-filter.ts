export function normalizeText(text: string): string {
  return text
    .toLowerCase()
    .normalize("NFC")
    .replace(/[.\-_*+~`'"!@#$%^&()[\]{}|\\/:;<>,?=]/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export interface KeywordRow {
  pattern: string;
  match_type: "exact" | "regex";
  severity: "zero_tolerance" | "flag_for_review";
  category: string;
}

export function checkKeywords(rawText: string, keywords: KeywordRow[]) {
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
