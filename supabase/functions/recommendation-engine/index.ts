import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const MAX_EVENTS_PER_REQUEST = 50;
const ALLOWED_EVENTS = new Set([
  "impression", "view_dwell", "image_click", "like", "comment",
  "share", "hide", "not_interested", "report",
]);

type PostFlags = {
  id: string;
  is_ai_generated: boolean | null;
  moderation_status: string | null;
  layout_type: string | null;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};
const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" };

function json(data: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(data), { status, headers: jsonHeaders });
}

function integer(value: string | null, fallback: number, min: number, max: number): number {
  const parsed = Number.parseInt(value ?? "", 10);
  return Number.isFinite(parsed) ? Math.min(max, Math.max(min, parsed)) : fallback;
}

function isUuid(value: unknown): value is string {
  return typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

serve(async (req: Request): Promise<Response> => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const authorization = req.headers.get("Authorization");
  if (!authorization) return json({ error: "Authentication required", code: "UNAUTHENTICATED" }, 401);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: authError } = await userClient.auth.getUser();
  if (authError || !user) return json({ error: "Invalid or expired session", code: "UNAUTHENTICATED" }, 401);

  try {
    const url = new URL(req.url);
    const action = url.searchParams.get("action") ?? "feed";

    if (req.method === "POST" && action === "track") {
      const body = await req.json().catch(() => ({}));
      const rawEvents = Array.isArray(body.events) ? body.events : [body];
      if (rawEvents.length === 0 || rawEvents.length > MAX_EVENTS_PER_REQUEST) {
        return json({ error: `events must contain 1-${MAX_EVENTS_PER_REQUEST} items`, code: "INVALID_EVENTS" }, 400);
      }

      const events = rawEvents.map((event: Record<string, unknown>) => {
        if (!isUuid(event.postId) || !isUuid(event.eventId) || !ALLOWED_EVENTS.has(String(event.interactionType))) {
          throw new Error("INVALID_EVENT");
        }
        const durationMs = Math.min(600_000, Math.max(0, Number(event.durationMs) || 0));
        const visibleRatio = event.visibleRatio == null ? null : Math.min(1, Math.max(0, Number(event.visibleRatio)));
        return {
          event_id: event.eventId,
          user_id: user.id,
          post_id: event.postId,
          event_type: event.interactionType,
          session_id: isUuid(event.sessionId) ? event.sessionId : null,
          request_id: isUuid(event.requestId) ? event.requestId : null,
          position: Number.isInteger(Number(event.position)) && Number(event.position) >= 0
            ? Number(event.position)
            : null,
          source: typeof event.source === "string" ? event.source.slice(0, 40) : null,
          visible_ratio: visibleRatio,
          duration_ms: Math.round(durationMs),
          metadata: typeof event.metadata === "object" && event.metadata !== null ? event.metadata : {},
        };
      });

      const { error } = await admin.from("recommendation_events").upsert(events, {
        onConflict: "event_id", ignoreDuplicates: true,
      });
      if (error) throw error;

      const negative = events.filter((e) => e.event_type === "hide" || e.event_type === "not_interested" || e.event_type === "report");
      if (negative.length > 0) {
        const { error: dismissalError } = await admin.from("recommendation_dismissals").upsert(
          negative.map((e) => ({ user_id: user.id, entity_type: "post", entity_id: e.post_id, reason: e.event_type })),
          { onConflict: "user_id,entity_type,entity_id" },
        );
        if (dismissalError) throw dismissalError;
      }
      return json({ success: true, accepted: events.length });
    }

    if (req.method === "POST" && action === "dismiss-profile") {
      const body = await req.json().catch(() => ({}));
      if (!isUuid(body.profileId)) return json({ error: "Invalid profileId", code: "INVALID_INPUT" }, 400);
      const { error } = await admin.from("recommendation_dismissals").upsert({
        user_id: user.id, entity_type: "profile", entity_id: body.profileId, reason: "dismissed",
      }, { onConflict: "user_id,entity_type,entity_id" });
      if (error) throw error;
      return json({ success: true });
    }

    // Supabase Flutter `functions.invoke` gửi POST theo mặc định, kể cả khi chỉ
    // truyền queryParameters. Feed/PYMK là read-only nhưng chấp nhận cả GET và
    // POST để hợp đồng HTTP tương thích với SDK.
    if (req.method !== "GET" && req.method !== "POST") {
      return json({ error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, 405);
    }

    if (action === "pymk") {
      const limit = integer(url.searchParams.get("limit"), 10, 1, 30);
      const { data, error } = await userClient.rpc("get_people_you_may_know_v2", { p_limit: limit });
      if (error) throw error;
      return json({ success: true, candidates: data ?? [], rankerVersion: "pymk-v2" });
    }

    if (action !== "feed") return json({ error: "Unknown action", code: "UNKNOWN_ACTION" }, 400);
    const limit = integer(url.searchParams.get("limit"), 20, 1, 50);
    const cursorScoreRaw = url.searchParams.get("cursorScore");
    const cursorCreatedAt = url.searchParams.get("cursorCreatedAt");
    const cursorPostId = url.searchParams.get("cursorPostId");
    const cursorScore = cursorScoreRaw == null ? null : Number(cursorScoreRaw);
    const hasCursor = cursorScore != null && Number.isFinite(cursorScore) && cursorCreatedAt != null && isUuid(cursorPostId);
    if (cursorScoreRaw != null && !hasCursor) return json({ error: "Invalid cursor", code: "INVALID_CURSOR" }, 400);

    const { data: rankedPosts, error: rpcError } = await userClient.rpc("get_recommended_feed_v2", {
      p_limit: limit,
      p_cursor_score: hasCursor ? cursorScore : null,
      p_cursor_created_at: hasCursor ? cursorCreatedAt : null,
      p_cursor_post_id: hasCursor ? cursorPostId : null,
    });
    if (rpcError) throw rpcError;
    if (!rankedPosts?.length) return json({ success: true, posts: [], nextCursor: null, rankerVersion: "feed-v2" });

    const postIds = rankedPosts.map((p: Record<string, unknown>) => p.post_id as string);
    const authorIds = [...new Set(rankedPosts.map((p: Record<string, unknown>) => p.user_id as string))];
    const [{ data: authors, error: authorsError }, { data: media, error: mediaError }, { data: likes, error: likesError }, { data: flags, error: flagsError }] = await Promise.all([
      admin.from("profiles").select("id, username, full_name, avatar_url, created_at").in("id", authorIds),
      admin.from("post_media").select("id, post_id, url, type, order_index, created_at, width, height, aspect_ratio, thumbnail_url").in("post_id", postIds).order("order_index"),
      admin.from("likes").select("post_id").eq("user_id", user.id).in("post_id", postIds),
      admin.from("posts").select("id, is_ai_generated, moderation_status, layout_type").in("id", postIds),
    ]);
    if (authorsError || mediaError || likesError || flagsError) throw authorsError ?? mediaError ?? likesError ?? flagsError;

    const authorMap = new Map((authors ?? []).map((a) => [a.id, a]));
    const mediaMap = new Map<string, Record<string, unknown>[]>();
    for (const item of media ?? []) mediaMap.set(item.post_id, [...(mediaMap.get(item.post_id) ?? []), item]);
    const liked = new Set((likes ?? []).map((item) => item.post_id));
    const flagMap = new Map<string, PostFlags>(
      (flags ?? []).map((item) => {
        const typedItem = item as PostFlags;
        return [typedItem.id, typedItem];
      }),
    );
    const posts = rankedPosts.map((post: Record<string, unknown>) => ({
      id: post.post_id, user_id: post.user_id, caption: post.caption,
      likes_count: post.likes_count, comments_count: post.comments_count,
      privacy: post.privacy, created_at: post.created_at,
      profiles: authorMap.get(post.user_id as string) ?? null,
      post_media: mediaMap.get(post.post_id as string) ?? [],
      is_liked: liked.has(post.post_id),
      is_ai_generated: flagMap.get(post.post_id as string)?.is_ai_generated ?? false,
      moderation_status: flagMap.get(post.post_id as string)?.moderation_status ?? "published",
      layout_type: flagMap.get(post.post_id as string)?.layout_type ?? "grid",
      recommendation_score: post.score,
      recommendation_source: post.source,
      recommendation_reasons: post.reason_codes ?? [],
    }));
    const last = rankedPosts[rankedPosts.length - 1];
    return json({
      success: true, posts, rankerVersion: "feed-v2",
      nextCursor: rankedPosts.length < limit ? null : {
        score: last.score, createdAt: last.created_at, postId: last.post_id,
      },
    });
  } catch (error) {
    if (error instanceof Error && error.message === "INVALID_EVENT") {
      return json({ error: "Invalid recommendation event", code: "INVALID_EVENT" }, 400);
    }
    console.error("recommendation-engine error", error);
    return json({ error: "Recommendation service unavailable", code: "INTERNAL_ERROR" }, 500);
  }
});
