-- BloodConnect Row Level Security
-- Apply in Supabase SQL editor or via: supabase db push
-- Client apps must use the API BFF (service role) or authenticated role with firebase_uid JWT claims.

-- Helper: current user's internal UUID from firebase_uid claim
CREATE OR REPLACE FUNCTION public.current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT id FROM users
  WHERE firebase_uid = coalesce(
    auth.jwt() ->> 'sub',
    auth.jwt() ->> 'firebase_uid',
    auth.uid()::text
  )
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT role FROM users WHERE id = public.current_user_id();
$$;

CREATE OR REPLACE FUNCTION public.is_hospital_user()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT account_type = 'hospital' FROM users WHERE id = public.current_user_id();
$$;

-- ─── users ────────────────────────────────────────────────────────────────────
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_own ON public.users;
CREATE POLICY users_select_own ON public.users
  FOR SELECT USING (
    firebase_uid = coalesce(auth.jwt() ->> 'sub', auth.uid()::text)
    OR (public.is_hospital_user() AND account_type = 'hospital' AND hospital_verified = TRUE)
    OR (public.current_user_role() = 'donor' AND role = 'donor' AND account_type = 'regular')
  );

DROP POLICY IF EXISTS users_insert_own ON public.users;
CREATE POLICY users_insert_own ON public.users
  FOR INSERT WITH CHECK (
    firebase_uid = coalesce(auth.jwt() ->> 'sub', auth.uid()::text)
  );

DROP POLICY IF EXISTS users_update_own ON public.users;
CREATE POLICY users_update_own ON public.users
  FOR UPDATE USING (
    firebase_uid = coalesce(auth.jwt() ->> 'sub', auth.uid()::text)
  );

-- Leaderboard: donors may read donor stats (no PII beyond public leaderboard fields)
DROP POLICY IF EXISTS users_select_leaderboard ON public.users;
CREATE POLICY users_select_leaderboard ON public.users
  FOR SELECT USING (
    role = 'donor' AND total_donations > 0
    AND public.current_user_role() = 'donor'
  );

-- ─── blood_requests ───────────────────────────────────────────────────────────
ALTER TABLE public.blood_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS blood_requests_recipient ON public.blood_requests;
CREATE POLICY blood_requests_recipient ON public.blood_requests
  FOR ALL USING (requester_id = public.current_user_id())
  WITH CHECK (requester_id = public.current_user_id());

DROP POLICY IF EXISTS blood_requests_hospital ON public.blood_requests;
CREATE POLICY blood_requests_hospital ON public.blood_requests
  FOR ALL USING (hospital_id = public.current_user_id())
  WITH CHECK (hospital_id = public.current_user_id());

DROP POLICY IF EXISTS blood_requests_donor_read ON public.blood_requests;
CREATE POLICY blood_requests_donor_read ON public.blood_requests
  FOR SELECT USING (
    status = 'active'
    AND expires_at > now()
    AND public.current_user_role() = 'donor'
  );

-- ─── donor_responses ──────────────────────────────────────────────────────────
ALTER TABLE public.donor_responses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS donor_responses_own ON public.donor_responses;
CREATE POLICY donor_responses_own ON public.donor_responses
  FOR ALL USING (donor_id = public.current_user_id())
  WITH CHECK (donor_id = public.current_user_id());

DROP POLICY IF EXISTS donor_responses_hospital_read ON public.donor_responses;
CREATE POLICY donor_responses_hospital_read ON public.donor_responses
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM blood_requests br
      WHERE br.id = donor_responses.request_id
        AND br.hospital_id = public.current_user_id()
    )
  );

-- ─── donations ─────────────────────────────────────────────────────────────────
ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS donations_donor_read ON public.donations;
CREATE POLICY donations_donor_read ON public.donations
  FOR SELECT USING (donor_id = public.current_user_id());

DROP POLICY IF EXISTS donations_hospital_read ON public.donations;
CREATE POLICY donations_hospital_read ON public.donations
  FOR SELECT USING (verified_by_hospital_id = public.current_user_id());

-- ─── request_audit_log ────────────────────────────────────────────────────────
ALTER TABLE public.request_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_recipient ON public.request_audit_log;
CREATE POLICY audit_recipient ON public.request_audit_log
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM blood_requests br
      WHERE br.id = request_audit_log.request_id
        AND br.requester_id = public.current_user_id()
    )
  );

DROP POLICY IF EXISTS audit_hospital ON public.request_audit_log;
CREATE POLICY audit_hospital ON public.request_audit_log
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM blood_requests br
      WHERE br.id = request_audit_log.request_id
        AND br.hospital_id = public.current_user_id()
    )
  );

DROP POLICY IF EXISTS audit_insert_authenticated ON public.request_audit_log;
CREATE POLICY audit_insert_authenticated ON public.request_audit_log
  FOR INSERT WITH CHECK (public.current_user_id() IS NOT NULL);

-- ─── hospital_inventory ───────────────────────────────────────────────────────
ALTER TABLE public.hospital_inventory ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_hospital ON public.hospital_inventory;
CREATE POLICY inventory_hospital ON public.hospital_inventory
  FOR SELECT USING (hospital_id = public.current_user_id());

-- ─── inventory_delivery_log ───────────────────────────────────────────────────
ALTER TABLE public.inventory_delivery_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS inventory_log_hospital ON public.inventory_delivery_log;
CREATE POLICY inventory_log_hospital ON public.inventory_delivery_log
  FOR SELECT USING (hospital_id = public.current_user_id());

-- ─── badges (read-only for authenticated users) ───────────────────────────────
ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS badges_read ON public.badges;
CREATE POLICY badges_read ON public.badges FOR SELECT USING (auth.role() = 'authenticated');

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS user_badges_own ON public.user_badges;
CREATE POLICY user_badges_own ON public.user_badges
  FOR SELECT USING (user_id = public.current_user_id());

-- Service role (API BFF) bypasses RLS. Revoke direct anon/authenticated table grants if using PostgREST only.
