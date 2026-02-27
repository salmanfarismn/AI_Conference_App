import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// PaymentService handles all communication with the payment backend.
/// It NEVER generates hashes or exposes secrets — all security-critical
/// operations happen on the backend.
class PaymentService {
  // ─────────── Configuration ───────────
  // Auto-detect: localhost → local backend, otherwise → deployed Render backend
  static const String _prodBackendUrl = 'https://ai-conference-payment-backend.onrender.com/api';
  static const String _devBackendUrl = 'http://localhost:3001/api';

  static String get _baseUrl {
    final host = html.window.location.hostname ?? '';
    return (host == 'localhost' || host == '127.0.0.1')
        ? _devBackendUrl
        : _prodBackendUrl;
  }

  /// Exposed for debug logging only.
  static String get debugBaseUrl => _baseUrl;

  /// Initiate payment for a user.
  /// Returns a map with { success, paymentUrl, accessKey, txnid, amount, role }
  /// or { success: false, error: '...' }
  static Future<Map<String, dynamic>> createPayment(String uid) async {
    try {
      // Send the current frontend origin so the backend redirects correctly
      final frontendUrl = html.window.location.origin;

      final response = await http.post(
        Uri.parse('$_baseUrl/create-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'uid': uid, 'frontendUrl': frontendUrl}),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        // Check if payment is exempt (affiliation-based waiver)
        if (data['paymentRequired'] == false) {
          return {
            'success': true,
            'paymentRequired': false,
            'reason': data['reason'] ?? 'Fee Waiver Applied',
            'institution': data['institution'] ?? '',
          };
        }
        return {
          'success': true,
          'paymentRequired': true,
          'paymentUrl': data['paymentUrl'] as String,
          'accessKey': data['accessKey'] as String,
          'txnid': data['txnid'] as String,
          'amount': data['amount'] as String,
          'role': data['role'] as String,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to initiate payment.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Get the payment status for a user.
  /// Returns { success, hasApprovedPaper, paymentStatus, paymentAmount, paymentTxnId, paymentDate }
  static Future<Map<String, dynamic>> getPaymentStatus(String uid) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/payment-status/$uid'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return data;
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to fetch payment status.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  /// Initiate attendee registration payment.
  /// Does NOT require user login — attendees can register publicly.
  /// Returns a map with { success, paymentUrl, accessKey, txnid, amount }
  /// or { success: false, error: '...' }
  static Future<Map<String, dynamic>> createAttendeePayment({
    required String name,
    required String email,
    required String phone,
    String organization = '',
  }) async {
    try {
      final frontendUrl = html.window.location.origin;

      final response = await http.post(
        Uri.parse('$_baseUrl/create-attendee-payment'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'organization': organization,
          'frontendUrl': frontendUrl,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'paymentUrl': data['paymentUrl'] as String,
          'accessKey': data['accessKey'] as String,
          'txnid': data['txnid'] as String,
          'amount': data['amount'] as String,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to initiate attendee payment.',
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
