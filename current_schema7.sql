--
-- PostgreSQL database dump
--

\restrict OTzgAqRRJ8Kth7IahdLQSiAX3u3abqbR8IIazBjnlIOWrXiDb8ikjjQ8ysixuo3

-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.7 (Homebrew)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: add_hospital_inventory_units(uuid, character varying, integer, text, date, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.add_hospital_inventory_units(p_hospital_id uuid, p_blood_type character varying, p_units integer, p_reason text DEFAULT NULL::text, p_expiration_date date DEFAULT NULL::date, p_changed_by uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, error_message text, units_available integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_units_before INTEGER;
    v_units_after INTEGER;
    v_actor UUID;
BEGIN
    IF p_units <= 0 THEN
        RETURN QUERY SELECT FALSE, 'units_must_be_positive'::TEXT, 0;
        RETURN;
    END IF;
    v_actor := COALESCE(p_changed_by, p_hospital_id);
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_hospital_id AND account_type = 'hospital') THEN
        RETURN QUERY SELECT FALSE, 'not_a_hospital_account'::TEXT, 0;
        RETURN;
    END IF;
    SELECT COALESCE(hi.units_available, 0) INTO v_units_before
    FROM hospital_inventory hi WHERE hi.hospital_id = p_hospital_id AND hi.blood_type = p_blood_type;
    INSERT INTO hospital_inventory (hospital_id, blood_type, units_available, expiration_date, last_updated, updated_by)
    VALUES (p_hospital_id, p_blood_type, p_units, p_expiration_date, NOW(), v_actor)
    ON CONFLICT (hospital_id, blood_type)
    DO UPDATE SET
        units_available = hospital_inventory.units_available + p_units,
        expiration_date = COALESCE(p_expiration_date, hospital_inventory.expiration_date),
        last_updated = NOW(),
        updated_by = v_actor
    RETURNING units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'added', v_units_before, v_units_after, p_units, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$;


--
-- Name: check_and_alert_low_inventory(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_and_alert_low_inventory() RETURNS TABLE(hospital_id uuid, hospital_name text, blood_type character varying, units_available integer, minimum_threshold integer, action_taken text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_hospital RECORD;
    v_inv RECORD;
    v_existing_alert INTEGER;
    v_request_id UUID;
    v_short_id TEXT;
    v_donor_count INTEGER;
BEGIN
    FOR v_hospital IN SELECT id, users.hospital_name, hospital_code FROM users WHERE account_type = 'hospital' AND is_active = TRUE LOOP
        FOR v_inv IN SELECT hospital_inventory.blood_type, units_available, minimum_threshold
                     FROM hospital_inventory
                     WHERE hospital_id = v_hospital.id AND units_available < minimum_threshold AND units_available >= 0
        LOOP
            SELECT COUNT(*) INTO v_existing_alert
            FROM low_inventory_alerts
            WHERE hospital_id = v_hospital.id
              AND blood_type = v_inv.blood_type
              AND alert_status IN ('pending', 'notified')
              AND created_at > NOW() - INTERVAL '24 hours';
            CONTINUE WHEN v_existing_alert > 0;

            SELECT generate_short_request_id(v_hospital.hospital_code) INTO v_short_id;

            INSERT INTO blood_requests (
                short_id, requester_id, blood_type, units_needed, urgency_level,
                hospital_id, hospital_name, hospital_location,
                status, is_auto_request, auto_request_source_hospital_id,
                nearby_donors_count, expires_at, description
            ) VALUES (
                v_short_id, v_hospital.id, v_inv.blood_type,
                GREATEST(v_inv.minimum_threshold - v_inv.units_available + 2, 2),
                'urgent', v_hospital.id, v_hospital.hospital_name,
                (SELECT location FROM users WHERE id = v_hospital.id),
                'active', TRUE, v_hospital.id,
                0, NOW() + INTERVAL '24 hours',
                format('Auto-generated: Low %s inventory (%s units, threshold %s)',
                  v_inv.blood_type, v_inv.units_available, v_inv.minimum_threshold)
            ) RETURNING id INTO v_request_id;

            INSERT INTO low_inventory_alerts (hospital_id, blood_type, request_id, units_available_at_alert, threshold_at_alert, alert_status)
            VALUES (v_hospital.id, v_inv.blood_type, v_request_id, v_inv.units_available, v_inv.minimum_threshold, 'pending');

            SELECT COUNT(*)::int INTO v_donor_count
            FROM find_nearby_donors(v_inv.blood_type, (SELECT location FROM users WHERE id = v_hospital.id), 120, 200);

            UPDATE blood_requests SET nearby_donors_count = v_donor_count WHERE id = v_request_id;

            hospital_id := v_hospital.id;
            hospital_name := v_hospital.hospital_name;
            blood_type := v_inv.blood_type;
            units_available := v_inv.units_available;
            minimum_threshold := v_inv.minimum_threshold;
            action_taken := format('auto_request_created id=%s donors=%s', v_request_id, v_donor_count);
            RETURN NEXT;
        END LOOP;
    END LOOP;
END;
$$;


--
-- Name: create_appointment_slots(uuid, date, date, time without time zone, time without time zone, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_appointment_slots(p_hospital_id uuid, p_start_date date, p_end_date date, p_start_time time without time zone, p_end_time time without time zone, p_interval_mins integer DEFAULT 30) RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_count INT := 0;
    v_current_date DATE;
    v_current_time TIME;
BEGIN
    v_current_date := p_start_date;
    WHILE v_current_date <= p_end_date LOOP
        v_current_time := p_start_time;
        WHILE v_current_time < p_end_time LOOP
            INSERT INTO appointment_slots (hospital_id, slot_date, slot_time)
            VALUES (p_hospital_id, v_current_date, v_current_time)
            ON CONFLICT (hospital_id, slot_date, slot_time) DO NOTHING;
            v_count := v_count + 1;
            v_current_time := v_current_time + (p_interval_mins || ' minutes')::INTERVAL;
        END LOOP;
        v_current_date := v_current_date + 1;
    END LOOP;
    RETURN v_count;
END;
$$;


--
-- Name: current_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_id() RETURNS uuid
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT id FROM users
  WHERE firebase_uid = coalesce(
    auth.jwt() ->> 'sub',
    auth.jwt() ->> 'firebase_uid',
    auth.uid()::text
  )
  LIMIT 1;
$$;


--
-- Name: current_user_role(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.current_user_role() RETURNS text
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT role FROM users WHERE id = public.current_user_id();
$$;


--
-- Name: find_nearby_donors(character varying, extensions.geography, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.find_nearby_donors(p_blood_type character varying, p_location extensions.geography, p_max_distance_km integer DEFAULT 50, p_limit integer DEFAULT 100) RETURNS TABLE(user_id uuid, name text, blood_type character varying, phone text, distance_km numeric, days_since_last_donation integer, total_donations integer, reward_points integer, currently_requesting boolean, user_role text)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id, u.name, u.blood_type, u.phone,
        ROUND((ST_Distance(u.location, p_location) / 1000)::numeric, 2),
        COALESCE(CURRENT_DATE - u.last_donation_date, 999),
        u.total_donations, u.reward_points,
        u.is_recipient, u.role
    FROM users u
    WHERE u.account_type = 'regular'
        AND u.role = 'donor'
        AND u.donor_status = 'available'
        AND u.blood_type = p_blood_type
        AND u.is_active = TRUE
        AND u.notification_enabled = TRUE
        AND u.location IS NOT NULL
        AND ST_DWithin(u.location, p_location, p_max_distance_km * 1000)
        AND (u.last_donation_date IS NULL
             OR CURRENT_DATE - u.last_donation_date >= 56)
    ORDER BY u.is_recipient ASC, ST_Distance(u.location, p_location) ASC
    LIMIT p_limit;
END;
$$;


--
-- Name: generate_short_request_id(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.generate_short_request_id(hospital_code text) RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_date_part TEXT;
    v_random_part TEXT;
    v_short_id TEXT;  
    v_collision_check INTEGER;
BEGIN
    v_date_part := TO_CHAR(CURRENT_DATE, 'YYYYMMDD');
    
    LOOP
        v_random_part := LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0');
        v_short_id := hospital_code || '-' || v_date_part || '-' || v_random_part;
        
        SELECT COUNT(*) INTO v_collision_check
        FROM blood_requests
        WHERE short_id = v_short_id;
        
        EXIT WHEN v_collision_check = 0;
    END LOOP;
    
    RETURN v_short_id;
END;
$$;


--
-- Name: get_hospital_feedback_analytics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_hospital_feedback_analytics(p_hospital_id uuid) RETURNS TABLE(total_feedbacks bigint, avg_overall numeric, avg_efficiency numeric, avg_professionalism numeric, avg_cleanliness numeric, avg_waiting_time numeric, rating_1_count bigint, rating_2_count bigint, rating_3_count bigint, rating_4_count bigint, rating_5_count bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT,
        ROUND(AVG(df.overall_rating)::numeric, 2),
        ROUND(AVG(df.hospital_efficiency_rating)::numeric, 2),
        ROUND(AVG(df.staff_professionalism_rating)::numeric, 2),
        ROUND(AVG(df.cleanliness_rating)::numeric, 2),
        ROUND(AVG(df.waiting_time_rating)::numeric, 2),
        COUNT(*) FILTER (WHERE df.overall_rating = 1)::BIGINT,
        COUNT(*) FILTER (WHERE df.overall_rating = 2)::BIGINT,
        COUNT(*) FILTER (WHERE df.overall_rating = 3)::BIGINT,
        COUNT(*) FILTER (WHERE df.overall_rating = 4)::BIGINT,
        COUNT(*) FILTER (WHERE df.overall_rating = 5)::BIGINT
    FROM donor_feedback df
    WHERE df.target_id = p_hospital_id AND df.feedback_type = 'hospital_request';
END;
$$;


--
-- Name: get_recipient_feedback_analytics(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_recipient_feedback_analytics(p_recipient_id uuid) RETURNS TABLE(total_feedbacks bigint, avg_overall numeric, avg_communication numeric, avg_organization numeric)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT,
        ROUND(AVG(df.overall_rating)::numeric, 2),
        ROUND(AVG(df.communication_rating)::numeric, 2),
        ROUND(AVG(df.organization_rating)::numeric, 2)
    FROM donor_feedback df
    WHERE df.target_id = p_recipient_id AND df.feedback_type = 'recipient_request';
END;
$$;


--
-- Name: increment_hospital_inventory(uuid, character varying, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.increment_hospital_inventory(p_hospital_id uuid, p_blood_type character varying, p_units integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    INSERT INTO hospital_inventory (hospital_id, blood_type, units_available)
    VALUES (p_hospital_id, p_blood_type, p_units)
    ON CONFLICT (hospital_id, blood_type)
    DO UPDATE SET
        units_available = hospital_inventory.units_available + p_units,
        last_updated = NOW();
END;
$$;


--
-- Name: is_hospital_email(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_hospital_email(p_email text) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    email_domain TEXT;
    domain_count INTEGER;
BEGIN
    -- Extract domain from email
    email_domain := SPLIT_PART(p_email, '@', 2);
    
    -- Check if domain exists in whitelist
    SELECT COUNT(*) INTO domain_count
    FROM hospital_domains
    WHERE domain = email_domain AND active = TRUE;
    
    RETURN domain_count > 0;
END;
$$;


--
-- Name: is_hospital_user(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_hospital_user() RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT account_type = 'hospital' FROM users WHERE id = public.current_user_id();
$$;


--
-- Name: mark_alert_notified(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_alert_notified(p_request_id uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE low_inventory_alerts SET alert_status = 'notified',
        notified_donors_count = (SELECT COUNT(*) FROM donor_responses WHERE request_id = p_request_id)
    WHERE request_id = p_request_id AND alert_status = 'pending';
END;
$$;


--
-- Name: redeem_coupon(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.redeem_coupon(p_user_id uuid, p_coupon_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: remove_hospital_inventory_units(uuid, character varying, integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.remove_hospital_inventory_units(p_hospital_id uuid, p_blood_type character varying, p_units integer, p_reason text DEFAULT NULL::text, p_changed_by uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, error_message text, units_available integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_units_before INTEGER;
    v_units_after INTEGER;
    v_actor UUID;
BEGIN
    IF p_units <= 0 THEN
        RETURN QUERY SELECT FALSE, 'units_must_be_positive'::TEXT, 0;
        RETURN;
    END IF;
    v_actor := COALESCE(p_changed_by, p_hospital_id);
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_hospital_id AND account_type = 'hospital') THEN
        RETURN QUERY SELECT FALSE, 'not_a_hospital_account'::TEXT, 0;
        RETURN;
    END IF;
    SELECT hi.units_available INTO v_units_before
    FROM hospital_inventory hi WHERE hi.hospital_id = p_hospital_id AND hi.blood_type = p_blood_type;
    IF v_units_before IS NULL OR v_units_before < p_units THEN
        RETURN QUERY SELECT FALSE, 'insufficient_units'::TEXT, COALESCE(v_units_before, 0);
        RETURN;
    END IF;
    UPDATE hospital_inventory SET
        units_available = units_available - p_units,
        last_updated = NOW(),
        updated_by = v_actor
    WHERE hospital_id = p_hospital_id AND blood_type = p_blood_type
    RETURNING units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'removed', v_units_before, v_units_after, -p_units, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$;


--
-- Name: resolve_low_inventory_alerts(uuid, character varying); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_low_inventory_alerts(p_hospital_id uuid, p_blood_type character varying) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
    UPDATE low_inventory_alerts SET alert_status = 'resolved', resolved_at = NOW()
    WHERE hospital_id = p_hospital_id AND blood_type = p_blood_type AND alert_status IN ('pending', 'notified');
END;
$$;


--
-- Name: set_hospital_inventory_threshold(uuid, character varying, integer, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_hospital_inventory_threshold(p_hospital_id uuid, p_blood_type character varying, p_threshold integer, p_changed_by uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, error_message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_threshold_before INTEGER;
    v_actor UUID;
BEGIN
    IF p_threshold < 0 THEN
        RETURN QUERY SELECT FALSE, 'threshold_cannot_be_negative'::TEXT;
        RETURN;
    END IF;
    v_actor := COALESCE(p_changed_by, p_hospital_id);
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_hospital_id AND account_type = 'hospital') THEN
        RETURN QUERY SELECT FALSE, 'not_a_hospital_account'::TEXT;
        RETURN;
    END IF;
    SELECT hi.minimum_threshold INTO v_threshold_before
    FROM hospital_inventory hi WHERE hi.hospital_id = p_hospital_id AND hi.blood_type = p_blood_type;
    INSERT INTO hospital_inventory (hospital_id, blood_type, units_available, minimum_threshold, last_updated, updated_by)
    VALUES (p_hospital_id, p_blood_type, 0, p_threshold, NOW(), v_actor)
    ON CONFLICT (hospital_id, blood_type)
    DO UPDATE SET
        minimum_threshold = p_threshold,
        last_updated = NOW(),
        updated_by = v_actor;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, threshold_before, threshold_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'threshold_changed', v_threshold_before, p_threshold, 0, 'Threshold updated', v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT;
END;
$$;


--
-- Name: set_hospital_inventory_units(uuid, character varying, integer, text, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.set_hospital_inventory_units(p_hospital_id uuid, p_blood_type character varying, p_units integer, p_reason text DEFAULT NULL::text, p_changed_by uuid DEFAULT NULL::uuid) RETURNS TABLE(success boolean, error_message text, units_available integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_units_before INTEGER;
    v_units_after INTEGER;
    v_actor UUID;
BEGIN
    IF p_units < 0 THEN
        RETURN QUERY SELECT FALSE, 'units_cannot_be_negative'::TEXT, 0;
        RETURN;
    END IF;
    v_actor := COALESCE(p_changed_by, p_hospital_id);
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_hospital_id AND account_type = 'hospital') THEN
        RETURN QUERY SELECT FALSE, 'not_a_hospital_account'::TEXT, 0;
        RETURN;
    END IF;
    SELECT COALESCE(hi.units_available, 0) INTO v_units_before
    FROM hospital_inventory hi WHERE hi.hospital_id = p_hospital_id AND hi.blood_type = p_blood_type;
    INSERT INTO hospital_inventory (hospital_id, blood_type, units_available, last_updated, updated_by)
    VALUES (p_hospital_id, p_blood_type, p_units, NOW(), v_actor)
    ON CONFLICT (hospital_id, blood_type)
    DO UPDATE SET
        units_available = p_units,
        last_updated = NOW(),
        updated_by = v_actor
    RETURNING units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'adjusted', v_units_before, v_units_after, p_units - v_units_before, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$;


--
-- Name: toggle_story_like(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.toggle_story_like(p_story_id uuid, p_user_id uuid) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
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


--
-- Name: touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;


--
-- Name: update_donor_status(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_donor_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.account_type = 'regular' AND NEW.role = 'donor' THEN
        IF NEW.last_donation_date IS NOT NULL THEN
            IF CURRENT_DATE - NEW.last_donation_date < 56 THEN
                NEW.donor_status := 'on_cooldown';
            ELSE
                NEW.donor_status := 'available';
            END IF;
        ELSE
            NEW.donor_status := 'available';
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


--
-- Name: verify_request_donation(uuid, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.verify_request_donation(p_request_id uuid, p_hospital_user_id uuid, p_staff_name text DEFAULT NULL::text) RETURNS TABLE(success boolean, error_message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_status TEXT;
    v_hospital UUID;
    v_requester UUID;
    v_donor UUID;
    v_blood VARCHAR(3);
    v_units INT;
    v_points INT;
BEGIN
    SELECT br.status, br.hospital_id, br.requester_id, br.blood_type, br.units_needed
    INTO v_status, v_hospital, v_requester, v_blood, v_units
    FROM blood_requests br
    WHERE br.id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Request not found'::TEXT;
        RETURN;
    END IF;

    IF v_hospital IS DISTINCT FROM p_hospital_user_id THEN
        RETURN QUERY SELECT FALSE, 'This request belongs to another hospital'::TEXT;
        RETURN;
    END IF;

    IF v_status <> 'in_progress' THEN
        RETURN QUERY SELECT FALSE,
            format('Request cannot be verified while status is %s', v_status)::TEXT;
        RETURN;
    END IF;

    SELECT dr.donor_id INTO v_donor
    FROM donor_responses dr
    WHERE dr.request_id = p_request_id AND dr.response_type = 'accepted'
    LIMIT 1;

    IF v_donor IS NULL THEN
        RETURN QUERY SELECT FALSE, 'No donor has accepted this request yet'::TEXT;
        RETURN;
    END IF;

    -- Urgency-based points
    SELECT CASE urgency_level
        WHEN 'critical' THEN 30
        WHEN 'urgent'   THEN 20
        ELSE 10
    END INTO v_points
    FROM blood_requests WHERE id = p_request_id;

    UPDATE blood_requests SET
        status = 'fulfilled',
        fulfilled_at = NOW(),
        units_fulfilled = v_units,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id;

    INSERT INTO donations (
        request_id, donor_id, verified_by_hospital_id,
        verified_by_hospital_staff, units_donated, donation_type
    ) VALUES (
        p_request_id, v_donor, p_hospital_user_id,
        p_staff_name, 1, 'whole_blood'
    );

    INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
    VALUES (
        p_request_id, 'verified_closed',
        'Hospital verified donation; 1 unit logged.',
        p_hospital_user_id
    );

    INSERT INTO inventory_delivery_log (hospital_id, blood_type, units, request_id, note)
    VALUES (p_hospital_user_id, v_blood, 1, p_request_id, '1 unit delivered');

    PERFORM increment_hospital_inventory(p_hospital_user_id, v_blood, 1);

    UPDATE users SET
        is_recipient = FALSE,
        updated_at = NOW()
    WHERE id = v_requester;

    UPDATE users SET
        total_donations = COALESCE(total_donations, 0) + 1,
        last_donation_date = CURRENT_DATE,
        reward_points = COALESCE(reward_points, 0) + v_points,
        updated_at = NOW()
    WHERE id = v_donor;

    -- Award milestone badges
    INSERT INTO user_badges (user_id, badge_id, earned_at)
    SELECT v_donor, b.id, NOW()
    FROM badges b
    WHERE b.requirement_type = 'donation_count'
      AND b.requirement_value <= (
          SELECT total_donations FROM users WHERE id = v_donor
      )
      AND NOT EXISTS (
          SELECT 1 FROM user_badges ub2
          WHERE ub2.user_id = v_donor AND ub2.badge_id = b.id
      );

    RETURN QUERY SELECT TRUE, NULL::TEXT;
END;
$$;


--
-- Name: active_requests_summary; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.active_requests_summary AS
SELECT
    NULL::uuid AS id,
    NULL::character varying(30) AS short_id,
    NULL::character varying(3) AS blood_type,
    NULL::text AS urgency_level,
    NULL::text AS hospital_name,
    NULL::integer AS units_needed,
    NULL::integer AS units_fulfilled,
    NULL::timestamp without time zone AS created_at,
    NULL::timestamp without time zone AS expires_at,
    NULL::bigint AS accepted_donors,
    NULL::bigint AS interested_donors;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    badge_code character varying(50) NOT NULL,
    badge_name text NOT NULL,
    description text,
    icon_url text,
    requirement_type text,
    requirement_value integer,
    points_value integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT badges_requirement_type_check CHECK ((requirement_type = ANY (ARRAY['donation_count'::text, 'consecutive_months'::text, 'critical_response'::text, 'rare_blood'::text])))
);


--
-- Name: blood_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.blood_requests (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    short_id character varying(30) NOT NULL,
    requester_id uuid NOT NULL,
    blood_type character varying(3) NOT NULL,
    units_needed integer NOT NULL,
    units_fulfilled integer DEFAULT 0,
    urgency_level text NOT NULL,
    hospital_name text NOT NULL,
    hospital_id uuid,
    hospital_location extensions.geography(Point,4326) NOT NULL,
    requester_location extensions.geography(Point,4326),
    description text,
    patient_name text,
    contact_phone text,
    status text DEFAULT 'active'::text NOT NULL,
    nearby_donors_count integer DEFAULT 0,
    total_eligible_count integer DEFAULT 0,
    notified_donors_count integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    expires_at timestamp without time zone NOT NULL,
    fulfilled_at timestamp without time zone,
    version integer DEFAULT 1,
    is_auto_request boolean DEFAULT false,
    auto_request_source_hospital_id uuid,
    CONSTRAINT blood_requests_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT blood_requests_status_check CHECK ((status = ANY (ARRAY['active'::text, 'in_progress'::text, 'fulfilled'::text, 'cancelled'::text, 'expired'::text]))),
    CONSTRAINT blood_requests_units_fulfilled_check CHECK ((units_fulfilled >= 0)),
    CONSTRAINT blood_requests_units_needed_check CHECK ((units_needed > 0)),
    CONSTRAINT blood_requests_urgency_level_check CHECK ((urgency_level = ANY (ARRAY['routine'::text, 'urgent'::text, 'critical'::text])))
);


--
-- Name: coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    code_prefix text DEFAULT 'BC'::text NOT NULL,
    title text NOT NULL,
    description text NOT NULL,
    partner_name text NOT NULL,
    partner_logo_url text,
    discount_pct integer NOT NULL,
    points_cost integer DEFAULT 500 NOT NULL,
    total_available integer DEFAULT 1000 NOT NULL,
    total_redeemed integer DEFAULT 0 NOT NULL,
    valid_until timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT coupons_discount_pct_check CHECK (((discount_pct >= 1) AND (discount_pct <= 100)))
);


--
-- Name: donations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    donor_id uuid,
    verified_by_hospital_id uuid NOT NULL,
    verified_by_hospital_staff text,
    units_donated integer NOT NULL,
    donation_type text,
    points_awarded integer DEFAULT 10,
    badge_earned text,
    donation_date timestamp without time zone DEFAULT now(),
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT donations_donation_type_check CHECK ((donation_type = ANY (ARRAY['whole_blood'::text, 'platelets'::text, 'plasma'::text]))),
    CONSTRAINT donations_units_donated_check CHECK ((units_donated > 0))
);


--
-- Name: donor_feedback; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donor_feedback (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    donation_id uuid NOT NULL,
    donor_id uuid NOT NULL,
    feedback_type text NOT NULL,
    target_id uuid NOT NULL,
    overall_rating integer,
    communication_rating integer,
    organization_rating integer,
    hospital_efficiency_rating integer,
    staff_professionalism_rating integer,
    cleanliness_rating integer,
    waiting_time_rating integer,
    comment text,
    is_anonymous boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT donor_feedback_cleanliness_rating_check CHECK (((cleanliness_rating >= 1) AND (cleanliness_rating <= 5))),
    CONSTRAINT donor_feedback_communication_rating_check CHECK (((communication_rating >= 1) AND (communication_rating <= 5))),
    CONSTRAINT donor_feedback_feedback_type_check CHECK ((feedback_type = ANY (ARRAY['recipient_request'::text, 'hospital_request'::text]))),
    CONSTRAINT donor_feedback_hospital_efficiency_rating_check CHECK (((hospital_efficiency_rating >= 1) AND (hospital_efficiency_rating <= 5))),
    CONSTRAINT donor_feedback_organization_rating_check CHECK (((organization_rating >= 1) AND (organization_rating <= 5))),
    CONSTRAINT donor_feedback_overall_rating_check CHECK (((overall_rating >= 1) AND (overall_rating <= 5))),
    CONSTRAINT donor_feedback_staff_professionalism_rating_check CHECK (((staff_professionalism_rating >= 1) AND (staff_professionalism_rating <= 5))),
    CONSTRAINT donor_feedback_waiting_time_rating_check CHECK (((waiting_time_rating >= 1) AND (waiting_time_rating <= 5)))
);


--
-- Name: donor_leaderboard; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.donor_leaderboard AS
SELECT
    NULL::uuid AS id,
    NULL::text AS name,
    NULL::character varying(3) AS blood_type,
    NULL::integer AS total_donations,
    NULL::integer AS reward_points,
    NULL::text AS donor_status,
    NULL::bigint AS badges_earned,
    NULL::bigint AS rank;


--
-- Name: donor_responses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donor_responses (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    donor_id uuid,
    response_type text NOT NULL,
    distance_km numeric(6,2),
    estimated_arrival timestamp without time zone,
    responded_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    ai_eligibility_score numeric(4,3),
    ai_eligibility_passed boolean,
    ai_checked_at timestamp with time zone,
    CONSTRAINT donor_responses_response_type_check CHECK ((response_type = ANY (ARRAY['accepted'::text, 'declined'::text, 'interested'::text, 'en_route'::text, 'arrived'::text])))
);


--
-- Name: hospital_domains; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hospital_domains (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    domain text NOT NULL,
    hospital_name text,
    contact_email text,
    verified_at timestamp without time zone DEFAULT now(),
    verified_by uuid,
    active boolean DEFAULT true,
    active_status boolean DEFAULT true,
    active_reason text
);


--
-- Name: hospital_inventory; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hospital_inventory (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    hospital_id uuid NOT NULL,
    blood_type character varying(3) NOT NULL,
    units_available integer DEFAULT 0,
    units_reserved integer DEFAULT 0,
    minimum_threshold integer DEFAULT 5,
    last_updated timestamp without time zone DEFAULT now(),
    updated_by uuid,
    expiration_date date,
    CONSTRAINT hospital_inventory_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT hospital_inventory_units_available_check CHECK ((units_available >= 0)),
    CONSTRAINT hospital_inventory_units_reserved_check CHECK ((units_reserved >= 0))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    firebase_uid text NOT NULL,
    email text NOT NULL,
    name text NOT NULL,
    phone text,
    blood_type character varying(3),
    location extensions.geography(Point,4326),
    account_type text DEFAULT 'regular'::text NOT NULL,
    is_recipient boolean DEFAULT false,
    last_donation_date date,
    total_donations integer DEFAULT 0,
    reward_points integer DEFAULT 0,
    donor_status text DEFAULT 'available'::text,
    hospital_name text,
    hospital_code character varying(10),
    hospital_verified boolean DEFAULT false,
    hospital_approval_date timestamp without time zone,
    approved_by uuid,
    notification_enabled boolean DEFAULT true,
    notification_radius_km integer DEFAULT 25,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    is_active boolean DEFAULT true,
    fcm_token text,
    city_area text,
    role text DEFAULT 'donor'::text NOT NULL,
    date_of_birth date,
    CONSTRAINT hospital_fields_required CHECK ((((account_type = 'hospital'::text) AND (hospital_name IS NOT NULL) AND (hospital_code IS NOT NULL)) OR (account_type = 'regular'::text))),
    CONSTRAINT users_account_type_check CHECK ((account_type = ANY (ARRAY['regular'::text, 'hospital'::text]))),
    CONSTRAINT users_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT users_donor_status_check CHECK ((donor_status = ANY (ARRAY['available'::text, 'unavailable'::text, 'on_cooldown'::text]))),
    CONSTRAINT users_min_age_check CHECK (((account_type = 'hospital'::text) OR (date_of_birth IS NULL) OR (age((date_of_birth)::timestamp with time zone) >= '18 years'::interval))),
    CONSTRAINT users_role_check CHECK ((role = ANY (ARRAY['donor'::text, 'recipient'::text, 'hospital'::text])))
);


--
-- Name: hospital_inventory_status; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.hospital_inventory_status AS
 SELECT u.name AS hospital_name,
    hi.blood_type,
    hi.units_available,
    hi.minimum_threshold,
        CASE
            WHEN (hi.units_available < hi.minimum_threshold) THEN 'LOW'::text
            WHEN (hi.units_available < (hi.minimum_threshold * 2)) THEN 'MEDIUM'::text
            ELSE 'ADEQUATE'::text
        END AS stock_status,
    hi.last_updated
   FROM (public.hospital_inventory hi
     JOIN public.users u ON ((hi.hospital_id = u.id)))
  WHERE (u.account_type = 'hospital'::text);


--
-- Name: inventory_change_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_change_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    hospital_id uuid NOT NULL,
    blood_type character varying(3) NOT NULL,
    change_type text NOT NULL,
    units_before integer DEFAULT 0 NOT NULL,
    units_after integer DEFAULT 0 NOT NULL,
    threshold_before integer,
    threshold_after integer,
    units_changed integer DEFAULT 0 NOT NULL,
    reason text,
    changed_by uuid NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT inventory_change_log_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT inventory_change_log_change_type_check CHECK ((change_type = ANY (ARRAY['added'::text, 'removed'::text, 'adjusted'::text, 'threshold_changed'::text, 'expiration_updated'::text])))
);


--
-- Name: inventory_delivery_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.inventory_delivery_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    hospital_id uuid NOT NULL,
    blood_type character varying(3) NOT NULL,
    units integer DEFAULT 1 NOT NULL,
    request_id uuid,
    note text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT inventory_delivery_log_units_check CHECK ((units > 0))
);


--
-- Name: inventory_history_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.inventory_history_view AS
 SELECT icl.id,
    u.name AS hospital_name,
    icl.blood_type,
    icl.change_type,
    icl.units_before,
    icl.units_after,
    icl.units_changed,
    icl.threshold_before,
    icl.threshold_after,
    icl.reason,
    changer.name AS changed_by_name,
    icl.created_at
   FROM ((public.inventory_change_log icl
     JOIN public.users u ON ((u.id = icl.hospital_id)))
     LEFT JOIN public.users changer ON ((changer.id = icl.changed_by)))
  ORDER BY icl.created_at DESC;


--
-- Name: low_inventory_alerts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.low_inventory_alerts (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    hospital_id uuid NOT NULL,
    blood_type character varying(3) NOT NULL,
    request_id uuid,
    units_available_at_alert integer NOT NULL,
    threshold_at_alert integer NOT NULL,
    alert_status text DEFAULT 'pending'::text NOT NULL,
    notified_donors_count integer DEFAULT 0,
    resolved_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT low_inventory_alerts_alert_status_check CHECK ((alert_status = ANY (ARRAY['pending'::text, 'notified'::text, 'resolved'::text, 'suppressed'::text]))),
    CONSTRAINT low_inventory_alerts_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[])))
);


--
-- Name: medical_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.medical_records (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    hemoglobin numeric(4,2),
    blood_pressure_systolic integer,
    blood_pressure_diastolic integer,
    weight_kg numeric(5,2),
    report_date date NOT NULL,
    report_image_url text,
    lab_name text,
    ai_confidence numeric(3,2),
    extraction_method text,
    eligibility_status text NOT NULL,
    ineligibility_reasons text[],
    verified_by_hospital boolean DEFAULT false,
    verified_by_hospital_id uuid,
    verification_notes text,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    expires_at timestamp without time zone,
    CONSTRAINT medical_records_ai_confidence_check CHECK (((ai_confidence >= (0)::numeric) AND (ai_confidence <= (1)::numeric))),
    CONSTRAINT medical_records_eligibility_status_check CHECK ((eligibility_status = ANY (ARRAY['eligible'::text, 'not_eligible'::text, 'manual_review_required'::text]))),
    CONSTRAINT medical_records_extraction_method_check CHECK ((extraction_method = ANY (ARRAY['ai_vit'::text, 'manual_entry'::text, 'hospital_verified'::text])))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    request_id uuid,
    notification_type text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    sent_at timestamp without time zone DEFAULT now(),
    delivered_at timestamp without time zone,
    read_at timestamp without time zone,
    clicked_at timestamp without time zone,
    fcm_token text,
    fcm_message_id text,
    delivery_status text,
    CONSTRAINT notifications_delivery_status_check CHECK ((delivery_status = ANY (ARRAY['sent'::text, 'delivered'::text, 'failed'::text, 'clicked'::text]))),
    CONSTRAINT notifications_notification_type_check CHECK ((notification_type = ANY (ARRAY['request_alert'::text, 'fulfillment_update'::text, 'reward_earned'::text, 'system_message'::text, 'story_like'::text, 'story_created'::text])))
);


--
-- Name: request_audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.request_audit_log (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    event_type text NOT NULL,
    detail text,
    actor_user_id uuid,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: story_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.story_likes (
    story_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);


--
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    earned_at timestamp without time zone DEFAULT now()
);


--
-- Name: user_coupons; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_coupons (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    coupon_id uuid NOT NULL,
    coupon_code text NOT NULL,
    redeemed_at timestamp with time zone DEFAULT now(),
    used_at timestamp with time zone,
    expires_at timestamp with time zone DEFAULT (now() + '90 days'::interval),
    points_spent integer NOT NULL
);


--
-- Name: user_stories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_stories (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    author_id uuid NOT NULL,
    role text NOT NULL,
    title text NOT NULL,
    body text NOT NULL,
    blood_type text,
    likes_count integer DEFAULT 0 NOT NULL,
    is_approved boolean DEFAULT false NOT NULL,
    is_featured boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT user_stories_body_check CHECK (((char_length(body) >= 50) AND (char_length(body) <= 2000))),
    CONSTRAINT user_stories_role_check CHECK ((role = ANY (ARRAY['donor'::text, 'recipient'::text]))),
    CONSTRAINT user_stories_title_check CHECK (((char_length(title) >= 5) AND (char_length(title) <= 120)))
);


--
-- Name: badges badges_badge_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_badge_code_key UNIQUE (badge_code);


--
-- Name: badges badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.badges
    ADD CONSTRAINT badges_pkey PRIMARY KEY (id);


--
-- Name: blood_requests blood_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blood_requests
    ADD CONSTRAINT blood_requests_pkey PRIMARY KEY (id);


--
-- Name: blood_requests blood_requests_short_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blood_requests
    ADD CONSTRAINT blood_requests_short_id_key UNIQUE (short_id);


--
-- Name: coupons coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.coupons
    ADD CONSTRAINT coupons_pkey PRIMARY KEY (id);


--
-- Name: donations donations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_pkey PRIMARY KEY (id);


--
-- Name: donor_feedback donor_feedback_donation_id_donor_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_feedback
    ADD CONSTRAINT donor_feedback_donation_id_donor_id_key UNIQUE (donation_id, donor_id);


--
-- Name: donor_feedback donor_feedback_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_feedback
    ADD CONSTRAINT donor_feedback_pkey PRIMARY KEY (id);


--
-- Name: donor_responses donor_responses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_responses
    ADD CONSTRAINT donor_responses_pkey PRIMARY KEY (id);


--
-- Name: donor_responses donor_responses_request_id_donor_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_responses
    ADD CONSTRAINT donor_responses_request_id_donor_id_key UNIQUE (request_id, donor_id);


--
-- Name: hospital_domains hospital_domains_domain_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_domains
    ADD CONSTRAINT hospital_domains_domain_key UNIQUE (domain);


--
-- Name: hospital_domains hospital_domains_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_domains
    ADD CONSTRAINT hospital_domains_pkey PRIMARY KEY (id);


--
-- Name: hospital_inventory hospital_inventory_hospital_id_blood_type_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_inventory
    ADD CONSTRAINT hospital_inventory_hospital_id_blood_type_key UNIQUE (hospital_id, blood_type);


--
-- Name: hospital_inventory hospital_inventory_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_inventory
    ADD CONSTRAINT hospital_inventory_pkey PRIMARY KEY (id);


--
-- Name: inventory_change_log inventory_change_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_change_log
    ADD CONSTRAINT inventory_change_log_pkey PRIMARY KEY (id);


--
-- Name: inventory_delivery_log inventory_delivery_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_delivery_log
    ADD CONSTRAINT inventory_delivery_log_pkey PRIMARY KEY (id);


--
-- Name: low_inventory_alerts low_inventory_alerts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.low_inventory_alerts
    ADD CONSTRAINT low_inventory_alerts_pkey PRIMARY KEY (id);


--
-- Name: medical_records medical_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: request_audit_log request_audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_audit_log
    ADD CONSTRAINT request_audit_log_pkey PRIMARY KEY (id);


--
-- Name: story_likes story_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_pkey PRIMARY KEY (story_id, user_id);


--
-- Name: user_badges user_badges_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_pkey PRIMARY KEY (id);


--
-- Name: user_badges user_badges_user_id_badge_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_badge_id_key UNIQUE (user_id, badge_id);


--
-- Name: user_coupons user_coupons_coupon_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_coupons
    ADD CONSTRAINT user_coupons_coupon_code_key UNIQUE (coupon_code);


--
-- Name: user_coupons user_coupons_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_coupons
    ADD CONSTRAINT user_coupons_pkey PRIMARY KEY (id);


--
-- Name: user_stories user_stories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stories
    ADD CONSTRAINT user_stories_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_firebase_uid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_firebase_uid_key UNIQUE (firebase_uid);


--
-- Name: users users_hospital_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_hospital_code_key UNIQUE (hospital_code);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: donor_responses_one_accepted_per_request; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX donor_responses_one_accepted_per_request ON public.donor_responses USING btree (request_id) WHERE (response_type = 'accepted'::text);


--
-- Name: idx_blood_requests_requester_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blood_requests_requester_id ON public.blood_requests USING btree (requester_id);


--
-- Name: idx_blood_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_blood_requests_status ON public.blood_requests USING btree (status) WHERE (status = ANY (ARRAY['active'::text, 'in_progress'::text]));


--
-- Name: idx_donations_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donations_date ON public.donations USING btree (donation_date DESC);


--
-- Name: idx_donations_donor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donations_donor_id ON public.donations USING btree (donor_id);


--
-- Name: idx_donations_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donations_request_id ON public.donations USING btree (request_id);


--
-- Name: idx_donations_verified_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donations_verified_by ON public.donations USING btree (verified_by_hospital_id);


--
-- Name: idx_donor_feedback_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_feedback_created ON public.donor_feedback USING btree (created_at DESC);


--
-- Name: idx_donor_feedback_donor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_feedback_donor ON public.donor_feedback USING btree (donor_id);


--
-- Name: idx_donor_feedback_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_feedback_target ON public.donor_feedback USING btree (target_id);


--
-- Name: idx_donor_feedback_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_feedback_type ON public.donor_feedback USING btree (feedback_type);


--
-- Name: idx_donor_responses_donor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_responses_donor_id ON public.donor_responses USING btree (donor_id);


--
-- Name: idx_donor_responses_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_responses_request_id ON public.donor_responses USING btree (request_id);


--
-- Name: idx_donor_responses_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_donor_responses_type ON public.donor_responses USING btree (response_type);


--
-- Name: idx_inventory_blood_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_blood_type ON public.hospital_inventory USING btree (blood_type);


--
-- Name: idx_inventory_change_log_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_change_log_created ON public.inventory_change_log USING btree (created_at DESC);


--
-- Name: idx_inventory_change_log_hospital; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_change_log_hospital ON public.inventory_change_log USING btree (hospital_id);


--
-- Name: idx_inventory_change_log_hospital_bt; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_change_log_hospital_bt ON public.inventory_change_log USING btree (hospital_id, blood_type);


--
-- Name: idx_inventory_delivery_hospital; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_delivery_hospital ON public.inventory_delivery_log USING btree (hospital_id);


--
-- Name: idx_inventory_hospital_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_hospital_id ON public.hospital_inventory USING btree (hospital_id);


--
-- Name: idx_inventory_low_stock; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_inventory_low_stock ON public.hospital_inventory USING btree (units_available) WHERE (units_available < minimum_threshold);


--
-- Name: idx_low_inventory_alerts_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_low_inventory_alerts_created ON public.low_inventory_alerts USING btree (created_at DESC);


--
-- Name: idx_low_inventory_alerts_unique_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_low_inventory_alerts_unique_active ON public.low_inventory_alerts USING btree (hospital_id, blood_type) WHERE (alert_status = ANY (ARRAY['pending'::text, 'notified'::text]));


--
-- Name: idx_medical_records_eligibility; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_medical_records_eligibility ON public.medical_records USING btree (eligibility_status);


--
-- Name: idx_medical_records_expires_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_medical_records_expires_at ON public.medical_records USING btree (expires_at);


--
-- Name: idx_medical_records_report_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_medical_records_report_date ON public.medical_records USING btree (report_date DESC);


--
-- Name: idx_medical_records_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_medical_records_user_id ON public.medical_records USING btree (user_id);


--
-- Name: idx_notifications_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_request_id ON public.notifications USING btree (request_id);


--
-- Name: idx_notifications_sent_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_sent_at ON public.notifications USING btree (sent_at DESC);


--
-- Name: idx_notifications_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_id ON public.notifications USING btree (user_id);


--
-- Name: idx_one_active_request_per_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_one_active_request_per_requester ON public.blood_requests USING btree (requester_id) WHERE (status = ANY (ARRAY['active'::text, 'in_progress'::text]));


--
-- Name: idx_request_audit_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_request_audit_request_id ON public.request_audit_log USING btree (request_id);


--
-- Name: idx_requests_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_active ON public.blood_requests USING btree (status) WHERE (status = 'active'::text);


--
-- Name: idx_requests_blood_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_blood_type ON public.blood_requests USING btree (blood_type);


--
-- Name: idx_requests_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_created_at ON public.blood_requests USING btree (created_at DESC);


--
-- Name: idx_requests_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_location ON public.blood_requests USING gist (hospital_location);


--
-- Name: idx_requests_requester_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_requester_id ON public.blood_requests USING btree (requester_id);


--
-- Name: idx_requests_requester_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_requester_location ON public.blood_requests USING gist (requester_location);


--
-- Name: idx_requests_short_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_short_id ON public.blood_requests USING btree (short_id);


--
-- Name: idx_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_status ON public.blood_requests USING btree (status);


--
-- Name: idx_requests_urgency; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_requests_urgency ON public.blood_requests USING btree (urgency_level);


--
-- Name: idx_stories_approved_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stories_approved_created ON public.user_stories USING btree (created_at DESC) WHERE (is_approved = true);


--
-- Name: idx_stories_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stories_author ON public.user_stories USING btree (author_id);


--
-- Name: idx_stories_featured; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stories_featured ON public.user_stories USING btree (created_at DESC) WHERE ((is_featured = true) AND (is_approved = true));


--
-- Name: idx_user_badges_earned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_badges_earned_at ON public.user_badges USING btree (earned_at DESC);


--
-- Name: idx_user_badges_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_badges_user_id ON public.user_badges USING btree (user_id);


--
-- Name: idx_user_coupons_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_coupons_code ON public.user_coupons USING btree (coupon_code);


--
-- Name: idx_user_coupons_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_coupons_user ON public.user_coupons USING btree (user_id, redeemed_at DESC);


--
-- Name: idx_users_account_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_account_type ON public.users USING btree (account_type);


--
-- Name: idx_users_blood_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_blood_type ON public.users USING btree (blood_type);


--
-- Name: idx_users_donor_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_donor_status ON public.users USING btree (donor_status) WHERE (donor_status = 'available'::text);


--
-- Name: idx_users_fcm_token; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_fcm_token ON public.users USING btree (fcm_token) WHERE (fcm_token IS NOT NULL);


--
-- Name: idx_users_firebase_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_firebase_uid ON public.users USING btree (firebase_uid);


--
-- Name: idx_users_hospital_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_hospital_code ON public.users USING btree (hospital_code) WHERE (hospital_code IS NOT NULL);


--
-- Name: idx_users_location; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_location ON public.users USING gist (location);


--
-- Name: active_requests_summary _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.active_requests_summary AS
 SELECT br.id,
    br.short_id,
    br.blood_type,
    br.urgency_level,
    br.hospital_name,
    br.units_needed,
    br.units_fulfilled,
    br.created_at,
    br.expires_at,
    count(DISTINCT dr.donor_id) FILTER (WHERE (dr.response_type = 'accepted'::text)) AS accepted_donors,
    count(DISTINCT dr.donor_id) FILTER (WHERE (dr.response_type = 'interested'::text)) AS interested_donors
   FROM (public.blood_requests br
     LEFT JOIN public.donor_responses dr ON ((br.id = dr.request_id)))
  WHERE (br.status = 'active'::text)
  GROUP BY br.id;


--
-- Name: donor_leaderboard _RETURN; Type: RULE; Schema: public; Owner: -
--

CREATE OR REPLACE VIEW public.donor_leaderboard AS
 SELECT u.id,
    u.name,
    u.blood_type,
    u.total_donations,
    u.reward_points,
    u.donor_status,
    count(ub.badge_id) AS badges_earned,
    rank() OVER (ORDER BY u.reward_points DESC) AS rank
   FROM (public.users u
     LEFT JOIN public.user_badges ub ON ((u.id = ub.user_id)))
  WHERE (u.role = 'donor'::text)
  GROUP BY u.id
  ORDER BY u.reward_points DESC;


--
-- Name: users auto_update_donor_status; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER auto_update_donor_status BEFORE INSERT OR UPDATE OF last_donation_date, role ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_donor_status();


--
-- Name: user_stories trg_stories_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_stories_updated_at BEFORE UPDATE ON public.user_stories FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();


--
-- Name: donor_feedback update_donor_feedback_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_donor_feedback_updated_at BEFORE UPDATE ON public.donor_feedback FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: medical_records update_medical_records_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_medical_records_updated_at BEFORE UPDATE ON public.medical_records FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: blood_requests update_requests_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_requests_updated_at BEFORE UPDATE ON public.blood_requests FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: blood_requests blood_requests_auto_request_source_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blood_requests
    ADD CONSTRAINT blood_requests_auto_request_source_hospital_id_fkey FOREIGN KEY (auto_request_source_hospital_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: blood_requests blood_requests_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blood_requests
    ADD CONSTRAINT blood_requests_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: blood_requests blood_requests_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.blood_requests
    ADD CONSTRAINT blood_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: donations donations_donor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_donor_id_fkey FOREIGN KEY (donor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: donations donations_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id);


--
-- Name: donations donations_verified_by_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_verified_by_hospital_id_fkey FOREIGN KEY (verified_by_hospital_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: donor_feedback donor_feedback_donation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_feedback
    ADD CONSTRAINT donor_feedback_donation_id_fkey FOREIGN KEY (donation_id) REFERENCES public.donations(id) ON DELETE CASCADE;


--
-- Name: donor_feedback donor_feedback_donor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_feedback
    ADD CONSTRAINT donor_feedback_donor_id_fkey FOREIGN KEY (donor_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: donor_feedback donor_feedback_target_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_feedback
    ADD CONSTRAINT donor_feedback_target_id_fkey FOREIGN KEY (target_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: donor_responses donor_responses_donor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_responses
    ADD CONSTRAINT donor_responses_donor_id_fkey FOREIGN KEY (donor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: donor_responses donor_responses_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_responses
    ADD CONSTRAINT donor_responses_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id) ON DELETE CASCADE;


--
-- Name: hospital_domains hospital_domains_verified_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_domains
    ADD CONSTRAINT hospital_domains_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: hospital_inventory hospital_inventory_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_inventory
    ADD CONSTRAINT hospital_inventory_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: hospital_inventory hospital_inventory_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hospital_inventory
    ADD CONSTRAINT hospital_inventory_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: inventory_change_log inventory_change_log_changed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_change_log
    ADD CONSTRAINT inventory_change_log_changed_by_fkey FOREIGN KEY (changed_by) REFERENCES public.users(id);


--
-- Name: inventory_change_log inventory_change_log_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_change_log
    ADD CONSTRAINT inventory_change_log_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: inventory_delivery_log inventory_delivery_log_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_delivery_log
    ADD CONSTRAINT inventory_delivery_log_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: inventory_delivery_log inventory_delivery_log_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_delivery_log
    ADD CONSTRAINT inventory_delivery_log_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id) ON DELETE SET NULL;


--
-- Name: low_inventory_alerts low_inventory_alerts_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.low_inventory_alerts
    ADD CONSTRAINT low_inventory_alerts_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: low_inventory_alerts low_inventory_alerts_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.low_inventory_alerts
    ADD CONSTRAINT low_inventory_alerts_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id) ON DELETE SET NULL;


--
-- Name: medical_records medical_records_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: medical_records medical_records_verified_by_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.medical_records
    ADD CONSTRAINT medical_records_verified_by_hospital_id_fkey FOREIGN KEY (verified_by_hospital_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: notifications notifications_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: request_audit_log request_audit_log_actor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_audit_log
    ADD CONSTRAINT request_audit_log_actor_user_id_fkey FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: request_audit_log request_audit_log_request_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.request_audit_log
    ADD CONSTRAINT request_audit_log_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.blood_requests(id) ON DELETE CASCADE;


--
-- Name: story_likes story_likes_story_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_story_id_fkey FOREIGN KEY (story_id) REFERENCES public.user_stories(id) ON DELETE CASCADE;


--
-- Name: story_likes story_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.story_likes
    ADD CONSTRAINT story_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_badge_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_badge_id_fkey FOREIGN KEY (badge_id) REFERENCES public.badges(id) ON DELETE CASCADE;


--
-- Name: user_badges user_badges_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_badges
    ADD CONSTRAINT user_badges_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_coupons user_coupons_coupon_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_coupons
    ADD CONSTRAINT user_coupons_coupon_id_fkey FOREIGN KEY (coupon_id) REFERENCES public.coupons(id);


--
-- Name: user_coupons user_coupons_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_coupons
    ADD CONSTRAINT user_coupons_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_stories user_stories_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_stories
    ADD CONSTRAINT user_stories_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: users users_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: request_audit_log audit_hospital; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_hospital ON public.request_audit_log USING ((EXISTS ( SELECT 1
   FROM public.blood_requests br
  WHERE ((br.id = request_audit_log.request_id) AND (br.hospital_id = public.current_user_id())))));


--
-- Name: request_audit_log audit_insert_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_insert_authenticated ON public.request_audit_log FOR INSERT WITH CHECK ((public.current_user_id() IS NOT NULL));


--
-- Name: request_audit_log audit_recipient; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_recipient ON public.request_audit_log FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.blood_requests br
  WHERE ((br.id = request_audit_log.request_id) AND (br.requester_id = public.current_user_id())))));


--
-- Name: badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.badges ENABLE ROW LEVEL SECURITY;

--
-- Name: badges badges_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY badges_read ON public.badges FOR SELECT USING ((auth.role() = 'authenticated'::text));


--
-- Name: blood_requests; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.blood_requests ENABLE ROW LEVEL SECURITY;

--
-- Name: blood_requests blood_requests_donor_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blood_requests_donor_read ON public.blood_requests FOR SELECT USING (((status = 'active'::text) AND (expires_at > now()) AND (public.current_user_role() = 'donor'::text)));


--
-- Name: blood_requests blood_requests_hospital; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blood_requests_hospital ON public.blood_requests USING ((hospital_id = public.current_user_id())) WITH CHECK ((hospital_id = public.current_user_id()));


--
-- Name: blood_requests blood_requests_recipient; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY blood_requests_recipient ON public.blood_requests USING ((requester_id = public.current_user_id())) WITH CHECK ((requester_id = public.current_user_id()));


--
-- Name: coupons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

--
-- Name: coupons coupons_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY coupons_read ON public.coupons FOR SELECT USING ((is_active = true));


--
-- Name: donations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.donations ENABLE ROW LEVEL SECURITY;

--
-- Name: donations donations_donor_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY donations_donor_read ON public.donations FOR SELECT USING ((donor_id = public.current_user_id()));


--
-- Name: donations donations_hospital_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY donations_hospital_read ON public.donations FOR SELECT USING ((verified_by_hospital_id = public.current_user_id()));


--
-- Name: donor_feedback; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.donor_feedback ENABLE ROW LEVEL SECURITY;

--
-- Name: donor_responses; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.donor_responses ENABLE ROW LEVEL SECURITY;

--
-- Name: donor_responses donor_responses_hospital_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY donor_responses_hospital_read ON public.donor_responses FOR SELECT USING ((EXISTS ( SELECT 1
   FROM public.blood_requests br
  WHERE ((br.id = donor_responses.request_id) AND (br.hospital_id = public.current_user_id())))));


--
-- Name: donor_responses donor_responses_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY donor_responses_own ON public.donor_responses USING ((donor_id = public.current_user_id())) WITH CHECK ((donor_id = public.current_user_id()));


--
-- Name: hospital_inventory; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hospital_inventory ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_change_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inventory_change_log ENABLE ROW LEVEL SECURITY;

--
-- Name: inventory_delivery_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.inventory_delivery_log ENABLE ROW LEVEL SECURITY;

--
-- Name: hospital_inventory inventory_hospital; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inventory_hospital ON public.hospital_inventory FOR SELECT USING ((hospital_id = public.current_user_id()));


--
-- Name: inventory_delivery_log inventory_log_hospital; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY inventory_log_hospital ON public.inventory_delivery_log FOR SELECT USING ((hospital_id = public.current_user_id()));


--
-- Name: low_inventory_alerts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.low_inventory_alerts ENABLE ROW LEVEL SECURITY;

--
-- Name: request_audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.request_audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: user_stories stories_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stories_insert ON public.user_stories FOR INSERT WITH CHECK ((author_id = auth.uid()));


--
-- Name: user_stories stories_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stories_read ON public.user_stories FOR SELECT USING (((is_approved = true) OR (author_id = auth.uid())));


--
-- Name: user_stories stories_update; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stories_update ON public.user_stories FOR UPDATE USING ((author_id = auth.uid())) WITH CHECK ((author_id = auth.uid()));


--
-- Name: story_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.story_likes ENABLE ROW LEVEL SECURITY;

--
-- Name: story_likes story_likes_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_likes_read ON public.story_likes FOR SELECT USING (true);


--
-- Name: story_likes story_likes_write; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY story_likes_write ON public.story_likes USING ((user_id = auth.uid()));


--
-- Name: user_badges; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;

--
-- Name: user_badges user_badges_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_badges_own ON public.user_badges FOR SELECT USING ((user_id = public.current_user_id()));


--
-- Name: user_coupons; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_coupons ENABLE ROW LEVEL SECURITY;

--
-- Name: user_coupons user_coupons_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY user_coupons_own ON public.user_coupons USING ((user_id = auth.uid()));


--
-- Name: user_stories; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_stories ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: users users_insert_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_insert_own ON public.users FOR INSERT WITH CHECK ((firebase_uid = COALESCE((auth.jwt() ->> 'sub'::text), (auth.uid())::text)));


--
-- Name: users users_select_leaderboard; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_leaderboard ON public.users FOR SELECT USING (((role = 'donor'::text) AND (total_donations > 0) AND (public.current_user_role() = 'donor'::text)));


--
-- Name: users users_select_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_select_own ON public.users FOR SELECT USING (((firebase_uid = COALESCE((auth.jwt() ->> 'sub'::text), (auth.uid())::text)) OR (public.is_hospital_user() AND (account_type = 'hospital'::text) AND (hospital_verified = true)) OR ((public.current_user_role() = 'donor'::text) AND (role = 'donor'::text) AND (account_type = 'regular'::text))));


--
-- Name: users users_update_own; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY users_update_own ON public.users FOR UPDATE USING ((firebase_uid = COALESCE((auth.jwt() ->> 'sub'::text), (auth.uid())::text)));


--
-- PostgreSQL database dump complete
--

\unrestrict OTzgAqRRJ8Kth7IahdLQSiAX3u3abqbR8IIazBjnlIOWrXiDb8ikjjQ8ysixuo3

