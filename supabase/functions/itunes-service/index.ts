import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

const headers = {
  ...corsHeaders,
  "Content-Type": "application/json",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

async function fetchItunes(term: string, limit: number) {
  try {
    const url = `https://itunes.apple.com/search?term=${encodeURIComponent(term)}&media=music&entity=song&limit=${limit}`;
    const res = await fetch(url, {
      headers: { "User-Agent": "Viora/1.0 (itunes-service)" },
    });
    if (!res.ok) return [];
    const data = await res.json();
    return data.results || [];
  } catch (e) {
    console.error("fetchItunes error:", e);
    return [];
  }
}

serve(async (request) => {
  // Handle CORS preflight requests
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let term = "";
    let limit = 100;

    if (request.method === "POST") {
      try {
        const body = await request.json();
        if (typeof body.term === "string") {
          term = body.term.trim();
        }
        if (typeof body.limit === "number") {
          limit = Math.min(Math.max(body.limit, 1), 100);
        }
      } catch (_) {}
    } else if (request.method === "GET") {
      const url = new URL(request.url);
      const queryTerm = url.searchParams.get("term");
      if (queryTerm) term = queryTerm.trim();
      const queryLimit = url.searchParams.get("limit");
      if (queryLimit) limit = Math.min(Math.max(Number(queryLimit) || 100, 1), 100);
    }

    // Khi term rỗng (mới mở modal): Tải song song 4 thể loại (Nhạc Việt, US-UK Hits, V-Pop, Top Hits) trên Server Deno!
    if (!term) {
      const perCategoryLimit = Math.min(Math.max(Math.floor(limit / 4), 10), 25);
      const [viet, usuk, vpop, topHits] = await Promise.all([
        fetchItunes("nhac viet", perCategoryLimit),
        fetchItunes("us uk hit", perCategoryLimit),
        fetchItunes("v-pop", perCategoryLimit),
        fetchItunes("top hits", perCategoryLimit),
      ]);

      const seen = new Set<string>();
      const combined: any[] = [];
      const maxLen = Math.max(viet.length, usuk.length, vpop.length, topHits.length);

      for (let i = 0; i < maxLen; i++) {
        for (const list of [viet, usuk, vpop, topHits]) {
          if (i < list.length) {
            const track = list[i];
            const trackId = String(track.trackId || track.collectionId || track.trackName);
            if (trackId && !seen.has(trackId)) {
              seen.add(trackId);
              combined.push(track);
            }
          }
        }
      }

      return json({ resultCount: combined.length, results: combined }, 200);
    }

    // Khi có từ khóa tìm kiếm cụ thể
    const results = await fetchItunes(term, limit);
    return json({ resultCount: results.length, results }, 200);
  } catch (error) {
    console.error("itunes-service error:", error);
    return json({ error: "Failed to fetch music from iTunes", results: [] }, 500);
  }
});
