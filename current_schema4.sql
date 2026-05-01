--
-- PostgreSQL database dump
--

\restrict k77EDWJjH8TrOrJfHQsTRpuUAmZfjZDDABlRE1QVUZFtdATht6O9SHtzBi8b3Yi

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
-- Name: update_slot_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_slot_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.status = 'scheduled' THEN
            UPDATE appointment_slots SET current_count = current_count + 1
            WHERE id = NEW.slot_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status = 'scheduled' AND NEW.status IN ('cancelled', 'completed') THEN
            UPDATE appointment_slots SET current_count = current_count - 1
            WHERE id = NEW.slot_id;
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
-- Name: appointment_slots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appointment_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    hospital_id uuid,
    slot_date date NOT NULL,
    slot_time time without time zone NOT NULL,
    max_donors integer DEFAULT 5,
    current_count integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: appointments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.appointments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    donor_id uuid,
    slot_id uuid,
    blood_type character varying(3),
    status character varying(20) DEFAULT 'scheduled'::character varying,
    notes text,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT appointments_status_check CHECK (((status)::text = ANY ((ARRAY['scheduled'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);


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
    CONSTRAINT blood_requests_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT blood_requests_status_check CHECK ((status = ANY (ARRAY['active'::text, 'in_progress'::text, 'fulfilled'::text, 'cancelled'::text, 'expired'::text]))),
    CONSTRAINT blood_requests_units_fulfilled_check CHECK ((units_fulfilled >= 0)),
    CONSTRAINT blood_requests_units_needed_check CHECK ((units_needed > 0)),
    CONSTRAINT blood_requests_urgency_level_check CHECK ((urgency_level = ANY (ARRAY['routine'::text, 'urgent'::text, 'critical'::text])))
);


--
-- Name: donations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.donations (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    request_id uuid NOT NULL,
    donor_id uuid NOT NULL,
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
    donor_id uuid NOT NULL,
    response_type text NOT NULL,
    distance_km numeric(6,2),
    estimated_arrival timestamp without time zone,
    responded_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
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
    CONSTRAINT hospital_fields_required CHECK ((((account_type = 'hospital'::text) AND (hospital_name IS NOT NULL) AND (hospital_code IS NOT NULL)) OR (account_type = 'regular'::text))),
    CONSTRAINT users_account_type_check CHECK ((account_type = ANY (ARRAY['regular'::text, 'hospital'::text]))),
    CONSTRAINT users_blood_type_check CHECK (((blood_type)::text = ANY ((ARRAY['A+'::character varying, 'A-'::character varying, 'B+'::character varying, 'B-'::character varying, 'O+'::character varying, 'O-'::character varying, 'AB+'::character varying, 'AB-'::character varying])::text[]))),
    CONSTRAINT users_donor_status_check CHECK ((donor_status = ANY (ARRAY['available'::text, 'unavailable'::text, 'on_cooldown'::text]))),
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
    CONSTRAINT notifications_notification_type_check CHECK ((notification_type = ANY (ARRAY['request_alert'::text, 'fulfillment_update'::text, 'reward_earned'::text, 'system_message'::text])))
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
-- Name: user_badges; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_badges (
    id uuid DEFAULT extensions.uuid_generate_v4() NOT NULL,
    user_id uuid NOT NULL,
    badge_id uuid NOT NULL,
    earned_at timestamp without time zone DEFAULT now()
);


--
-- Name: appointment_slots appointment_slots_hospital_id_slot_date_slot_time_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_slots
    ADD CONSTRAINT appointment_slots_hospital_id_slot_date_slot_time_key UNIQUE (hospital_id, slot_date, slot_time);


--
-- Name: appointment_slots appointment_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_slots
    ADD CONSTRAINT appointment_slots_pkey PRIMARY KEY (id);


--
-- Name: appointments appointments_donor_slot_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_donor_slot_unique UNIQUE (donor_id, slot_id);


--
-- Name: appointments appointments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);


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
-- Name: donations donations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donations
    ADD CONSTRAINT donations_pkey PRIMARY KEY (id);


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
-- Name: inventory_delivery_log inventory_delivery_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.inventory_delivery_log
    ADD CONSTRAINT inventory_delivery_log_pkey PRIMARY KEY (id);


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
-- Name: idx_user_badges_earned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_badges_earned_at ON public.user_badges USING btree (earned_at DESC);


--
-- Name: idx_user_badges_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_badges_user_id ON public.user_badges USING btree (user_id);


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
-- Name: appointments sync_slot_count; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER sync_slot_count AFTER INSERT OR UPDATE ON public.appointments FOR EACH ROW EXECUTE FUNCTION public.update_slot_count();


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
-- Name: appointment_slots appointment_slots_hospital_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointment_slots
    ADD CONSTRAINT appointment_slots_hospital_id_fkey FOREIGN KEY (hospital_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: appointments appointments_donor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_donor_id_fkey FOREIGN KEY (donor_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: appointments appointments_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.appointments
    ADD CONSTRAINT appointments_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.appointment_slots(id);


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
-- Name: donor_responses donor_responses_donor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.donor_responses
    ADD CONSTRAINT donor_responses_donor_id_fkey FOREIGN KEY (donor_id) REFERENCES public.users(id) ON DELETE CASCADE;


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
-- Name: users users_approved_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict k77EDWJjH8TrOrJfHQsTRpuUAmZfjZDDABlRE1QVUZFtdATht6O9SHtzBi8b3Yi

