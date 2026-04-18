import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiService extends ChangeNotifier {
  // Backend is currently running on port 5000 when you use `python app.py`.
  static const String defaultBaseUrl = 'http://192.168.0.3:5000';
  String baseUrl = defaultBaseUrl;

  void setBaseUrl(String url) {
    baseUrl = url;
    notifyListeners();
  }

  Future<Map<String, dynamic>?> detectViolation(File imageFile, {String? cameraLocation, String? vehicleNumber}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/api/detect'));
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      if (cameraLocation != null) {
        request.fields['camera_location'] = cameraLocation;
      }
      if (vehicleNumber != null && vehicleNumber.isNotEmpty) {
        request.fields['vehicle_number'] = normalizePlate(vehicleNumber);
      }
      var response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode == 200) {
        return jsonDecode(body) as Map<String, dynamic>;
      }
      return {
        'error': 'HTTP ${response.statusCode}',
        'body': body,
      };
    } catch (e) {
      debugPrint('Detect error: $e');
      return {'error': e.toString()};
    }
  }

  Future<List<dynamic>> getViolations({int limit = 50, int offset = 0, String? vehicleNumber}) async {
    try {
      var uri = Uri.parse('$baseUrl/api/violations').replace(
        queryParameters: {'limit': limit.toString(), 'offset': offset.toString()}
          ..addAll(vehicleNumber != null && vehicleNumber.isNotEmpty
              ? {'vehicle_number': normalizePlate(vehicleNumber)}
              : {}),
      );
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['violations'] as List<dynamic>? ?? [];
      }
    } catch (e) {
      debugPrint('Violations error: $e');
    }
    return [];
  }

  /// Normalize plate — same rules as backend [utils.plate_utils]: AP03 BR4545 or compact custom plates.
  static String normalizePlate(String plate) {
    var clean = plate.toUpperCase().replaceAll(RegExp(r'[\s\-\.]'), '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length >= 10 && RegExp(r'^[A-Z]{2}[0-9]{2}').hasMatch(clean)) {
      return '${clean.substring(0, 4)} ${clean.substring(4)}';
    }
    // Match Python: len >= 8 and district code (positions 2–3) are both digits
    if (clean.length >= 8 && clean.length >= 4) {
      final head = clean.substring(0, 4);
      if (RegExp(r'^[A-Z]{2}[0-9]{2}$').hasMatch(head)) {
        return '${clean.substring(0, 4)} ${clean.substring(4)}';
      }
    }
    return clean;
  }

  Future<bool> registerVehicle(String vehicleNumber, String ownerName, String phoneNumber, {String? address}) async {
    try {
      final normalized = normalizePlate(vehicleNumber);
      final response = await http.post(
        Uri.parse('$baseUrl/api/owner/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'vehicle_number': normalized,
          'owner_name': ownerName.trim(),
          'phone_number': phoneNumber.trim(),
          if (address != null && address.isNotEmpty) 'address': address.trim(),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Register vehicle error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> lookupOwner(String vehicleNumber) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/owner/lookup').replace(
          queryParameters: {'vehicle_number': normalizePlate(vehicleNumber)},
        ),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Lookup error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> getAnalyticsDaily({int days = 7}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/daily').replace(
          queryParameters: {'days': days.toString()},
        ),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
    return {'data': <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> getAnalyticsWeekly({int weeks = 4}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/weekly').replace(
          queryParameters: {'weeks': weeks.toString()},
        ),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
    return {'data': <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> getAnalyticsMonthly({int months = 6}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/analytics/monthly').replace(
          queryParameters: {'months': months.toString()},
        ),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
    return {'data': <Map<String, dynamic>>[]};
  }

  Future<Map<String, dynamic>> getSummary() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/analytics/summary'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Summary error: $e');
    }
    return {'total': 0, 'today': 0};
  }

  /// Returns (success, errorMessage). errorMessage is null when success.
  Future<({bool success, String? error})> checkHealthWithError() async {
    final urls = ['$baseUrl/api/health', '$baseUrl/health', baseUrl];
    String? lastError;
    for (final url in urls) {
      try {
        final uri = Uri.parse(url);
        debugPrint('[ApiService] Checking: $uri');
        final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw Exception('Connection timeout (5s)'),
        );
        debugPrint('[ApiService] Health response: ${response.statusCode} from $url');
        if (response.statusCode == 200) {
          return (success: true, error: null);
        }
        lastError = 'HTTP ${response.statusCode}';
      } catch (e) {
        debugPrint('[ApiService] Try $url failed: $e');
        lastError = e.toString().replaceFirst('Exception: ', '');
      }
    }
    return (success: false, error: lastError ?? 'Connection failed. Ensure backend is running (python run.py) and phone is on same WiFi.');
  }

  Future<bool> checkHealth() async {
    final result = await checkHealthWithError();
    return result.success;
  }
}
