import 'package:bloodconnect/services/database_service.dart';

class AppointmentService {
  final DatabaseService _db;

  AppointmentService(this._db);

  /// Get available slots for a hospital (or all if hospitalId is null)
  Future<List<Map<String, dynamic>>> getAvailableSlots(String? hospitalId) async {
    if (hospitalId != null) {
      return await _db.query('''
        SELECT 
          id, slot_date, slot_time, max_donors, current_count,
          (max_donors - current_count) as available_slots
        FROM appointment_slots
        WHERE hospital_id = @hospitalId::uuid
          AND slot_date >= CURRENT_DATE
          AND current_count < max_donors
        ORDER BY slot_date, slot_time
      ''', params: {'hospitalId': hospitalId});
    } else {
      return await _db.query('''
        SELECT 
          id, slot_date, slot_time, max_donors, current_count,
          (max_donors - current_count) as available_slots
        FROM appointment_slots
        WHERE slot_date >= CURRENT_DATE
          AND current_count < max_donors
        ORDER BY slot_date, slot_time
      ''');
    }
  }

  /// Get all slots for a hospital (for hospital to manage)
  Future<List<Map<String, dynamic>>> getHospitalSlots(String hospitalId) async {
    return await _db.query('''
      SELECT 
        id, slot_date, slot_time, max_donors, current_count,
        (max_donors - current_count) as available_slots
      FROM appointment_slots
      WHERE hospital_id = @hospitalId::uuid
        AND slot_date >= CURRENT_DATE
      ORDER BY slot_date, slot_time
    ''', params: {'hospitalId': hospitalId});
  }

  /// Book an appointment slot
  Future<void> bookSlot({
    required String slotId,
    required String donorId,
    required String bloodType,
    String? notes,
  }) async {
    await _db.query('''
      INSERT INTO appointments (donor_id, slot_id, blood_type, notes)
      SELECT @donorId::uuid, @slotId::uuid, @bloodType, @notes
      WHERE EXISTS (
        SELECT 1 FROM appointment_slots 
        WHERE id = @slotId::uuid AND current_count < max_donors
      )
    ''', params: {
      'slotId': slotId,
      'donorId': donorId,
      'bloodType': bloodType,
      'notes': notes,
    });
  }

  /// Get donor's appointments
  Future<List<Map<String, dynamic>>> getDonorAppointments(String donorId) async {
    return await _db.query('''
      SELECT 
        a.id, a.status, a.blood_type, a.notes, a.created_at,
        s.slot_date, s.slot_time,
        h.hospital_name
      FROM appointments a
      JOIN appointment_slots s ON s.id = a.slot_id
      JOIN users h ON h.id = s.hospital_id
      WHERE a.donor_id = @donorId::uuid
      ORDER BY s.slot_date, s.slot_time
    ''', params: {'donorId': donorId});
  }

  /// Cancel appointment
  Future<void> cancelAppointment({
    required String appointmentId,
    required String donorId,
  }) async {
    await _db.query('''
      UPDATE appointments 
      SET status = 'cancelled'
      WHERE id = @appointmentId::uuid 
        AND donor_id = @donorId::uuid 
        AND status = 'scheduled'
    ''', params: {
      'appointmentId': appointmentId,
      'donorId': donorId,
    });
  }

  /// Hospital creates slots
  Future<void> createSlots({
    required String hospitalId,
    required List<Map<String, dynamic>> slots,
  }) async {
    for (final slot in slots) {
      await _db.query('''
        INSERT INTO appointment_slots (hospital_id, slot_date, slot_time, max_donors)
        VALUES (@hospitalId::uuid, @slotDate, @slotTime, @maxDonors)
        ON CONFLICT (hospital_id, slot_date, slot_time) DO NOTHING
      ''', params: {
        'hospitalId': hospitalId,
        'slotDate': slot['slot_date'],
        'slotTime': slot['slot_time'],
        'maxDonors': slot['max_donors'] ?? 5,
      });
    }
  }
}