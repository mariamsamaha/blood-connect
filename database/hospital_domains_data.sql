-- Sample hospital domains for BloodConnect
-- This file populates the hospital_domains table with test data

-- Clear existing data
DELETE FROM hospital_domains;

-- Insert sample hospital domains
INSERT INTO hospital_domains (domain, hospital_name, contact_email, verified_at, active) VALUES
    ('cairo.general.eg', 'Cairo General Hospital', 'admin@cairo.general.eg', NOW()),
    ('ain.shams.hospital.eg', 'Ain Shams University Hospital', 'info@ain.shams.edu.eg', NOW()),
    ('dar.alfouad.eg', 'Dar Al Fouad Hospital', 'support@dar.alfouad.eg', NOW()),
    ('cleopatra.hospitals.com', 'Cleopatra Hospitals', 'admin@cleopatra.hospitals.com', NOW()),
    ('qasr.elainy.eg', 'Qasr El Ainy Hospital', 'support@qasr.edu.eg', NOW());
    ('ain.shams.hospital.eg', 'Ain Shams University Hospital', 'info@ain.shams.edu.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('dar.alfouad.eg', 'Dar Al Fouad Hospital', 'support@dar.alfouad.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('cleopatra.hospitals.com', 'Cleopatra Hospitals', 'admin@cleopatra.hospitals.com', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('qasr.elainy.eg', 'Qasr El Ainy Hospital', 'support@qasr.edu.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('ain.shams.hospital.eg', 'Ain Shams University Hospital', 'info@ain.shams.edu.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('dar.alfouad.eg', 'Dar Al Fouad Hospital', 'support@dar.alfouad.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('cleopatra.hospitals.com', 'Cleopatra Hospitals', 'admin@cleopatra.hospitals.com', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE),
    ('qasr.elainy.eg', 'Qasr El Ainy Hospital', 'support@qasr.edu.eg', NOW(), '550e8400-e29b-41d4-a716-99ac2be3128', TRUE);