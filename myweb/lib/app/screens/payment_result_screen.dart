import 'dart:ui';
import 'package:flutter/material.dart';

import '../widgets/parallax_background.dart';
import 'home_screen.dart';

/// Displays the payment result (success or failure) after Easebuzz callback.
/// This screen is reached via route '/payment-result' with query parameters:
///   - status: 'success' or 'failed'
///   - txnid: transaction ID
///   - amount: paid amount
///   - reason: failure reason (if failed)
class PaymentResultScreen extends StatelessWidget {
  final String status;
  final String? txnid;
  final String? amount;
  final String? reason;

  const PaymentResultScreen({
    super.key,
    required this.status,
    this.txnid,
    this.amount,
    this.reason,
  });

  bool get isSuccess => status == 'success';

  @override
  Widget build(BuildContext context) {
    const accentViolet = Color(0xFF7C4DFF);
    const primaryIndigo = Color(0xFF6200EA);

    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accentViolet,
        secondary: primaryIndigo,
        surface: Color(0xFF0F0E1C),
        error: Color(0xFFFF5252),
      ),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: ParallaxBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildResultCard(context, accentViolet, primaryIndigo),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    Color accentViolet,
    Color primaryIndigo,
  ) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: const Color(0xFF1E1B4B).withOpacity(0.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Icon
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isSuccess
                          ? [Colors.green.shade400, Colors.green.shade700]
                          : [Colors.red.shade400, Colors.red.shade700],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isSuccess ? Colors.green : Colors.red).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_rounded : Icons.close_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 28),

                // Title
                Text(
                  isSuccess ? 'Payment Successful!' : 'Payment Failed',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  isSuccess
                      ? 'Your conference registration fee has been paid successfully.'
                      : _getFailureMessage(),
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (isSuccess && txnid != null) ...[
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),

                  // Transaction details
                  _buildDetailRow('Transaction ID', txnid!),
                  if (amount != null) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Amount Paid', '₹$amount'),
                  ],
                ],

                const SizedBox(height: 32),

                // Action button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess ? Colors.green : accentViolet,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      isSuccess ? 'Go to Dashboard' : 'Try Again',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFailureMessage() {
    switch (reason) {
      case 'hash_mismatch':
        return 'Payment verification failed. If money was deducted, it will be refunded within 5-7 business days.';
      case 'server_error':
        return 'A server error occurred. Please try again or contact support.';
      case 'payment_failed':
        return 'The payment could not be completed. Please try again.';
      default:
        return 'Something went wrong. Please try again or contact the organizer.';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
