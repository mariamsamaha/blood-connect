-- BloodConnect: Three-feature migration
-- Run AFTER the existing schema and RLS migration.
-- File: supabase/migrations/20250524000000_stories_coupons_ai.sql
-- ─────────────────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════════════════════
-- FEATURE 1: User Stories
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.user_stories (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  author_id     UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  role          TEXT NOT NULL CHECK (role IN ('donor', 'recipient')),
  title         TEXT NOT NULL CHECK (char_length(title) BETWEEN 5 AND 120),
  body          TEXT NOT NULL CHECK (char_length(body) BETWEEN 50 AND 2000),
  blood_type    TEXT,                        -- optional, shown as context
  likes_count   INT NOT NULL DEFAULT 0,
  is_approved   BOOLEAN NOT NULL DEFAULT FALSE, -- moderation flag
  is_featured   BOOLEAN NOT NULL DEFAULT FALSE, -- pinned to top
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Track who liked which story (prevent double-likes)
CREATE TABLE IF NOT EXISTS public.story_likes (
  story_id   UUID NOT NULL REFERENCES public.user_stories(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (story_id, user_id)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_stories_approved_created
  ON public.user_stories (created_at DESC)
  WHERE is_approved = TRUE;

CREATE INDEX IF NOT EXISTS idx_stories_featured
  ON public.user_stories (created_at DESC)
  WHERE is_featured = TRUE AND is_approved = TRUE;

CREATE INDEX IF NOT EXISTS idx_stories_author
  ON public.user_stories (author_id);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

DROP TRIGGER IF EXISTS trg_stories_updated_at ON public.user_stories;
CREATE TRIGGER trg_stories_updated_at
  BEFORE UPDATE ON public.user_stories
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Atomic like/unlike toggle
CREATE OR REPLACE FUNCTION public.toggle_story_like(
  p_story_id UUID,
  p_user_id  UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_liked BOOLEAN;
BEGIN
  -- Check if already liked
  IF EXISTS (
    SELECT 1 FROM public.story_likes
    WHERE story_id = p_story_id AND user_id = p_user_id
  ) THEN
    -- Unlike
    DELETE FROM public.story_likes
    WHERE story_id = p_story_id AND user_id = p_user_id;

    UPDATE public.user_stories
    SET likes_count = GREATEST(0, likes_count - 1)
    WHERE id = p_story_id;

    v_liked := FALSE;
  ELSE
    -- Like
    INSERT INTO public.story_likes (story_id, user_id)
    VALUES (p_story_id, p_user_id)
    ON CONFLICT DO NOTHING;

    UPDATE public.user_stories
    SET likes_count = likes_count + 1
    WHERE id = p_story_id;

    v_liked := TRUE;
  END IF;

  RETURN jsonb_build_object('liked', v_liked);
END; $$;

-- RLS for user_stories
ALTER TABLE public.user_stories ENABLE ROW LEVEL SECURITY;

CREATE POLICY stories_read ON public.user_stories
  FOR SELECT USING (is_approved = TRUE OR author_id = auth.uid()::UUID);

CREATE POLICY stories_insert ON public.user_stories
  FOR INSERT WITH CHECK (author_id = auth.uid()::UUID);

CREATE POLICY stories_update ON public.user_stories
  FOR UPDATE USING (author_id = auth.uid()::UUID)
  WITH CHECK (author_id = auth.uid()::UUID);

-- RLS for story_likes
ALTER TABLE public.story_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY story_likes_read ON public.story_likes FOR SELECT USING (TRUE);
CREATE POLICY story_likes_write ON public.story_likes
  FOR ALL USING (user_id = auth.uid()::UUID);

-- Seed a few example approved stories for the demo
INSERT INTO public.user_stories
  (author_id, role, title, body, blood_type, likes_count, is_approved, is_featured)
SELECT
  u.id,
  'donor',
  'I saved my neighbour''s daughter',
  'Last Ramadan I got a notification at 2am about an O- request 3km away. I almost ignored it. But I went. Turns out it was a 7-year-old who had been in an accident. The mother was crying outside the hospital. She didn''t even know my name but she held my hand and said "you gave her time." I donate every year now. This app made it feel real.',
  'O-',
  47,
  TRUE,
  TRUE
FROM public.users u
WHERE u.account_type = 'regular'
LIMIT 1
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FEATURE 2: Coupons & Redemption
-- ═══════════════════════════════════════════════════════════════════════════════

-- Coupon templates (defined by admin/hospital partnerships)
CREATE TABLE IF NOT EXISTS public.coupons (
  id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code_prefix       TEXT NOT NULL DEFAULT 'BC',  -- coupon codes will be BC-XXXX-XXXX
  title             TEXT NOT NULL,               -- "10% off blood test at Al Salam Lab"
  description       TEXT NOT NULL,
  partner_name      TEXT NOT NULL,               -- "Al Salam Medical Lab"
  partner_logo_url  TEXT,
  discount_pct      INT NOT NULL CHECK (discount_pct BETWEEN 1 AND 100),
  points_cost       INT NOT NULL DEFAULT 500,    -- reward points needed to redeem
  total_available   INT NOT NULL DEFAULT 1000,
  total_redeemed    INT NOT NULL DEFAULT 0,
  valid_until       TIMESTAMPTZ,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- User coupon instances (one row per redemption)
CREATE TABLE IF NOT EXISTS public.user_coupons (
  id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id       UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  coupon_id     UUID NOT NULL REFERENCES public.coupons(id),
  coupon_code   TEXT NOT NULL UNIQUE,            -- BC-A1B2-C3D4
  redeemed_at   TIMESTAMPTZ DEFAULT NOW(),
  used_at       TIMESTAMPTZ,                     -- NULL = not yet used at partner
  expires_at    TIMESTAMPTZ DEFAULT (NOW() + INTERVAL '90 days'),
  points_spent  INT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_user_coupons_user
  ON public.user_coupons (user_id, redeemed_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_coupons_code
  ON public.user_coupons (coupon_code);

-- Atomic redeem: deducts points and issues coupon in one transaction
CREATE OR REPLACE FUNCTION public.redeem_coupon(
  p_user_id   UUID,
  p_coupon_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_coupon    RECORD;
  v_user      RECORD;
  v_code      TEXT;
  v_coupon_id UUID;
BEGIN
  -- Lock coupon row
  SELECT * INTO v_coupon FROM public.coupons
  WHERE id = p_coupon_id AND is_active = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'coupon_not_found');
  END IF;

  IF v_coupon.valid_until IS NOT NULL AND v_coupon.valid_until < NOW() THEN
    RETURN jsonb_build_object('error', 'coupon_expired');
  END IF;

  IF v_coupon.total_redeemed >= v_coupon.total_available THEN
    RETURN jsonb_build_object('error', 'coupon_sold_out');
  END IF;

  -- Check user points
  SELECT * INTO v_user FROM public.users
  WHERE id = p_user_id FOR UPDATE;

  IF v_user.reward_points < v_coupon.points_cost THEN
    RETURN jsonb_build_object('error', 'insufficient_points',
      'have', v_user.reward_points, 'need', v_coupon.points_cost);
  END IF;

  -- Generate unique code: BC-XXXX-XXXX
  LOOP
    v_code := v_coupon.code_prefix || '-'
      || UPPER(SUBSTRING(md5(random()::TEXT) FROM 1 FOR 4)) || '-'
      || UPPER(SUBSTRING(md5(random()::TEXT) FROM 1 FOR 4));
    EXIT WHEN NOT EXISTS (
      SELECT 1 FROM public.user_coupons WHERE coupon_code = v_code
    );
  END LOOP;

  -- Deduct points
  UPDATE public.users
  SET reward_points = reward_points - v_coupon.points_cost
  WHERE id = p_user_id;

  -- Increment redeemed counter
  UPDATE public.coupons
  SET total_redeemed = total_redeemed + 1
  WHERE id = p_coupon_id;

  -- Issue coupon
  INSERT INTO public.user_coupons
    (user_id, coupon_id, coupon_code, points_spent)
  VALUES
    (p_user_id, p_coupon_id, v_code, v_coupon.points_cost)
  RETURNING id INTO v_coupon_id;

  RETURN jsonb_build_object(
    'success', TRUE,
    'coupon_code', v_code,
    'user_coupon_id', v_coupon_id,
    'points_remaining', v_user.reward_points - v_coupon.points_cost
  );
END; $$;

-- RLS for coupons
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY coupons_read ON public.coupons FOR SELECT USING (is_active = TRUE);

ALTER TABLE public.user_coupons ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_coupons_own ON public.user_coupons
  FOR ALL USING (user_id = auth.uid()::UUID);

-- Seed demo coupon
INSERT INTO public.coupons
  (title, description, partner_name, discount_pct, points_cost, total_available, is_active)
VALUES
  (
    '10% off blood tests',
    'Get 10% off any blood test panel at our partner labs. Valid for 90 days after redemption. Show the coupon code at the lab reception.',
    'Al Salam Medical Lab',
    10,
    500,
    1000,
    TRUE
  ),
  (
    '15% off full health screening',
    'Redeem for a 15% discount on a comprehensive health screening package including CBC, lipid panel, and blood glucose.',
    'Cleopatra Hospital Labs',
    15,
    800,
    500,
    TRUE
  )
ON CONFLICT DO NOTHING;

-- ═══════════════════════════════════════════════════════════════════════════════
-- FEATURE 3: AI Eligibility — audit log column
-- ═══════════════════════════════════════════════════════════════════════════════

-- Add AI check result to donor_responses for audit trail
ALTER TABLE public.donor_responses
  ADD COLUMN IF NOT EXISTS ai_eligibility_score NUMERIC(4,3),  -- 0.000–1.000
  ADD COLUMN IF NOT EXISTS ai_eligibility_passed BOOLEAN,
  ADD COLUMN IF NOT EXISTS ai_checked_at TIMESTAMPTZ;
