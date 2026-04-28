import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/services/database_service.dart';
import 'package:bloodconnect/utils/blood_compatibility.dart';

class NotificationService {
  final DatabaseService _db;

  NotificationService(this._db);

  /// Push to donors matching blood type + proximity.
  Future<void> sendNewRequestNotifications(BloodRequest request) async {
    final backendUrl = dotenv.env['NOTIFICATION_BACKEND_URL'] ?? '';
    if (backendUrl.isEmpty) {
      debugPrint('NotificationService: NOTIFICATION_BACKEND_URL not set — aborting.');
      return;
    }

    try {
      // Step 1: resolve compatible donor blood types
      final donorTypes = donorBloodTypesCompatibleWith(request.bloodType);
      if (donorTypes.isEmpty) {
        debugPrint('NotificationService: no compatible donor types for ${request.bloodType}');
        return;
      }
      debugPrint('NotificationService: compatible types for ${request.bloodType} → $donorTypes');

      // Step 2: query matching donors with an FCM token
      const hospitalPoint =
          'ST_SetSRID(ST_MakePoint(@hospitalLng::float8, @hospitalLat::float8), 4326)::geography';

      final donors = await _db.query(
        '''
        SELECT DISTINCT u.fcm_token
        FROM users u
        WHERE u.fcm_token IS NOT NULL
          AND u.account_type = 'regular'
          AND u.role = 'donor'
          AND u.donor_status = 'available'
          AND u.is_active = TRUE
          AND u.notification_enabled = TRUE
          AND u.location IS NOT NULL
          AND u.blood_type = ANY(string_to_array(@typesCsv, ',')::varchar[])
          AND ST_DWithin(
            u.location,
            $hospitalPoint,
            (GREATEST(COALESCE(u.notification_radius_km, 50), 10) * 1000)::double precision
          )
        ''',
        params: {
          'typesCsv': donorTypes.join(','),
          'hospitalLng': request.hospitalLng,
          'hospitalLat': request.hospitalLat,
        },
      );

      debugPrint('NotificationService: found ${donors.length} eligible donor(s)');

      if (donors.isEmpty) {
        debugPrint('NotificationService: no donors matched — check donor_status, is_donor, '
            'notification_enabled, location, and blood_type columns in the DB.');
        return;
      }

      // Step 3: extract non-empty tokens
      final tokens = donors
          .map((row) => row['fcm_token'] as String?)
          .whereType<String>()
          .where((t) => t.isNotEmpty)
          .toList();

      debugPrint('NotificationService: ${tokens.length} FCM token(s) to notify');

      if (tokens.isEmpty) return;

      // Step 4: POST to notification backend
      final payload = <String, dynamic>{
        'request': {
          'id': request.id,
          'short_id': request.shortId,
          'blood_type': request.bloodType,
          'units_needed': request.unitsNeeded,
          'hospital_name': request.hospitalName,
        },
        'tokens': tokens,
      };

      debugPrint('NotificationService: calling $backendUrl/sendNewRequest');

      final response = await http
          .post(
        Uri.parse('$backendUrl/sendNewRequest'),
        headers: {
          'Content-Type': 'application/json',
          'x-internal-secret': dotenv.env['NOTIFICATION_BACKEND_SECRET'] ?? '',
        },
        body: jsonEncode(payload),
      )
          .timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('NotificationService: HTTP timeout after 15 s');
          throw TimeoutException('Notification backend timeout');
        },
      );

      // Step 5: log result
      if (response.statusCode == 200) {
        debugPrint('NotificationService: backend responded 200 — ${response.body}');
        
        final body = jsonDecode(response.body);
        final staleTokens = body['stale_tokens'] as List<dynamic>?;
        if (staleTokens != null && staleTokens.isNotEmpty) {
          final tokenList = staleTokens.cast<String>();
          await _db.query(
            'UPDATE users SET fcm_token = NULL WHERE fcm_token = ANY(@tokens::text[])',
            params: {'tokens': tokenList},
          );
          debugPrint('NotificationService: purged ${staleTokens.length} stale FCM token(s)');
        }
      } else {
        debugPrint('NotificationService: backend responded ${response.statusCode} — ${response.body}');
      }

      developer.log('Notification result: ${response.statusCode} ${response.body}');
    } on TimeoutException catch (e) {
      debugPrint('NotificationService: timed out — $e');
      developer.log('Notification timeout: $e');
    } catch (e, stack) {
      debugPrint('NotificationService: unexpected error — $e');
      developer.log('Notification error: $e', error: e, stackTrace: stack);
    }
  }
}