UPDATE users
SET
  hospital_verified = TRUE,
  location = COALESCE(
    location,
    ST_SetSRID(ST_MakePoint(31.2357, 30.0444), 4326)::geography
  ),
  updated_at = NOW()
WHERE account_type = 'hospital';
