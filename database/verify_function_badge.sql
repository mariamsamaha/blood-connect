-- Auto-award badges function for verify_request_donation
-- Run this SQL in Supabase SQL Editor

CREATE OR REPLACE FUNCTION verify_request_donation(
    p_request_id UUID,
    p_hospital_user_id UUID,
    p_staff_name TEXT DEFAULT NULL
)
RETURNS TABLE (success BOOLEAN, error_message TEXT)
LANGUAGE plpgsql
AS $func$
DECLARE
    v_status TEXT;
    v_hospital UUID;
    v_requester UUID;
    v_donor UUID;
    v_blood VARCHAR(3);
    v_units INT;
    v_is_auto_request BOOLEAN;
BEGIN
    SELECT br.status, br.hospital_id, br.requester_id, br.blood_type, br.units_needed, br.is_auto_request
    INTO v_status, v_hospital, v_requester, v_blood, v_units, v_is_auto_request
    FROM blood_requests br
    WHERE br.id = p_request_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Request not found';
        RETURN;
    END IF;

    IF v_hospital IS DISTINCT FROM p_hospital_user_id THEN
        RETURN QUERY SELECT FALSE, 'This request belongs to another hospital';
        RETURN;
    END IF;

    IF v_status <> 'in_progress' THEN
        RETURN QUERY SELECT FALSE, format('Request cannot be verified while status is %s', v_status);
        RETURN;
    END IF;

    SELECT dr.donor_id INTO v_donor
    FROM donor_responses dr
    WHERE dr.request_id = p_request_id AND dr.response_type = 'accepted'
    LIMIT 1;

    IF v_donor IS NULL THEN
        RETURN QUERY SELECT FALSE, 'No donor has accepted this request yet';
        RETURN;
    END IF;

    UPDATE blood_requests SET
        status = 'fulfilled',
        fulfilled_at = NOW(),
        units_fulfilled = v_units,
        updated_at = NOW(),
        version = version + 1
    WHERE id = p_request_id;

    INSERT INTO donations (request_id, donor_id, verified_by_hospital_id, verified_by_hospital_staff, units_donated, donation_type)
    VALUES (p_request_id, v_donor, p_hospital_user_id, p_staff_name, 1, 'whole_blood');

    INSERT INTO request_audit_log (request_id, event_type, detail, actor_user_id)
    VALUES (p_request_id, 'verified_closed', 'Hospital verified donation', p_hospital_user_id);

    INSERT INTO inventory_delivery_log (hospital_id, blood_type, units, request_id, note)
    VALUES (p_hospital_user_id, v_blood, 1, p_request_id, '1 unit delivered');

    PERFORM increment_hospital_inventory(p_hospital_user_id, v_blood, 1);

    IF v_is_auto_request THEN
        PERFORM resolve_low_inventory_alerts(p_hospital_user_id, v_blood);
    END IF;

    UPDATE users SET is_recipient = FALSE, updated_at = NOW() WHERE id = v_requester;

    UPDATE users SET
        total_donations = COALESCE(total_donations, 0) + 1,
        last_donation_date = CURRENT_DATE,
        reward_points = COALESCE(reward_points, 0) + 10,
        updated_at = NOW()
    WHERE id = v_donor;

    INSERT INTO user_badges (user_id, badge_id)
    SELECT v_donor, b.id
    FROM badges b
    WHERE b.requirement_type = 'donation_count'
      AND b.requirement_value <= (SELECT total_donations FROM users WHERE id = v_donor)
      AND NOT EXISTS (
          SELECT 1 FROM user_badges ub WHERE ub.user_id = v_donor AND ub.badge_id = b.id
      );

    RETURN QUERY SELECT TRUE, NULL;
END;
$func$;