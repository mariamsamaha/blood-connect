CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- USERS TABLE

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    firebase_uid TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    phone TEXT,
    blood_type VARCHAR(3) CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-')),

    -- PostGIS geography type for accurate distance calculations, SRID 4326 = WGS84 coordinate system (standard for GPS
    location GEOGRAPHY(POINT, 4326),
    
    -- ACCOUNT TYPE (Who they are - permanent)
   
    account_type TEXT NOT NULL DEFAULT 'regular' CHECK (account_type IN ('regular', 'hospital')),
    

    is_donor BOOLEAN DEFAULT TRUE,      -- Can receive donation alerts
    is_recipient BOOLEAN DEFAULT FALSE, -- Currently has active blood request
    

    last_donation_date DATE,      -- donor specific fields
    total_donations INTEGER DEFAULT 0,
    reward_points INTEGER DEFAULT 0,
    donor_status TEXT DEFAULT 'available' CHECK (donor_status IN ('available', 'unavailable', 'on_cooldown')),
    
    -- hospital specific fields
    hospital_name TEXT,
    hospital_code VARCHAR(10) UNIQUE, 
    hospital_verified BOOLEAN DEFAULT FALSE,
    hospital_approval_date TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    
    -- curent UI mode (What they're viewing now)
    active_mode TEXT DEFAULT 'donor_view' CHECK (active_mode IN ('donor_view', 'recipient_view', 'hospital_view')),
    
    -- USER PREFERENCES
    notification_enabled BOOLEAN DEFAULT TRUE,
    notification_radius_km INTEGER DEFAULT 25,
    
    -- METADATA
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    
    -- CONSTRAINTS
    CONSTRAINT hospital_fields_required CHECK (
        (account_type = 'hospital' AND hospital_name IS NOT NULL AND hospital_code IS NOT NULL) OR
        (account_type = 'regular')
    ),
    CONSTRAINT hospital_mode_required CHECK (
        (account_type = 'hospital' AND active_mode = 'hospital_view') OR
        (account_type = 'regular')
    )
);

-- Indexes for performance
CREATE INDEX idx_users_firebase_uid ON users(firebase_uid);
CREATE INDEX idx_users_account_type ON users(account_type);
CREATE INDEX idx_users_is_donor ON users(is_donor) WHERE is_donor = TRUE;
CREATE INDEX idx_users_donor_status ON users(donor_status) WHERE donor_status = 'available';
CREATE INDEX idx_users_blood_type ON users(blood_type);
CREATE INDEX idx_users_location ON users USING GIST(location); -- Spatial index for fast proximity queries
CREATE INDEX idx_users_hospital_code ON users(hospital_code) WHERE hospital_code IS NOT NULL;

-- BLOOD_REQUESTS TABLE
-- Stores all blood donation requests

CREATE TABLE blood_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    short_id VARCHAR(20) UNIQUE NOT NULL,
    
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blood_type VARCHAR(3) NOT NULL CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-')),
    units_needed INTEGER NOT NULL CHECK (units_needed > 0),
    units_fulfilled INTEGER DEFAULT 0 CHECK (units_fulfilled >= 0),
    
    -- Urgency level determines notification strategy
    urgency_level TEXT NOT NULL CHECK (urgency_level IN ('routine', 'urgent', 'critical')),
    
    -- Location details
    hospital_name TEXT NOT NULL,
    hospital_id UUID REFERENCES users(id), 
    hospital_location GEOGRAPHY(POINT, 4326) NOT NULL,
    requester_location GEOGRAPHY(POINT, 4326),
    -- Request metadata
    description TEXT,
    patient_name TEXT,
    contact_phone TEXT,
    
    -- Status tracking
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'in_progress', 'fulfilled', 'cancelled', 'expired')),
    
    -- Matching statistics
    nearby_donors_count INTEGER DEFAULT 0,
    total_eligible_count INTEGER DEFAULT 0,
    notified_donors_count INTEGER DEFAULT 0,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    fulfilled_at TIMESTAMP,
    
    -- Optimistic locking for concurrent updates
    version INTEGER DEFAULT 1
);

-- Indexes
CREATE INDEX idx_requests_short_id ON blood_requests(short_id);
CREATE INDEX idx_requests_requester_id ON blood_requests(requester_id);
CREATE INDEX idx_requests_blood_type ON blood_requests(blood_type);
CREATE INDEX idx_requests_status ON blood_requests(status);
CREATE INDEX idx_requests_urgency ON blood_requests(urgency_level);
CREATE INDEX idx_requests_location ON blood_requests USING GIST(hospital_location);
CREATE INDEX idx_requests_requester_location ON blood_requests USING GIST(requester_location);
CREATE INDEX idx_requests_created_at ON blood_requests(created_at DESC);
CREATE INDEX idx_requests_active ON blood_requests(status) WHERE status = 'active'; -- Partial index for active requests

-- Tracks donor responses to blood requests
CREATE TABLE donor_responses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES blood_requests(id) ON DELETE CASCADE,
    donor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Response details
    response_type TEXT NOT NULL CHECK (response_type IN ('accepted', 'declined', 'interested', 'en_route', 'arrived')),
    distance_km NUMERIC(6, 2), -- Distance from donor to hospital at time of response
    estimated_arrival TIMESTAMP,
    
    -- Timestamps
    responded_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- Prevent duplicate responses
    UNIQUE(request_id, donor_id)
);

-- Indexes
CREATE INDEX idx_donor_responses_request_id ON donor_responses(request_id);
CREATE INDEX idx_donor_responses_donor_id ON donor_responses(donor_id);
CREATE INDEX idx_donor_responses_type ON donor_responses(response_type);


-- DONATIONS TABLE: Records completed, verified donations
CREATE TABLE donations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    request_id UUID NOT NULL REFERENCES blood_requests(id),
    donor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Hospital verification
    verified_by_hospital_id UUID NOT NULL REFERENCES users(id),
    verified_by_hospital_staff TEXT, -- Name of the staff member who verified
    
    -- Donation details
    units_donated INTEGER NOT NULL CHECK (units_donated > 0),
    donation_type TEXT CHECK (donation_type IN ('whole_blood', 'platelets', 'plasma')),
    
    -- Rewards
    points_awarded INTEGER DEFAULT 10,
    badge_earned TEXT, -- 'first_donation', 'lifesaver', '10_donations'
    
    -- Timestamps
    donation_date TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_donations_request_id ON donations(request_id);
CREATE INDEX idx_donations_donor_id ON donations(donor_id);
CREATE INDEX idx_donations_verified_by ON donations(verified_by_hospital_id);
CREATE INDEX idx_donations_date ON donations(donation_date DESC);

-- MEDICAL_RECORDS TABLE that Stores AI-extracted medical eligibility data
CREATE TABLE medical_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Extracted medical values
    hemoglobin NUMERIC(4, 2), -- g/dL
    blood_pressure_systolic INTEGER,
    blood_pressure_diastolic INTEGER,
    weight_kg NUMERIC(5, 2),
    
    -- Document metadata
    report_date DATE NOT NULL,
    report_image_url TEXT,
    lab_name TEXT,
    
    -- AI processing results
    ai_confidence NUMERIC(3, 2) CHECK (ai_confidence >= 0 AND ai_confidence <= 1),
    extraction_method TEXT CHECK (extraction_method IN ('ai_vit', 'manual_entry', 'hospital_verified')),
    
    -- Eligibility determination
    eligibility_status TEXT NOT NULL CHECK (eligibility_status IN ('eligible', 'not_eligible', 'manual_review_required')),
    ineligibility_reasons TEXT[], -- Array of reasons: ['low_hemoglobin', 'recent_donation', 'weight_insufficient']
    
    -- Hospital verification override
    verified_by_hospital BOOLEAN DEFAULT FALSE,
    verified_by_hospital_id UUID REFERENCES users(id),
    verification_notes TEXT,
    
    -- Timestamps
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP -- Medical reports expire after 3 months
);

-- Indexes
CREATE INDEX idx_medical_records_user_id ON medical_records(user_id);
CREATE INDEX idx_medical_records_eligibility ON medical_records(eligibility_status);
CREATE INDEX idx_medical_records_report_date ON medical_records(report_date DESC);
CREATE INDEX idx_medical_records_expires_at ON medical_records(expires_at);

-- HOSPITAL_INVENTORY TABLE : Tracks hospital blood bank inventory
CREATE TABLE hospital_inventory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    hospital_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    blood_type VARCHAR(3) NOT NULL CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-')),
    
    -- Inventory levels
    units_available INTEGER DEFAULT 0 CHECK (units_available >= 0),
    units_reserved INTEGER DEFAULT 0 CHECK (units_reserved >= 0),
    minimum_threshold INTEGER DEFAULT 5, -- Alert when inventory drops below this
    
    -- Metadata
    last_updated TIMESTAMP DEFAULT NOW(),
    updated_by UUID REFERENCES users(id),
    
    -- Ensure one row per hospital per blood type
    UNIQUE(hospital_id, blood_type)
);

-- Indexes
CREATE INDEX idx_inventory_hospital_id ON hospital_inventory(hospital_id);
CREATE INDEX idx_inventory_blood_type ON hospital_inventory(blood_type);
CREATE INDEX idx_inventory_low_stock ON hospital_inventory(units_available) WHERE units_available < minimum_threshold;

-- NOTIFICATIONS TABLE : Logs all sent notifications for analytics
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    request_id UUID REFERENCES blood_requests(id) ON DELETE CASCADE,
    
    -- Notification details
    notification_type TEXT NOT NULL CHECK (notification_type IN ('request_alert', 'fulfillment_update', 'reward_earned', 'system_message')),
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    
    -- Delivery tracking
    sent_at TIMESTAMP DEFAULT NOW(),
    delivered_at TIMESTAMP,
    read_at TIMESTAMP,
    clicked_at TIMESTAMP,
    
    -- FCM details
    fcm_token TEXT,
    fcm_message_id TEXT,
    delivery_status TEXT CHECK (delivery_status IN ('sent', 'delivered', 'failed', 'clicked'))
);

-- Indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_request_id ON notifications(request_id);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

-- HOSPITAL_DOMAINS TABLE : Whitelist of verified hospital email domains
CREATE TABLE hospital_domains (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    domain TEXT UNIQUE NOT NULL,
    hospital_name TEXT,
    contact_email TEXT,
    verified_at TIMESTAMP WITHOUT TIME ZONE DEFAULT NOW(),
    verified_by UUID REFERENCES users(id),
    active BOOLEAN DEFAULT TRUE,
    -- Active status field for hospital verification workflow
    active_status BOOLEAN DEFAULT TRUE,
    active_reason TEXT
);

-- ============================================================
-- SEED DATA - Hospital Domains
-- ============================================================

INSERT INTO hospital_domains (domain, hospital_name, contact_email, verified_at, active) VALUES
    ('cairo.general.eg', 'Cairo General Hospital', 'admin@cairo.general.eg', NOW(), TRUE),
    ('ain.shams.hospital.eg', 'Ain Shams University Hospital', 'info@ain.shams.edu.eg', NOW(), TRUE),
    ('dar.alfouad.eg', 'Dar Al Fouad Hospital', 'support@dar.alfouad.eg', NOW(), TRUE),
    ('cleopatra.hospitals.com', 'Cleopatra Hospitals', 'admin@cleopatra.hospitals.com', NOW(), TRUE),
    ('zewailcity.edu.eg', 'Zewail City University Hospital', 'admin@zewailcity.edu.eg', NOW(), TRUE),  
    ('qasr.elainy.eg', 'Qasr El Ainy Hospital', 'support@qasr.edu.eg', NOW(), TRUE)
ON CONFLICT (domain) DO NOTHING;

-- BADGES TABLE : Defines achievement badges for gamification
CREATE TABLE badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    badge_code VARCHAR(50) UNIQUE NOT NULL, -- e.g., 'first_donation', 'lifesaver_10'
    badge_name TEXT NOT NULL,
    description TEXT,
    icon_url TEXT,
    requirement_type TEXT CHECK (requirement_type IN ('donation_count', 'consecutive_months', 'critical_response', 'rare_blood')),
    requirement_value INTEGER,
    points_value INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- USER_BADGES TABLE : Tracks badges earned by users
CREATE TABLE user_badges (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(user_id, badge_id)
);

-- Indexes
CREATE INDEX idx_user_badges_user_id ON user_badges(user_id);
CREATE INDEX idx_user_badges_earned_at ON user_badges(earned_at DESC);


-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update trigger to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_requests_updated_at BEFORE UPDATE ON blood_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_medical_records_updated_at BEFORE UPDATE ON medical_records
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to automatically update donor_status based on last_donation_date
CREATE OR REPLACE FUNCTION update_donor_status()
RETURNS TRIGGER AS $$
BEGIN
    -- Only for regular users who are donors
    IF NEW.account_type = 'regular' AND NEW.is_donor = TRUE THEN
        IF NEW.last_donation_date IS NOT NULL THEN
            -- Check if still in cooldown period (90 days)
            IF CURRENT_DATE - NEW.last_donation_date < 90 THEN
                NEW.donor_status := 'on_cooldown';
            ELSE
                NEW.donor_status := 'available';
            END IF;
        ELSE
            -- Never donated before - available
            NEW.donor_status := 'available';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update donor_status when last_donation_date changes
CREATE TRIGGER auto_update_donor_status
    BEFORE INSERT OR UPDATE OF last_donation_date ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_donor_status();

-- Function to generate short request ID
CREATE OR REPLACE FUNCTION generate_short_request_id(hospital_code TEXT)
RETURNS TEXT AS $$
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
$$ LANGUAGE plpgsql;

-- Function to check if email is from verified hospital domain
CREATE OR REPLACE FUNCTION is_hospital_email(p_email TEXT)
RETURNS BOOLEAN AS $$
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
$$ LANGUAGE plpgsql;

-- Function to increment hospital inventory atomically
CREATE OR REPLACE FUNCTION increment_hospital_inventory(
    p_hospital_id UUID,
    p_blood_type VARCHAR(3),
    p_units INTEGER
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO hospital_inventory (hospital_id, blood_type, units_available)
    VALUES (p_hospital_id, p_blood_type, p_units)
    ON CONFLICT (hospital_id, blood_type)
    DO UPDATE SET
        units_available = hospital_inventory.units_available + p_units,
        last_updated = NOW();
END;
$$ LANGUAGE plpgsql;

-- Function to find nearby eligible donors (CRITICAL QUERY) Uses capability-based matching: searches for is_donor = TRUE
CREATE OR REPLACE FUNCTION find_nearby_donors(
    p_blood_type VARCHAR(3),
    p_location GEOGRAPHY,
    p_max_distance_km INTEGER DEFAULT 50,
    p_limit INTEGER DEFAULT 100
)
RETURNS TABLE (
    user_id UUID,
    name TEXT,
    blood_type VARCHAR(3),
    phone TEXT,
    distance_km NUMERIC,
    days_since_last_donation INTEGER,
    total_donations INTEGER,
    reward_points INTEGER,
    currently_requesting BOOLEAN,
    active_mode TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id AS user_id,
        u.name,
        u.blood_type,
        u.phone,
        ROUND((ST_Distance(u.location, p_location) / 1000)::numeric, 2) AS distance_km,
        COALESCE(CURRENT_DATE - u.last_donation_date, 999) AS days_since_last_donation,
        u.total_donations,
        u.reward_points,
        u.is_recipient AS currently_requesting,
        u.active_mode
    FROM users u
    WHERE u.account_type = 'regular'
        AND u.is_donor = TRUE
        AND u.donor_status = 'available'
        AND u.blood_type = p_blood_type
        AND u.is_active = TRUE
        AND u.notification_enabled = TRUE
        AND u.location IS NOT NULL
        AND ST_DWithin(u.location, p_location, p_max_distance_km * 1000)
        AND (u.last_donation_date IS NULL OR CURRENT_DATE - u.last_donation_date >= 90)
    ORDER BY 
        u.is_recipient ASC,
        ST_Distance(u.location, p_location) ASC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

-- SAMPLE DATA 

-- Insert sample regular users (donors)
INSERT INTO users (firebase_uid, email, name, blood_type, account_type, is_donor, is_recipient, active_mode, location) VALUES
    ('firebase_donor_1', 'ahmed.hassan@example.com', 'Ahmed Hassan', 'O+', 'regular', TRUE, FALSE, 'donor_view', 
     ST_GeogFromText('POINT(31.2400 30.0500)')),
    ('firebase_donor_2', 'fatima.ali@example.com', 'Fatima Ali', 'A+', 'regular', TRUE, FALSE, 'donor_view',
     ST_GeogFromText('POINT(31.2300 30.0400)')),
    ('firebase_donor_3', 'mohamed.saeed@example.com', 'Mohamed Saeed', 'B+', 'regular', TRUE, TRUE, 'recipient_view',
     ST_GeogFromText('POINT(31.3000 30.1000)'));

-- Insert sample hospital
INSERT INTO users (firebase_uid, email, name, account_type, hospital_name, hospital_code, hospital_verified, active_mode, location) VALUES
    ('firebase_hospital_1', 'admin@cairo.general.eg', 'Cairo General Hospital', 'hospital', 
     'Cairo General Hospital', 'CH', TRUE, 'hospital_view',
     ST_GeogFromText('POINT(31.2357 30.0444)'));

-- Insert sample badges
INSERT INTO badges 
(badge_code, badge_name, description, requirement_type, requirement_value, points_value)
VALUES
    ('first_donation', 'First Drop', 'Completed your first blood donation', 'donation_count', 1, 10),
    ('lifesaver_5', 'Lifesaver', 'Saved 5 lives through donation', 'donation_count', 5, 50),
    ('lifesaver_10', 'Super Lifesaver', 'Saved 10 lives through donation', 'donation_count', 10, 100),
    ('critical_responder', 'Critical Responder', 'Responded to a critical request within 30 minutes', 'critical_response', 1, 25),
    ('rare_hero', 'Rare Hero', 'Donated rare blood type (AB-, O-)', 'rare_blood', 1, 30),
    ('consistent_donor', 'Consistent Donor', 'Donated for 3 consecutive months', 'consecutive_months', 3, 75)
ON CONFLICT (badge_code) DO NOTHING;



-- VIEWS FOR COMMON QUERIES
-- Active requests with donor match counts
CREATE VIEW active_requests_summary AS
SELECT
    br.id,
    br.short_id,
    br.blood_type,
    br.urgency_level,
    br.hospital_name,
    br.units_needed,
    br.units_fulfilled,
    br.created_at,
    br.expires_at,
    COUNT(DISTINCT dr.donor_id) FILTER (WHERE dr.response_type = 'accepted') AS accepted_donors,
    COUNT(DISTINCT dr.donor_id) FILTER (WHERE dr.response_type = 'interested') AS interested_donors
FROM blood_requests br
LEFT JOIN donor_responses dr ON br.id = dr.request_id
WHERE br.status = 'active'
GROUP BY br.id;

-- Donor leaderboard
CREATE VIEW donor_leaderboard AS
SELECT
    u.id,
    u.name,
    u.blood_type,
    u.total_donations,
    u.reward_points,
    u.donor_status,
    COUNT(ub.badge_id) AS badges_earned,
    RANK() OVER (ORDER BY u.reward_points DESC) AS rank
FROM users u
LEFT JOIN user_badges ub ON u.id = ub.user_id
WHERE u.account_type = 'regular' AND u.is_donor = TRUE
GROUP BY u.id
ORDER BY u.reward_points DESC;

-- Hospital inventory status
CREATE VIEW hospital_inventory_status AS
SELECT
    u.name AS hospital_name,
    hi.blood_type,
    hi.units_available,
    hi.minimum_threshold,
    CASE
        WHEN hi.units_available < hi.minimum_threshold THEN 'LOW'
        WHEN hi.units_available < hi.minimum_threshold * 2 THEN 'MEDIUM'
        ELSE 'ADEQUATE'
    END AS stock_status,
    hi.last_updated
FROM hospital_inventory hi
JOIN users u ON hi.hospital_id = u.id
WHERE u.account_type = 'hospital';





