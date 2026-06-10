-- Fix timestamp columns to use WITH TIME ZONE
-- This prevents timezone interpretation mismatches between
-- PostgreSQL and the Node.js pg library

ALTER TABLE public.blood_requests
  ALTER COLUMN created_at TYPE timestamptz,
  ALTER COLUMN updated_at TYPE timestamptz,
  ALTER COLUMN expires_at TYPE timestamptz,
  ALTER COLUMN fulfilled_at TYPE timestamptz;
