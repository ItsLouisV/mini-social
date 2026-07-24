import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.8";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

/**
 * RECOMMENDATION ENGINE EDGE FUNCTION
 * Endpoint hỗ trợ:
 * - GET ?action=feed&userId=...&limit=20&offset=0  : Xếp hạng bài viết cho Feed
 * - GET ?action=pymk&userId=...&limit=10           : Gợi ý kết bạn People You May Know
 * - POST ?action=track                              : Lưu lịch sử tương tác ẩn (dwell time, clicks)
 */
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const url = new URL(req.url);
    const action = url.searchParams.get("action") || "feed";

    // ── 1. ACTION: TRACK IMPLICIT INTERACTION ──
    if (req.method === "POST" && action === "track") {
      const body = await req.json();
      const { userId, postId, interactionType, durationMs } = body;

      if (!userId || !postId || !interactionType) {
        return new Response(
          JSON.stringify({ error: "Missing required fields: userId, postId, interactionType" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { error } = await supabase.from("user_interactions").insert({
        user_id: userId,
        post_id: postId,
        interaction_type: interactionType,
        duration_ms: durationMs || 0,
      });

      if (error) {
        throw error;
      }

      return new Response(
        JSON.stringify({ success: true, message: "Interaction tracked successfully" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 2. ACTION: PEOPLE YOU MAY KNOW (PYMK) ──
    if (action === "pymk") {
      const userId = url.searchParams.get("userId");
      const limit = parseInt(url.searchParams.get("limit") || "10", 10);

      if (!userId) {
        return new Response(
          JSON.stringify({ error: "Missing parameter: userId" }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data, error } = await supabase.rpc("get_people_you_may_know", {
        p_user_id: userId,
        p_limit: limit,
      });

      if (error) {
        throw error;
      }

      return new Response(
        JSON.stringify({ success: true, candidates: data || [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── 3. ACTION: RECOMMENDED FEED (DEFAULT) ──
    const userId = url.searchParams.get("userId");
    const limit = parseInt(url.searchParams.get("limit") || "20", 10);
    const offset = parseInt(url.searchParams.get("offset") || "0", 10);

    if (!userId) {
      return new Response(
        JSON.stringify({ error: "Missing parameter: userId" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Gọi RPC xếp hạng Feed
    const { data: rankedPosts, error: rpcError } = await supabase.rpc("get_recommended_feed", {
      p_user_id: userId,
      p_limit: limit,
      p_offset: offset,
    });

    if (rpcError) {
      throw rpcError;
    }

    if (!rankedPosts || rankedPosts.length === 0) {
      return new Response(
        JSON.stringify({ success: true, posts: [] }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const postIds = rankedPosts.map((p: any) => p.post_id);
    const authorIds = Array.from(new Set(rankedPosts.map((p: any) => p.user_id)));

    // Lấy thông tin tác giả bài viết
    const { data: authors } = await supabase
      .from("profiles")
      .select("id, username, full_name, avatar_url, created_at")
      .in("id", authorIds);

    const authorMap = new Map((authors || []).map((a: any) => [a.id, a]));

    // Lấy media bài viết
    const { data: mediaList } = await supabase
      .from("post_media")
      .select("id, post_id, url, type, order_index")
      .in("post_id", postIds)
      .order("order_index", { ascending: true });

    const mediaMap = new Map<string, any[]>();
    (mediaList || []).forEach((m: any) => {
      const list = mediaMap.get(m.post_id) || [];
      list.push(m);
      mediaMap.set(m.post_id, list);
    });

    // Lấy trạng thái likes của user hiện tại
    const { data: myLikes } = await supabase
      .from("likes")
      .select("post_id")
      .eq("user_id", userId)
      .in("post_id", postIds);

    const likedPostIds = new Set((myLikes || []).map((l: any) => l.post_id));

    // Format danh sách hoàn chỉnh bài đăng cho Client
    const formattedPosts = rankedPosts.map((p: any) => {
      const author = authorMap.get(p.user_id) || {
        id: p.user_id,
        username: "user",
        full_name: "Người dùng",
        avatar_url: null,
      };
      const media = mediaMap.get(p.post_id) || [];

      return {
        id: p.post_id,
        userId: p.user_id,
        caption: p.caption,
        likesCount: p.likes_count,
        commentsCount: p.comments_count,
        privacy: p.privacy,
        createdAt: p.created_at,
        isLiked: likedPostIds.has(p.post_id),
        score: p.score,
        user: author,
        media: media.map((m: any) => ({
          id: m.id,
          postId: m.post_id,
          url: m.url,
          type: m.type,
          orderIndex: m.order_index,
        })),
      };
    });

    return new Response(
      JSON.stringify({ success: true, posts: formattedPosts }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
