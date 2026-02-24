import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

/// PaymentService handles all communication with the payment backend.
/// It NEVER generates hashes or exposes secrets — all security-critical
/// operations happen on the backend.
class PaymentService {
  // ─────────── Configuration ───────────
  // Toggle this to your deployed backend URL in production.
  static const String _baseUrl = 'http://localhost:3001/api';

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
        return {
          'success': true,
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
}
