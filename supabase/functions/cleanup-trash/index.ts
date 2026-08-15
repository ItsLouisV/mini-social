import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const POSTS_BUCKET = "posts";
const RETENTION_DAYS = 30;
const BATCH_SIZE = 100;

const jsonHeaders = {
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "no-store",
};

function json(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function storagePath(row: { path?: string | null; url?: string | null }): string | null {
  if (row.path?.trim()) return row.path.trim();
  if (!row.url) return null;

  const marker = `/storage/v1/object/public/${POSTS_BUCKET}/`;
  const markerIndex = row.url.indexOf(marker);
  if (markerIndex >= 0) {
    return decodeURIComponent(row.url.substring(markerIndex + marker.length));
  }

  const legacyMarker = `/${POSTS_BUCKET}/`;
  const legacyIndex = row.url.lastIndexOf(legacyMarker);
  return legacyIndex >= 0
    ? decodeURIComponent(row.url.substring(legacyIndex + legacyMarker.length))
    : null;
}

serve(async (request: Request): Promise<Response> => {
  if (request.method !== "POST") {
    return json({ error: "Method not allowed", code: "METHOD_NOT_ALLOWED" }, 405);
  }

  const expectedAuthorization = `Bearer ${SERVICE_ROLE_KEY}`;
  if (!SERVICE_ROLE_KEY || request.headers.get("Authorization") !== expectedAuthorization) {
    return json({ error: "Unauthorized", code: "UNAUTHORIZED" }, 401);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const cutoff = new Date(
    Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000,
  ).toISOString();

  const { data: posts, error: fetchError } = await admin
    .from("posts")
    .select("id, post_media(path, url)")
    .not("deleted_at", "is", null)
    .lte("deleted_at", cutoff)
    .order("deleted_at", { ascending: true })
    .limit(BATCH_SIZE);

  if (fetchError) return json({ error: fetchError.message }, 500);
  if (!posts?.length) return json({ deletedPosts: 0, deletedFiles: 0, cutoff });

  const paths = [...new Set(posts.flatMap((post) =>
    ((post.post_media ?? []) as Array<{ path?: string | null; url?: string | null }>)
      .map(storagePath)
      .filter((path): path is string => Boolean(path))
  ))];

  let deletedFiles = 0;
  for (let index = 0; index < paths.length; index += BATCH_SIZE) {
    const batch = paths.slice(index, index + BATCH_SIZE);
    const { error: storageError } = await admin.storage.from(POSTS_BUCKET).remove(batch);
    if (storageError) {
      return json({
        error: storageError.message,
        code: "STORAGE_DELETE_FAILED",
        deletedFiles,
        postsPreserved: posts.length,
      }, 500);
    }
    deletedFiles += batch.length;
  }

  const postIds = posts.map((post) => post.id as string);
  const { error: deleteError } = await admin.from("posts").delete().in("id", postIds);
  if (deleteError) return json({ error: deleteError.message, deletedFiles }, 500);

  return json({ deletedPosts: postIds.length, deletedFiles, cutoff });
});
