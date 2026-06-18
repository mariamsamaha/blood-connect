-- Migration 008: Fix ambiguous column references in PL/pgSQL functions
--
-- The RETURNS TABLE clause creates PL/pgSQL variables that shadow table
-- columns.  Queries that reference them unqualified become ambiguous
-- (PostgreSQL error 42702).
--
-- Affected: inventory_history_view, add_hospital_inventory_units,
-- remove_hospital_inventory_units, set_hospital_inventory_units,
-- check_and_alert_low_inventory.

-- Fix 1: inventory_history_view was missing the hospital_id column.
DROP VIEW IF EXISTS inventory_history_view CASCADE;
CREATE VIEW inventory_history_view AS
SELECT
    icl.id,
    icl.hospital_id,
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
FROM inventory_change_log icl
JOIN users u ON u.id = icl.hospital_id
LEFT JOIN users changer ON changer.id = icl.changed_by
ORDER BY icl.created_at DESC;

-- Fix 2: add_hospital_inventory_units — RETURNING clause ambiguous.
CREATE OR REPLACE FUNCTION add_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_expiration_date DATE DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
DECLARE
    v_units_before INTEGER := 0;
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
    RETURNING hospital_inventory.units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'added', v_units_before, v_units_after, p_units, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$ LANGUAGE plpgsql;

-- Fix 3: remove_hospital_inventory_units — UPDATE SET and RETURNING ambiguous.
CREATE OR REPLACE FUNCTION remove_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
DECLARE
    v_units_before INTEGER := 0;
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
        units_available = hospital_inventory.units_available - p_units,
        last_updated = NOW(),
        updated_by = v_actor
    WHERE hospital_id = p_hospital_id AND blood_type = p_blood_type
    RETURNING hospital_inventory.units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'removed', v_units_before, v_units_after, -p_units, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$ LANGUAGE plpgsql;

-- Fix 4: set_hospital_inventory_units — RETURNING clause ambiguous.
CREATE OR REPLACE FUNCTION set_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
DECLARE
    v_units_before INTEGER := 0;
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
    RETURNING hospital_inventory.units_available INTO v_units_after;
    INSERT INTO inventory_change_log (hospital_id, blood_type, change_type, units_before, units_after, units_changed, reason, changed_by)
    VALUES (p_hospital_id, p_blood_type, 'adjusted', v_units_before, v_units_after, p_units - v_units_before, p_reason, v_actor);
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_units_after;
END;
$$ LANGUAGE plpgsql;

-- Fix 5: check_and_alert_low_inventory — SELECT columns ambiguous.
CREATE OR REPLACE FUNCTION check_and_alert_low_inventory()
RETURNS TABLE (
    hospital_id UUID,
    hospital_name TEXT,
    blood_type VARCHAR(3),
    units_available INTEGER,
    minimum_threshold INTEGER,
    action_taken TEXT
) AS $$
DECLARE
    v_hospital RECORD;
    v_inv RECORD;
    v_existing_alert INTEGER;
    v_request_id UUID;
    v_short_id TEXT;
    v_donor_count INTEGER;
BEGIN
    FOR v_hospital IN SELECT id, users.hospital_name, hospital_code FROM users WHERE account_type = 'hospital' AND is_active = TRUE LOOP
        FOR v_inv IN SELECT hospital_inventory.blood_type, hospital_inventory.units_available, hospital_inventory.minimum_threshold
                     FROM hospital_inventory
                     WHERE hospital_inventory.hospital_id = v_hospital.id AND hospital_inventory.units_available < hospital_inventory.minimum_threshold AND hospital_inventory.units_available >= 0
        LOOP
            SELECT COUNT(*) INTO v_existing_alert
            FROM low_inventory_alerts
            WHERE low_inventory_alerts.hospital_id = v_hospital.id
              AND low_inventory_alerts.blood_type = v_inv.blood_type
              AND low_inventory_alerts.alert_status IN ('pending', 'notified')
              AND low_inventory_alerts.created_at > NOW() - INTERVAL '24 hours';
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
$$ LANGUAGE plpgsql;
