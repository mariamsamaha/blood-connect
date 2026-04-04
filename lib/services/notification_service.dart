import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';

class NotificationService {
  final DatabaseService _db;

  NotificationService(this._db);

  /// Push to donors matching blood type + proximity (MVP).
  Future<void> sendNewRequestNotifications(BloodRequest request) async {
    final backendUrl = dotenv.env['NOTIFICATION_BACKEND_URL'];
    if (backendUrl == null || backendUrl.isEmpty) return;

    try {
      final donorTypes = donorBloodTypesCompatibleWith(request.bloodType);
      if (donorTypes.isEmpty) return;

      final donors = await _db.query('''
        SELECT DISTINCT u.fcm_token
        FROM users u
        WHERE u.fcm_token IS NOT NULL
          AND u.account_type = 'regular'
          AND u.is_donor = TRUE
          AND u.donor_status = 'available'
          AND u.is_active = TRUE
          AND u.notification_enabled = TRUE
          AND u.location IS NOT NULL
          AND u.blood_type = ANY(string_to_array(@typesCsv, ',')::varchar[])
          AND ST_DWithin(
            u.location,
            ST_SetSRID(ST_MakePoint(@hospitalLng::float8, @hospitalLat::float8), 4326)::geography,
            (GREATEST(COALESCE(u.notification_radius_km, 50), 80) * 1000)::double precision
          )
      ''', params: {
        'typesCsv': donorTypes.join(','),
        'hospitalLng': request.hospitalLng,
        'hospitalLat': request.hospitalLat,
      });

      if (donors.isEmpty) return;

      final tokens = donors
          .map((row) => row['fcm_token'] as String?)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isEmpty) return;

      final body = <String, dynamic>{
        'request': {
          'id': request.id,
          'short_id': request.shortId,
          'blood_type': request.bloodType,
          'units_needed': request.unitsNeeded,
          'hospital_name': request.hospitalName,
        },
        'tokens': tokens,
      };

      await http.post(
        Uri.parse(backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }
}
