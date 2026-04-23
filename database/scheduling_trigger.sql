CREATE OR REPLACE FUNCTION update_slot_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' AND NEW.status = 'scheduled' THEN
        UPDATE appointment_slots 
        SET current_count = current_count + 1
        WHERE id = NEW.slot_id;
    END IF;
    
    IF OLD.status = 'scheduled' AND NEW.status = 'cancelled' THEN
        UPDATE appointment_slots 
        SET current_count = current_count - 1
        WHERE id = NEW.slot_id;
    END IF;
    
    IF OLD.status = 'scheduled' AND NEW.status = 'completed' THEN
        UPDATE appointment_slots 
        SET current_count = current_count - 1
        WHERE id = NEW.slot_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS sync_slot_count ON appointments;
CREATE TRIGGER sync_slot_count
AFTER INSERT OR UPDATE ON appointments
FOR EACH ROW
EXECUTE FUNCTION update_slot_count();