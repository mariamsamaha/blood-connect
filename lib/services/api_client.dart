import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:bloodconnect/config/app_config.dart';

/// HTTP client for the BloodConnect API BFF. Attaches Firebase ID token on each call.
class ApiClient {
  ApiClient({http.Client? httpClient, FirebaseAuth? auth})
      : _http = httpClient ?? http.Client(),
        _auth = auth ?? FirebaseAuth.instance;

  final http.Client _http;
  final FirebaseAuth _auth;

  String get _base => AppConfig.apiBaseUrl;

  Future<Map<String, String>> _headers() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in');
    }
    final token = await user.getIdToken(true);
    if (token == null || token.isEmpty) {
      throw Exception('Could not obtain Firebase ID token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>?> getJson(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final response = await _http.get(uri, headers: await _headers());
    return _decode(response);
  }

  Future<List<Map<String, dynamic>>> getJsonList(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse('$_base$path').replace(queryParameters: query);
    final response = await _http.get(uri, headers: await _headers());
    if (response.statusCode == 204) return [];
    final body = jsonDecode(response.body);
    if (body is List) {
      return body.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    _throwForStatus(response);
    return [];
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? body}) async {
    final response = await _http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    final decoded = _decode(response);
    return decoded ?? {};
  }

  Future<void> patchJson(String path, {Object? body}) async {
    final response = await _http.patch(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    _throwForStatus(response);
  }

  Future<void> postEmpty(String path, {Object? body}) async {
    final response = await _http.post(
      Uri.parse('$_base$path'),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    _throwForStatus(response);
  }

  Map<String, dynamic>? _decode(http.Response response) {
    if (response.statusCode == 204 || response.body.isEmpty) return null;
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final trimmed = response.body.trim();
      if (trimmed == 'null') return null;
      final body = jsonDecode(response.body);
      if (body == null) return null;
      if (body is Map) return Map<String, dynamic>.from(body);
      if (body is List) {
        debugPrint('ApiClient: expected object, got list for ${response.request?.url}');
        return null;
      }
    }
    _throwForStatus(response);
    return null;
  }

  void _throwForStatus(http.Response response) {
    String message = 'API error ${response.statusCode}';
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] != null) {
        message = '${body['error']}';
        final detail = body['detail'];
        final hint = body['hint'];
        if (detail != null) message = '$message: $detail';
        if (hint != null) message = '$message\n$hint';
      }
    } catch (_) {}
    throw Exception(message);
  }
}
