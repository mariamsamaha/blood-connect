-- MVP database additions (run on Supabase after bloodconnect_schema.sql).

ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS city_area TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS donor_responses_one_accepted_per_request
  ON donor_responses (request_id)
  WHERE (response_type = 'accepted');

CREATE TABLE IF NOT EXISTS request_audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES blood_requests(id) ON DELETE CASCADE,
    event_type TEXT NOT NULL,
    detail TEXT,
    actor_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_request_audit_request_id ON request_audit_log(request_id);

CREATE TABLE IF NOT EXISTS inventory_delivery_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hospital_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blood_type VARCHAR(3) NOT NULL,
    units INTEGER NOT NULL DEFAULT 1 CHECK (units > 0),
    request_id UUID REFERENCES blood_requests(id) ON DELETE SET NULL,
    note TEXT,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION verify_request_donation(
    p_request_id UUID,
    p_hospital_user_id UUID,
    p_staff_name TEXT DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT) AS $$
DECLARE
    v_status TEXT;
    v_hospital UUID;
    v_requester UUID;
    v_donor UUID;
    v_blood VARCHAR(3);
    v_units INT;
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
        RETURN QUERY SELECT FALSE, format('Request cannot be verified while status is %s', v_status)::TEXT;
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

    UPDATE blood_requests SET
        status = 'fulfilled',
        fulfilled_at = NOW(),
        units_fulfilled = v_units,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id;

    INSERT INTO donations (
        request_id, donor_id, verified_by_hospital_id, verified_by_hospital_staff,
        units_donated, donation_type
    ) VALUES (
        p_request_id, v_donor, p_hospital_user_id, p_staff_name,
        1, 'whole_blood'
    );

    INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
    VALUES (
        p_request_id,
        'verified_closed',
        'Hospital verified donation; 1 unit logged (MVP).',
        p_hospital_user_id
    );

    INSERT INTO inventory_delivery_log (hospital_id, blood_type, units, request_id, note)
    VALUES (
        p_hospital_user_id, v_blood, 1, p_request_id,
        '1 unit delivered (MVP inventory log)'
    );

    PERFORM increment_hospital_inventory(p_hospital_user_id, v_blood, 1);

    UPDATE users SET
        is_recipient = FALSE,
        active_mode = 'donor_view',
        updated_at = NOW()
    WHERE id = v_requester;

    UPDATE users SET
        total_donations = COALESCE(total_donations, 0) + 1,
        last_donation_date = CURRENT_DATE,
        reward_points = COALESCE(reward_points, 0) + 10,
        updated_at = NOW()
    WHERE id = v_donor;

    RETURN QUERY SELECT TRUE, NULL::TEXT;
END;
$$ LANGUAGE plpgsql;
