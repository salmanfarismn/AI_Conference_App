import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// VerificationService handles all communication with the backend
/// for document verification (ID card + payment receipt uploads).
///
/// This service is COMPLETELY ISOLATED from existing services.
class VerificationService {
  // ─────────── Configuration ───────────
  static const String _prodBackendUrl =
      'https://ai-conference-payment-backend.onrender.com/api';
  static const String _devBackendUrl = 'http://localhost:3001/api';

  static String get _baseUrl {
    final host = html.window.location.hostname ?? '';
    return (host == 'localhost' || host == '127.0.0.1')
        ? _devBackendUrl
        : _prodBackendUrl;
  }

  /// Resolve MIME MediaType from filename extension.
  static MediaType _mediaTypeFromFileName(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  /// Upload ID Card image.
  /// Returns { success, idCardUrl, verificationStatus } or { success: false, error }
  static Future<Map<String, dynamic>> uploadIdCard({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload-id-card');
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'idCard',
          fileBytes,
          filename: fileName,
          contentType: _mediaTypeFromFileName(fileName),
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to upload ID card.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Upload Payment Receipt image.
  /// Returns { success, paymentReceiptImageUrl, verificationStatus } or { success: false, error }
  static Future<Map<String, dynamic>> uploadPaymentReceipt({
    required String userId,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/upload-payment-receipt');
      final request = http.MultipartRequest('POST', uri);

      request.fields['userId'] = userId;
      request.files.add(
        http.MultipartFile.fromBytes(
          'paymentReceipt',
          fileBytes,
          filename: fileName,
          contentType: _mediaTypeFromFileName(fileName),
        ),
      );

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody) as Map<String, dynamic>;

      if (streamedResponse.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to upload payment receipt.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get verification status for a user.
  /// Returns { success, userId, idCardUrl, paymentReceiptImageUrl,
  ///           verificationStatus, verificationDate, verifiedBy }
  static Future<Map<String, dynamic>> getVerificationStatus(
      String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/verification-status/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch verification status.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Admin: Get list of users with verification documents.
  static Future<Map<String, dynamic>> getVerificationList(
      String adminId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/admin/verification-list?adminId=$adminId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch verification list.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Admin: Approve or reject a user's verification.
  static Future<Map<String, dynamic>> verifyUser({
    required String userId,
    required String action, // 'approved' or 'rejected'
    required String adminId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/verify-user'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'action': action,
          'adminId': adminId,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Verification action failed.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}
