-- Migration 007: Inventory Management, Low Inventory Alerts, Donor Feedback

-- ============================================================
-- PART 1: Inventory Management Enhancements
-- ============================================================

ALTER TABLE hospital_inventory
  ADD COLUMN IF NOT EXISTS expiration_date DATE;

CREATE TABLE IF NOT EXISTS inventory_change_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hospital_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blood_type VARCHAR(3) NOT NULL CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-')),
    change_type TEXT NOT NULL CHECK (change_type IN ('added', 'removed', 'adjusted', 'threshold_changed', 'expiration_updated')),
    units_before INTEGER NOT NULL DEFAULT 0,
    units_after INTEGER NOT NULL DEFAULT 0,
    threshold_before INTEGER,
    threshold_after INTEGER,
    units_changed INTEGER NOT NULL DEFAULT 0,
    reason TEXT,
    changed_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_change_log_hospital
  ON inventory_change_log(hospital_id);
CREATE INDEX IF NOT EXISTS idx_inventory_change_log_hospital_bt
  ON inventory_change_log(hospital_id, blood_type);
CREATE INDEX IF NOT EXISTS idx_inventory_change_log_created
  ON inventory_change_log(created_at DESC);

CREATE OR REPLACE FUNCTION add_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_expiration_date DATE DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION remove_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_hospital_inventory_units(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER,
    p_reason TEXT DEFAULT NULL,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT, units_available INTEGER) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_hospital_inventory_threshold(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_threshold INTEGER,
    p_changed_by UUID DEFAULT NULL
) RETURNS TABLE (success BOOLEAN, error_message TEXT) AS $$
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
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW inventory_history_view AS
SELECT
    icl.id,
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

-- ============================================================
-- PART 2: Automatic Low Inventory Blood Requests
-- ============================================================

ALTER TABLE blood_requests
  ADD COLUMN IF NOT EXISTS is_auto_request BOOLEAN DEFAULT FALSE;
ALTER TABLE blood_requests
  ADD COLUMN IF NOT EXISTS auto_request_source_hospital_id UUID REFERENCES users(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS low_inventory_alerts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hospital_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blood_type VARCHAR(3) NOT NULL CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-')),
    request_id UUID REFERENCES blood_requests(id) ON DELETE SET NULL,
    units_available_at_alert INTEGER NOT NULL,
    threshold_at_alert INTEGER NOT NULL,
    alert_status TEXT NOT NULL DEFAULT 'pending' CHECK (alert_status IN ('pending', 'notified', 'resolved', 'suppressed')),
    notified_donors_count INTEGER DEFAULT 0,
    resolved_at TIMESTAMP WITHOUT TIME ZONE,
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_low_inventory_alerts_unique_active
  ON low_inventory_alerts(hospital_id, blood_type) WHERE alert_status IN ('pending', 'notified');
CREATE INDEX IF NOT EXISTS idx_low_inventory_alerts_created
  ON low_inventory_alerts(created_at DESC);

DROP FUNCTION IF EXISTS check_and_alert_low_inventory();

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
                1,
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

CREATE OR REPLACE FUNCTION mark_alert_notified(p_request_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE low_inventory_alerts SET alert_status = 'notified',
        notified_donors_count = (SELECT COUNT(*) FROM donor_responses WHERE request_id = p_request_id)
    WHERE request_id = p_request_id AND alert_status = 'pending';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION resolve_low_inventory_alerts(p_hospital_id UUID, p_blood_type VARCHAR(3))
RETURNS VOID AS $$
BEGIN
    UPDATE low_inventory_alerts SET alert_status = 'resolved', resolved_at = NOW()
    WHERE hospital_id = p_hospital_id AND blood_type = p_blood_type AND alert_status IN ('pending', 'notified');
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PART 3: Donor Feedback & Rating System
-- ============================================================

CREATE TABLE IF NOT EXISTS donor_feedback (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    donation_id UUID NOT NULL REFERENCES donations(id) ON DELETE CASCADE,
    donor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    feedback_type TEXT NOT NULL CHECK (feedback_type IN ('recipient_request', 'hospital_request')),
    target_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Common ratings (1-5)
    overall_rating INTEGER CHECK (overall_rating >= 1 AND overall_rating <= 5),

    -- Recipient request ratings
    communication_rating INTEGER CHECK (communication_rating >= 1 AND communication_rating <= 5),
    organization_rating INTEGER CHECK (organization_rating >= 1 AND organization_rating <= 5),

    -- Hospital request ratings
    hospital_efficiency_rating INTEGER CHECK (hospital_efficiency_rating >= 1 AND hospital_efficiency_rating <= 5),
    staff_professionalism_rating INTEGER CHECK (staff_professionalism_rating >= 1 AND staff_professionalism_rating <= 5),
    cleanliness_rating INTEGER CHECK (cleanliness_rating >= 1 AND cleanliness_rating <= 5),
    waiting_time_rating INTEGER CHECK (waiting_time_rating >= 1 AND waiting_time_rating <= 5),

    -- Written feedback
    comment TEXT,
    is_anonymous BOOLEAN DEFAULT FALSE,

    -- Metadata
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),

    -- One feedback per donation
    UNIQUE(donation_id, donor_id)
);

CREATE INDEX IF NOT EXISTS idx_donor_feedback_donor ON donor_feedback(donor_id);
CREATE INDEX IF NOT EXISTS idx_donor_feedback_target ON donor_feedback(target_id);
CREATE INDEX IF NOT EXISTS idx_donor_feedback_type ON donor_feedback(feedback_type);
CREATE INDEX IF NOT EXISTS idx_donor_feedback_created ON donor_feedback(created_at DESC);

-- Function to get hospital feedback analytics
CREATE OR REPLACE FUNCTION get_hospital_feedback_analytics(p_hospital_id UUID)
RETURNS TABLE (
    total_feedbacks BIGINT,
    avg_overall NUMERIC(3,2),
    avg_efficiency NUMERIC(3,2),
    avg_professionalism NUMERIC(3,2),
    avg_cleanliness NUMERIC(3,2),
    avg_waiting_time NUMERIC(3,2),
    rating_1_count BIGINT,
    rating_2_count BIGINT,
    rating_3_count BIGINT,
    rating_4_count BIGINT,
    rating_5_count BIGINT
) AS $$
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
$$ LANGUAGE plpgsql;

-- Function to get recipient feedback analytics
CREATE OR REPLACE FUNCTION get_recipient_feedback_analytics(p_recipient_id UUID)
RETURNS TABLE (
    total_feedbacks BIGINT,
    avg_overall NUMERIC(3,2),
    avg_communication NUMERIC(3,2),
    avg_organization NUMERIC(3,2)
) AS $$
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
$$ LANGUAGE plpgsql;

-- Trigger to update updated_at
CREATE TRIGGER update_donor_feedback_updated_at BEFORE UPDATE ON donor_feedback
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
