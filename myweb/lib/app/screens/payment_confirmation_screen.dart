import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../services/auth_service.dart';
import '../../services/payment_service.dart';
import '../../models/user_profile.dart';
import '../widgets/parallax_background.dart';
import 'home_screen.dart';

/// Pre-payment confirmation page.
/// Shows user category, fee amount, and a "Proceed to Payment" button.
/// This screen does NOT modify any global state — it only reads existing data.
class PaymentConfirmationScreen extends StatefulWidget {
  const PaymentConfirmationScreen({super.key});

  @override
  State<PaymentConfirmationScreen> createState() =>
      _PaymentConfirmationScreenState();
}

class _PaymentConfirmationScreenState extends State<PaymentConfirmationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  bool _loading = true;
  bool _processing = false;
  String? _error;
  UserProfile? _userProfile;

  // If role is already stored, lock it
  String _selectedRole = 'student';
  bool _roleLocked = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AuthService.getCurrentUserProfile();
      if (!mounted) return;

      if (profile != null) {
        setState(() {
          _userProfile = profile;
          if (profile.role.isNotEmpty) {
            _selectedRole = profile.role.toLowerCase();
            _roleLocked = true;
          }
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Unable to load user profile.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error loading profile: $e';
      });
    }
  }

  String get _feeAmount {
    return _selectedRole == 'student' ? '₹250' : '₹500';
  }

  String get _feeNumeric {
    return _selectedRole == 'student' ? '250.00' : '500.00';
  }

  String get _roleDisplay {
    return _selectedRole == 'student' ? 'Student' : 'Scholar (Faculty/Researcher)';
  }

  Future<void> _proceedToPayment() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      _showSnackBar('Not logged in.', isError: true);
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    try {
      final result = await PaymentService.createPayment(uid);

      if (!mounted) return;

      if (result['success'] == true) {
        final paymentUrl = result['paymentUrl'] as String;

        // Launch the Easebuzz payment page in the browser
        await launchUrlString(
          paymentUrl,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_self',
        );
      } else {
        _showSnackBar(result['error'] ?? 'Payment initiation failed.', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Payment error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

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
        appBar: AppBar(
          title: const Text('Payment Confirmation'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: ParallaxBackground(
          child: SafeArea(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: _loading
                          ? const Center(
                              child: CircularProgressIndicator(color: accentViolet),
                            )
                          : _error != null
                              ? _buildErrorState()
                              : _buildConfirmationContent(accentViolet, primaryIndigo),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            _error ?? 'An error occurred.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationContent(Color accentViolet, Color primaryIndigo) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Center(
            child: Text(
              'Confirm Payment',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Review the details below before proceeding.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white60),
            ),
          ),
          const SizedBox(height: 32),

          // User Info Card
          _buildGlassCard(
            children: [
              _buildInfoTile(Icons.person_rounded, 'Name', _userProfile?.name ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoTile(Icons.email_rounded, 'Email', _userProfile?.email ?? 'N/A'),
              const SizedBox(height: 12),
              _buildInfoTile(
                Icons.phone_rounded,
                'Phone',
                _userProfile?.phone ?? 'N/A',
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Category & Fee Card
          _buildGlassCard(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentViolet.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.school_rounded, color: accentViolet, size: 24),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'User Category',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Role selection
              if (_roleLocked) ...[
                // Locked — auto-selected from registration
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentViolet.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentViolet.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedRole == 'student'
                            ? Icons.school_rounded
                            : Icons.science_rounded,
                        color: accentViolet,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _roleDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Category set during registration',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.lock_outline, size: 18, color: Colors.white.withOpacity(0.4)),
                    ],
                  ),
                ),
              ] else ...[
                // Editable — allow selection
                _buildRoleOption(
                  'student',
                  'Student',
                  '₹250',
                  Icons.school_rounded,
                  accentViolet,
                ),
                const SizedBox(height: 12),
                _buildRoleOption(
                  'scholar',
                  'Scholar (Faculty/Researcher)',
                  '₹500',
                  Icons.science_rounded,
                  accentViolet,
                ),
              ],

              const SizedBox(height: 24),
              const Divider(color: Colors.white10),
              const SizedBox(height: 16),

              // Fee display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Conference Fee',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentViolet, primaryIndigo],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _feeAmount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Security notice
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.security_rounded, size: 20, color: Colors.blueAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your payment will be processed securely through Easebuzz payment gateway.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Proceed button
          SizedBox(
            height: 56,
            child: ElevatedButton(
              onPressed: _processing ? null : _proceedToPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentViolet,
                foregroundColor: Colors.white,
                shadowColor: accentViolet.withOpacity(0.5),
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _processing
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white70,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment_rounded, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Proceed to Payment · $_feeAmount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Cancel button
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildRoleOption(
    String roleValue,
    String label,
    String fee,
    IconData icon,
    Color accentColor,
  ) {
    final isSelected = _selectedRole == roleValue;
    return InkWell(
      onTap: () => setState(() => _selectedRole = roleValue),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withOpacity(0.12) : Colors.black.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor.withOpacity(0.5) : Colors.white.withOpacity(0.1),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? accentColor : Colors.white54),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 15,
                ),
              ),
            ),
            Text(
              fee,
              style: TextStyle(
                color: isSelected ? accentColor : Colors.white54,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.white30,
                  width: 2,
                ),
                color: isSelected ? accentColor : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: const Color(0xFF1E1B4B).withOpacity(0.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.white54),
        const SizedBox(width: 12),
        Text(
          '$label: ',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
