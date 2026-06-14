-- Add date_of_birth to users table for age verification (must be 18+)
ALTER TABLE public.users
  ADD COLUMN date_of_birth DATE;

-- Ensure donors are at least 18 years old
ALTER TABLE public.users
  ADD CONSTRAINT users_min_age_check
  CHECK (
    account_type = 'hospital'
    OR date_of_birth IS NULL
    OR (AGE(date_of_birth) >= INTERVAL '18 years')
  );
