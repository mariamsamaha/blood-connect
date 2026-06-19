-- Drop orphaned create_appointment_slots function.
-- The function references a non-existent appointment_slots table
-- and no code in the application uses it.
DROP FUNCTION IF EXISTS public.create_appointment_slots(uuid, date, date, time without time zone, time without time zone, int);
