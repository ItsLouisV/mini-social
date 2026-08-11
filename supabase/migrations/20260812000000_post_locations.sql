-- Structured, user-selected location snapshot for posts.
ALTER TABLE public.posts
  ADD COLUMN IF NOT EXISTS location_place_id TEXT,
  ADD COLUMN IF NOT EXISTS location_name TEXT,
  ADD COLUMN IF NOT EXISTS location_address TEXT,
  ADD COLUMN IF NOT EXISTS location_latitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_longitude DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS location_provider TEXT;

ALTER TABLE public.posts
  ADD CONSTRAINT posts_location_coordinates_check CHECK (
    (location_name IS NULL AND location_latitude IS NULL AND location_longitude IS NULL)
    OR
    (location_name IS NOT NULL
      AND location_latitude BETWEEN -90 AND 90
      AND location_longitude BETWEEN -180 AND 180)
  );

CREATE INDEX IF NOT EXISTS posts_location_coordinates_idx
  ON public.posts (location_latitude, location_longitude)
  WHERE deleted_at IS NULL AND location_name IS NOT NULL;

COMMENT ON COLUMN public.posts.location_name IS
  'Snapshot of the place explicitly selected by the post author.';
