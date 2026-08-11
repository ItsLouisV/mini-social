import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

// Keep this function self-contained so it can be deployed from both the
// Supabase Dashboard editor and the CLI (Dashboard does not bundle _shared).
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const headers = {
  ...corsHeaders,
  "Content-Type": "application/json",
};
const userAgent = "Viora/1.0 (places-service)";

type Place = {
  provider_place_id: string;
  name: string;
  address?: string;
  latitude: number;
  longitude: number;
  provider: "openstreetmap";
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers });
}

function validCoordinate(value: unknown, min: number, max: number) {
  return typeof value === "number" && Number.isFinite(value) && value >= min && value <= max;
}

function nominatimPlace(item: Record<string, unknown>): Place {
  const address = (item.address ?? {}) as Record<string, unknown>;
  const name = String(
    item.name ?? address.amenity ?? address.tourism ?? address.shop ??
      address.building ?? address.road ?? String(item.display_name ?? "").split(",")[0],
  );
  return {
    provider_place_id: `osm:${item.osm_type ?? "place"}:${item.osm_id ?? item.place_id}`,
    name,
    address: String(item.display_name ?? ""),
    latitude: Number(item.lat),
    longitude: Number(item.lon),
    provider: "openstreetmap",
  };
}

serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const { action, query, latitude, longitude } = await request.json();
    if (!["nearby", "search", "reverse"].includes(action)) {
      return json({ error: "Invalid action" }, 400);
    }

    if (action === "search") {
      const cleanQuery = String(query ?? "").trim().slice(0, 120);
      if (cleanQuery.length < 2) return json({ places: [] });
      const url = new URL("https://nominatim.openstreetmap.org/search");
      url.searchParams.set("format", "jsonv2");
      url.searchParams.set("addressdetails", "1");
      url.searchParams.set("limit", "15");
      url.searchParams.set("accept-language", "vi,en");
      url.searchParams.set("q", cleanQuery);
      if (validCoordinate(latitude, -90, 90) && validCoordinate(longitude, -180, 180)) {
        const delta = 0.25;
        url.searchParams.set("viewbox", `${longitude - delta},${latitude + delta},${longitude + delta},${latitude - delta}`);
      }
      const response = await fetch(url, { headers: { "User-Agent": userAgent } });
      if (!response.ok) throw new Error(`Search provider returned ${response.status}`);
      const items = await response.json();
      return json({ places: items.map(nominatimPlace) });
    }

    if (!validCoordinate(latitude, -90, 90) || !validCoordinate(longitude, -180, 180)) {
      return json({ error: "Invalid coordinates" }, 400);
    }

    if (action === "reverse") {
      const url = new URL("https://nominatim.openstreetmap.org/reverse");
      url.searchParams.set("format", "jsonv2");
      url.searchParams.set("addressdetails", "1");
      url.searchParams.set("zoom", "18");
      url.searchParams.set("lat", String(latitude));
      url.searchParams.set("lon", String(longitude));
      const response = await fetch(url, { headers: { "User-Agent": userAgent } });
      if (!response.ok) throw new Error(`Reverse provider returned ${response.status}`);
      return json({ places: [nominatimPlace(await response.json())] });
    }

    const overpassQuery = `[out:json][timeout:12];nwr(around:3000,${latitude},${longitude})[name][amenity];out center 30;`;
    const response = await fetch("https://overpass-api.de/api/interpreter", {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": userAgent },
      body: new URLSearchParams({ data: overpassQuery }),
    });
    if (!response.ok) throw new Error(`Nearby provider returned ${response.status}`);
    const data = await response.json();
    const places: Place[] = data.elements.map((item: Record<string, unknown>) => {
      const tags = (item.tags ?? {}) as Record<string, unknown>;
      const center = (item.center ?? {}) as Record<string, unknown>;
      return {
        provider_place_id: `osm:${item.type}:${item.id}`,
        name: String(tags.name ?? ""),
        address: [tags["addr:housenumber"], tags["addr:street"], tags["addr:city"]].filter(Boolean).join(" "),
        latitude: Number(item.lat ?? center.lat),
        longitude: Number(item.lon ?? center.lon),
        provider: "openstreetmap",
      };
    }).filter((item: Place) => item.name && Number.isFinite(item.latitude) && Number.isFinite(item.longitude));
    return json({ places });
  } catch (error) {
    console.error("places-service", error);
    return json({ error: "Places service unavailable" }, 502);
  }
});
