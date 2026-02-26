import 'dart:ui';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import '../../models/app_settings.dart';
import '../widgets/parallax_background.dart';
import 'welcome_screen.dart';
import 'submission_status_screen.dart';
import 'submit_paper_screen.dart';
import 'full_paper_submission_screen.dart';
import 'payment_confirmation_screen.dart';
import '../widgets/glass_navbar.dart';
import '../widgets/verification_documents_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ─── DEBUG: Log current user info ───
    final currentUser = AuthService.currentUser;
    debugPrint('=== [HOME_SCREEN] BUILD ===');
    debugPrint('[AUTH] currentUser is null: ${currentUser == null}');
    debugPrint('[AUTH] UID: ${currentUser?.uid}');
    debugPrint('[AUTH] Email: ${currentUser?.email}');
    debugPrint('[AUTH] isAnonymous: ${currentUser?.isAnonymous}');
    debugPrint('[AUTH] isEmailVerified: ${currentUser?.emailVerified}');
    debugPrint('=== [HOME_SCREEN] END AUTH INFO ===');
    // Custom Indigo/Violet Dark Theme
    const primaryIndigo = Color(0xFF6200EA);
    const accentViolet = Color(0xFF7C4DFF);
    
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accentViolet,
        secondary: primaryIndigo, 
        surface: Color(0xFF0F0E1C),
        error: Color(0xFFFF5252),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        bodyLarge: TextStyle(color: Colors.white),
        bodyMedium: TextStyle(color: Colors.white70),
      ),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: FutureBuilder(
            future: AuthService.getCurrentUserProfile(),
            builder: (context, snapshot) {
              return GlassNavbar(
                onLogout: _logout,
                userName: snapshot.data?.name ?? 'Conference Attendee',
              );
            },
          ),
        ),
        body: ParallaxBackground(
          child: Stack(
            children: [
              // Main Content
              SafeArea(
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 700),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: FadeTransition(
                        opacity: _animationController,
                        child: StreamBuilder(
                          stream: FirestoreService.appSettingsStream(),
                          builder: (context, snapshot) {
                            final settings = snapshot.hasData && snapshot.data?.data() != null
                                ? AppSettings.fromMap(snapshot.data!.data())
                                : AppSettings();
                                
                            return ListView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              children: [
                                _buildWelcome(),
                                const SizedBox(height: 32),
                                
                                Text(
                                  'SUBMISSIONS',
                                  style: TextStyle(
                                    color: accentViolet,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                _buildGlassActionCard(
                                  title: 'Abstract Submission',
                                  subtitle: settings.abstractSubmissionOpen 
                                      ? 'Submit your abstract for review.' 
                                      : 'Submission is currently closed.',
                                  icon: Icons.article_rounded,
                                  open: settings.abstractSubmissionOpen,
                                  onTap: () => _navigateToSubmit(context, 'abstract'),
                                  accentColor: accentViolet,
                                ),
                                const SizedBox(height: 16),
                                _buildGlassActionCard(
                                  title: 'Full Paper Submission',
                                  subtitle: settings.fullPaperSubmissionOpen 
                                      ? 'Submit your complete research paper.' 
                                      : 'Submission is currently closed.',
                                  icon: Icons.description_rounded,
                                  open: settings.fullPaperSubmissionOpen,
                                  onTap: () => _navigateToSubmit(context, 'fullpaper'),
                                  accentColor: primaryIndigo,
                                ),
                                
                                // ─── Payment Section ───
                                _buildPaymentSection(accentViolet),

                                // ─── Verification Documents Section ───
                                _buildVerificationSection(accentViolet),

                                const SizedBox(height: 32),
                                Text(
                                  'MY ACCOUNT',
                                  style: TextStyle(
                                    color: accentViolet,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                _buildGlassActionCard(
                                  title: 'My Submissions',
                                  subtitle: 'View status of your submitted papers.',
                                  icon: Icons.list_alt_rounded,
                                  open: true,
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const SubmissionStatusScreen(),
                                      ),
                                    );
                                  },
                                  accentColor: Colors.blueAccent,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    final isMobile = MediaQuery.of(context).size.width <= 640;
    
    return FutureBuilder(
      future: AuthService.getCurrentUserProfile(),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'User';
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            color: const Color(0xFF1E1B4B).withOpacity(0.4), // Dark Indigo tint
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Stack(
                children: [
                   // Decorative Background Effect
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      size: isMobile ? 120 : 180,
                      color: const Color(0xFF7C4DFF).withOpacity(0.05),
                    ),
                  ),
                  
                  // Main Content
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Accent Stick with Glow
                        Container(
                          width: 6,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFF6200EA),
                                Color(0xFF7C4DFF),
                                Color(0xFF00E5FF),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF).withOpacity(0.5),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        
                        // Text Content
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 20 : 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WELCOME BACK,',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2.0,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: isMobile ? 24 : 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline_rounded, size: 14, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Submit your abstract or full paper below.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.white.withOpacity(0.8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlassActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool open,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: const Color(0xFF1E1B4B).withOpacity(0.4), // Dark Indigo tint
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: open ? onTap : null,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: open 
                            ? accentColor.withOpacity(0.2) 
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        open ? icon : Icons.lock_outline_rounded,
                        color: open ? accentColor : Colors.grey,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: open ? Colors.white : Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: open ? Colors.white70 : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: open ? Colors.white54 : Colors.transparent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the payment section that appears between Full Paper Submission
  /// and My Account sections. Only visible when relevant.
  Widget _buildPaymentSection(Color accentViolet) {
    final uid = AuthService.currentUser?.uid;
    debugPrint('\n=== [PAYMENT_SECTION] START ===');
    debugPrint('[PAYMENT_SECTION] Current user UID: $uid');

    if (uid == null) {
      debugPrint('[PAYMENT_SECTION] ❌ UID is null — user not logged in. Payment section HIDDEN.');
      debugPrint('=== [PAYMENT_SECTION] END ===\n');
      return const SizedBox.shrink();
    }

    debugPrint('[PAYMENT_SECTION] ✅ UID found. Fetching payment status from API...');
    debugPrint('[PAYMENT_SECTION] API URL will be: ${PaymentService.debugBaseUrl}/payment-status/$uid');

    return FutureBuilder<Map<String, dynamic>>(
      future: PaymentService.getPaymentStatus(uid),
      builder: (context, snapshot) {
        // Debug logging
        debugPrint('\n--- [PAYMENT_SECTION] FutureBuilder rebuild ---');
        debugPrint('[PAYMENT] Connection state: ${snapshot.connectionState}');
        debugPrint('[PAYMENT] Has data: ${snapshot.hasData}');
        debugPrint('[PAYMENT] Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('[PAYMENT] ❌ Error: ${snapshot.error}');
          debugPrint('[PAYMENT] ❌ Stack trace: ${snapshot.stackTrace}');
        }
        if (snapshot.hasData) {
          debugPrint('[PAYMENT] ✅ Full API Response Data:');
          snapshot.data!.forEach((key, value) {
            debugPrint('[PAYMENT]   $key: $value (${value.runtimeType})');
          });
        }

        // While loading, show nothing to avoid layout jumps
        if (!snapshot.hasData) {
          debugPrint('[PAYMENT] ⏳ No data yet (loading or error). Payment section HIDDEN.');
          return const SizedBox.shrink();
        }

        final data = snapshot.data!;
        if (data['success'] != true) {
          debugPrint('[PAYMENT] ❌ API returned success=false. Payment button NOT rendered.');
          debugPrint('[PAYMENT] ❌ Error from API: ${data['error']}');
          debugPrint('[PAYMENT] ❌ Full response: $data');
          return const SizedBox.shrink();
        }

        final hasApprovedPaper = data['hasApprovedPaper'] == true;
        final paymentStatus = data['paymentStatus'] as String?;
        debugPrint('[PAYMENT] hasApprovedPaper=$hasApprovedPaper (raw value: ${data['hasApprovedPaper']}, type: ${data['hasApprovedPaper'].runtimeType})');
        debugPrint('[PAYMENT] paymentStatus=$paymentStatus (raw value: ${data['paymentStatus']}, type: ${data['paymentStatus']?.runtimeType})');

        // Only show section if user has an approved full paper
        if (!hasApprovedPaper) {
          debugPrint('[PAYMENT] ❌ hasApprovedPaper is FALSE. Payment button NOT rendered.');
          debugPrint('[PAYMENT] ❌ Reason: The user does not have an approved full paper.');
          return const SizedBox.shrink();
        }

        final isPaid = paymentStatus == 'paid';
        debugPrint('[PAYMENT] ✅ User HAS an approved paper. isPaid=$isPaid');
        if (isPaid) {
          debugPrint('[PAYMENT] 💚 Showing "Payment Completed" card + receipt options.');
        } else {
          debugPrint('[PAYMENT] 🟡 Showing "Pay Conference Fee" button. paymentStatus="$paymentStatus"');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'PAYMENT',
              style: TextStyle(
                color: accentViolet,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),

            if (isPaid) ...[
              _buildGlassActionCard(
                title: 'Payment Completed',
                subtitle: 'Conference fee paid successfully. TXN: ${data['paymentTxnId'] ?? 'N/A'}',
                icon: Icons.check_circle_rounded,
                open: false,
                onTap: () {},
                accentColor: Colors.green,
              ),
              const SizedBox(height: 12),
              _buildGlassActionCard(
                title: 'View Receipt',
                subtitle: 'Preview your payment receipt in browser.',
                icon: Icons.receipt_long_rounded,
                open: true,
                onTap: () {
                  final uid = AuthService.currentUser?.uid;
                  if (uid != null) {
                    final host = html.window.location.hostname ?? '';
                    final backendBase = (host == 'localhost' || host == '127.0.0.1')
                        ? 'http://localhost:3001/api'
                        : 'https://ai-conference-payment-backend.onrender.com/api';
                    html.window.open(
                      '$backendBase/receipt/$uid',
                      '_blank',
                    );
                  }
                },
                accentColor: const Color(0xFF7C4DFF),
              ),
              const SizedBox(height: 12),
              _buildGlassActionCard(
                title: 'Download Receipt',
                subtitle: 'Download receipt as PDF file.',
                icon: Icons.download_rounded,
                open: true,
                onTap: () {
                  final uid = AuthService.currentUser?.uid;
                  if (uid != null) {
                    final host = html.window.location.hostname ?? '';
                    final backendBase = (host == 'localhost' || host == '127.0.0.1')
                        ? 'http://localhost:3001/api'
                        : 'https://ai-conference-payment-backend.onrender.com/api';
                    html.window.open(
                      '$backendBase/receipt/download/$uid',
                      '_blank',
                    );
                  }
                },
                accentColor: Colors.teal,
              ),
            ] else
              _buildGlassActionCard(
                title: 'Pay Conference Fee',
                subtitle: 'Your full paper is approved. Complete payment to confirm registration.',
                icon: Icons.payment_rounded,
                open: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PaymentConfirmationScreen(),
                    ),
                  );
                },
                accentColor: Colors.amber,
              ),
          ],
        );
      },
    );
  }

  /// Builds the verification documents section.
  /// Only visible when the user has paid (paymentStatus == "paid").
  Widget _buildVerificationSection(Color accentViolet) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: PaymentService.getPaymentStatus(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        if (data['success'] != true) return const SizedBox.shrink();

        final paymentStatus = data['paymentStatus'] as String?;
        final isPaid = paymentStatus == 'paid';

        // Only show verification section after payment is completed
        if (!isPaid) return const SizedBox.shrink();

        return VerificationDocumentsSection(accentColor: accentViolet);
      },
    );
  }

  void _navigateToSubmit(BuildContext context, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => type == 'fullpaper'
            ? const FullPaperSubmissionScreen()
            : SubmitPaperScreen(submissionType: type),
      ),
    );
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
    );
  }
}
