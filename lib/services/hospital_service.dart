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
      int parseInt(dynamic v) {
        if (v == null) return 0;
        if (v is int) return v;
        if (v is double) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }
      return {
        'pending': parseInt(row['pending']),
        'today': parseInt(row['today']),
        'fulfilled': parseInt(row['fulfilled']),
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

  // ── Inventory Management ──

  Future<Map<String, dynamic>?> addInventoryUnits({
    required String hospitalId,
    required String bloodType,
    required int units,
    String? reason,
    String? expirationDate,
  }) async {
    try {
      return await _api.postJson('/api/v1/hospital/inventory/add', body: {
        'hospitalId': hospitalId,
        'bloodType': bloodType,
        'units': units,
        'reason': reason,
        'expirationDate': expirationDate,
      });
    } catch (e) {
      debugPrint('addInventoryUnits failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> removeInventoryUnits({
    required String hospitalId,
    required String bloodType,
    required int units,
    String? reason,
  }) async {
    try {
      return await _api.postJson('/api/v1/hospital/inventory/remove', body: {
        'hospitalId': hospitalId,
        'bloodType': bloodType,
        'units': units,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('removeInventoryUnits failed: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> setInventoryUnits({
    required String hospitalId,
    required String bloodType,
    required int units,
    String? reason,
  }) async {
    try {
      return await _api.postJson('/api/v1/hospital/inventory/set', body: {
        'hospitalId': hospitalId,
        'bloodType': bloodType,
        'units': units,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('setInventoryUnits failed: $e');
      return null;
    }
  }

  Future<bool> setInventoryThreshold({
    required String hospitalId,
    required String bloodType,
    required int threshold,
  }) async {
    try {
      await _api.postEmpty('/api/v1/hospital/inventory/threshold', body: {
        'hospitalId': hospitalId,
        'bloodType': bloodType,
        'threshold': threshold,
      });
      return true;
    } catch (e) {
      debugPrint('setInventoryThreshold failed: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getInventoryHistory(
    String hospitalId, {
    int limit = 50,
  }) async {
    try {
      return await _api.getJsonList(
        '/api/v1/hospital/inventory/history',
        query: {'hospitalId': hospitalId, 'limit': limit.toString()},
      );
    } catch (_) {
      return [];
    }
  }

  // ── Auto Low-Inventory ──

  Future<Map<String, dynamic>> triggerLowInventoryCheck() async {
    return await _api.postJson('/api/v1/hospital/low-inventory/check');
  }

  Future<List<Map<String, dynamic>>> getLowInventoryAlerts(String hospitalId) async {
    try {
      return await _api.getJsonList(
        '/api/v1/hospital/low-inventory/alerts',
        query: {'hospitalId': hospitalId},
      );
    } catch (_) {
      return [];
    }
  }

  Future<bool> resolveLowInventoryAlert({
    required String hospitalId,
    required String bloodType,
  }) async {
    try {
      await _api.postEmpty('/api/v1/hospital/low-inventory/resolve', body: {
        'hospitalId': hospitalId,
        'bloodType': bloodType,
      });
      return true;
    } catch (e) {
      debugPrint('resolveLowInventoryAlert failed: $e');
      return false;
    }
  }
}
