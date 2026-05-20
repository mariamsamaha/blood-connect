import 'package:bloodconnect/models/blood_request.dart';
import 'package:bloodconnect/models/hospital_request_match.dart';
import 'package:bloodconnect/services/api_client.dart';
import 'package:flutter/foundation.dart';

class HospitalService {
  final ApiClient _api;

  HospitalService(this._api);

  static String normalizeFourDigitCode(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    final tail = digits.length > 4
        ? digits.substring(digits.length - 4)
        : digits;
    return tail.padLeft(4, '0');
  }

  Future<List<HospitalRequestMatch>> searchByDisplayCode({
    required String hospitalUserId,
    required String fourDigitInput,
  }) async {
    final code = normalizeFourDigitCode(fourDigitInput);
    if (code.length != 4) return [];

    final result = await _api.getJsonList(
      '/api/v1/hospital/search',
      query: {'hospitalUserId': hospitalUserId, 'code': code},
    );

    return result.map((item) {
      final reqMap = Map<String, dynamic>.from(item['request'] as Map);
      final donorName = item['donorName']?.toString();
      final donorPhone = item['donorPhone']?.toString();
      reqMap.remove('donor_name');
      reqMap.remove('donor_phone');
      return HospitalRequestMatch(
        request: BloodRequest.fromJson(reqMap),
        donorName: (donorName != null && donorName.isNotEmpty) ? donorName : null,
        donorPhone:
            (donorPhone != null && donorPhone.isNotEmpty) ? donorPhone : null,
      );
    }).toList();
  }

  Future<String?> verifyDonation({
    required String hospitalUserId,
    required String requestId,
    String? staffName,
  }) async {
    final result = await _api.postJson(
      '/api/v1/hospital/verify',
      body: {
        'hospitalUserId': hospitalUserId,
        'requestId': requestId,
        'staffName': staffName,
      },
    );
    final err = result['error'];
    if (err == null) return null;
    return err.toString();
  }

  Future<List<Map<String, dynamic>>> getRecentAuditForRequest(
    String requestId,
  ) async {
    try {
      return await _api.getJsonList('/api/v1/hospital/requests/$requestId/audit');
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getInventory(String hospitalId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/hospital/inventory',
        query: {'hospitalId': hospitalId},
      );
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, int>> getHospitalStats(String hospitalId) async {
    try {
      final row = await _api.getJson(
        '/api/v1/hospital/stats',
        query: {'hospitalId': hospitalId},
      );
      if (row == null) return {'pending': 0, 'today': 0, 'fulfilled': 0};
      return {
        'pending': (row['pending'] as int?) ?? 0,
        'today': (row['today'] as int?) ?? 0,
        'fulfilled': (row['fulfilled'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('getHospitalStats failed: $e');
      return {'pending': 0, 'today': 0, 'fulfilled': 0};
    }
  }

  Future<List<Map<String, dynamic>>> getPendingRequests(String hospitalId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/hospital/pending',
        query: {'hospitalId': hospitalId},
      );
    } catch (e) {
      debugPrint('getPendingRequests failed: $e');
      return [];
    }
  }
}
