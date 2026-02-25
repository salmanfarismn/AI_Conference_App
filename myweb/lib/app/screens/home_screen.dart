import 'dart:typed_data';
import 'dart:ui';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import '../../models/app_settings.dart';
import '../../models/user_profile.dart';
import '../widgets/parallax_background.dart';
import 'welcome_screen.dart';
import 'submission_status_screen.dart';
import 'submit_paper_screen.dart';
import 'full_paper_submission_screen.dart';
import 'payment_confirmation_screen.dart';
import 'manual_payment_screen.dart';
import '../widgets/glass_navbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
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
                  behavior: ScrollConfiguration.of(context)
                      .copyWith(scrollbars: false),
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
                              final settings = snapshot.hasData &&
                                      snapshot.data?.data() != null
                                  ? AppSettings.fromMap(snapshot.data!.data())
                                  : AppSettings();

                              return ListView(
                                physics: const BouncingScrollPhysics(),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
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
                                    onTap: () =>
                                        _navigateToSubmit(context, 'abstract'),
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
                                    onTap: () =>
                                        _navigateToSubmit(context, 'fullpaper'),
                                    accentColor: primaryIndigo,
                                  ),
                                  const SizedBox(height: 16),
                                  StreamBuilder<
                                      DocumentSnapshot<Map<String, dynamic>>>(
                                    stream: FirestoreService.userProfileStream(
                                        AuthService.currentUser?.uid ?? ''),
                                    builder: (context, profileSnapshot) {
                                      final userData = profileSnapshot.hasData
                                          ? profileSnapshot.data?.data()
                                          : null;
                                      final paymentStatus =
                                          userData?['paymentStatus']
                                                  as String? ??
                                              'none';

                                      String cardTitle =
                                          'Upload Receipt & ID Card';
                                      String cardSubtitle =
                                          'Submit your bank transfer proof and ID card for manual verification.';
                                      IconData cardIcon =
                                          Icons.upload_file_rounded;
                                      Color cardColor = const Color(0xFF00B0FF);
                                      VoidCallback? cardTap;
                                      bool cardOpen = true;

                                      if (paymentStatus == 'verified') {
                                        cardTitle = 'Verified Successfully';
                                        cardSubtitle =
                                            'Your payment and ID have been verified. Thank you!';
                                        cardIcon = Icons.check_circle_rounded;
                                        cardColor = Colors.green;
                                        cardOpen = false; // Disable tapping
                                      } else if (paymentStatus == 'pending') {
                                        cardTitle = 'Verification Pending';
                                        cardSubtitle =
                                            'Your proof is currently under review by the administrator.';
                                        cardIcon = Icons.hourglass_top_rounded;
                                        cardColor = Colors.orange;
                                        cardTap = () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ManualPaymentPendingScreen(),
                                            ),
                                          );
                                        };
                                      } else if (paymentStatus == 'rejected') {
                                        cardTitle = 'Re-upload Proof';
                                        cardSubtitle =
                                            'Previous submission was rejected. Please upload correct files.';
                                        cardIcon = Icons.error_outline_rounded;
                                        cardColor = Colors.redAccent;
                                        cardTap = () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ManualPaymentScreen(),
                                            ),
                                          );
                                        };
                                      } else {
                                        // 'none'
                                        cardTap = () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const ManualPaymentScreen(),
                                            ),
                                          );
                                        };
                                      }

                                      return Column(
                                        children: [
                                          _buildGlassActionCard(
                                            title: cardTitle,
                                            subtitle: cardSubtitle,
                                            icon: cardIcon,
                                            open: cardOpen,
                                            onTap: cardTap ?? () {},
                                            accentColor: cardColor,
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      );
                                    },
                                  ),

                                  // ─── Payment Section ───
                                  _buildPaymentSection(accentViolet),

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
                                    subtitle:
                                        'View status of your submitted papers.',
                                    icon: Icons.list_alt_rounded,
                                    open: true,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const SubmissionStatusScreen(),
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
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: Colors.white.withOpacity(0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.info_outline_rounded,
                                          size: 14, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          'Submit your abstract or full paper below.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color:
                                                Colors.white.withOpacity(0.8),
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
    if (uid == null) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: PaymentService.getPaymentStatus(uid),
      builder: (context, snapshot) {
        // Debug logging
        debugPrint('[PAYMENT] Connection state: ${snapshot.connectionState}');
        debugPrint('[PAYMENT] Has data: ${snapshot.hasData}');
        debugPrint('[PAYMENT] Has error: ${snapshot.hasError}');
        if (snapshot.hasError) {
          debugPrint('[PAYMENT] Error: ${snapshot.error}');
        }
        if (snapshot.hasData) {
          debugPrint('[PAYMENT] Data: ${snapshot.data}');
        }

        // While loading, show nothing to avoid layout jumps
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        if (data['success'] != true) {
          debugPrint('[PAYMENT] API returned success=false: ${data['error']}');
          return const SizedBox.shrink();
        }

        final hasApprovedPaper = data['hasApprovedPaper'] == true;
        final paymentStatus = data['paymentStatus'] as String?;
        debugPrint(
            '[PAYMENT] hasApprovedPaper=$hasApprovedPaper, paymentStatus=$paymentStatus');

        // Only show section if user has an approved full paper
        if (!hasApprovedPaper) return const SizedBox.shrink();

        final isPaid = paymentStatus == 'paid' || paymentStatus == 'verified';
        final isPending = paymentStatus == 'pending';
        final isRejected = paymentStatus == 'rejected';

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
                subtitle:
                    'Conference fee paid successfully. TXN: ${data['paymentTxnId'] ?? 'N/A'}',
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
                    final backendBase = (host == 'localhost' ||
                            host == '127.0.0.1')
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
                    final backendBase = (host == 'localhost' ||
                            host == '127.0.0.1')
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
            ] else if (isPending) ...[
              _buildGlassActionCard(
                title: 'Verification Pending',
                subtitle:
                    'Your manual payment proof is being reviewed by administrator.',
                icon: Icons.hourglass_top_rounded,
                open: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualPaymentPendingScreen(),
                    ),
                  );
                },
                accentColor: Colors.orange,
              ),
            ] else if (isRejected) ...[
              _buildGlassActionCard(
                title: 'Payment Rejected',
                subtitle:
                    'Reason: ${data['paymentRejectionReason'] ?? "Invalid proof"}. Click here to re-upload.',
                icon: Icons.error_outline_rounded,
                open: true,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ManualPaymentScreen(),
                    ),
                  );
                },
                accentColor: Colors.redAccent,
              ),
            ] else ...[
              _buildGlassActionCard(
                title: 'Pay Conference Fee (Online)',
                subtitle:
                    'Pay securely using credit/debit card, UPI, or Netbanking.',
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
              const SizedBox(height: 12),
              _buildGlassActionCard(
                title: 'Manual Bank Transfer',
                subtitle: 'Download bank details and payment template.',
                icon: Icons.account_balance_rounded,
                open: true,
                onTap: () async {
                  final profile = await AuthService.getCurrentUserProfile();
                  String selectedRole =
                      profile?.role.toLowerCase() ?? 'scholar';
                  String feeAmount =
                      selectedRole == 'student' ? '₹250' : '₹500';
                  String roleDisplay = selectedRole == 'student'
                      ? 'Student'
                      : 'Scholar (Faculty/Researcher)';
                  _downloadManualTemplate(profile, feeAmount, roleDisplay);
                },
                accentColor: Colors.blueAccent,
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
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

  Future<void> _downloadManualTemplate(
      UserProfile? userProfile, String feeAmount, String roleDisplay) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(40),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, text: 'MANUAL PAYMENT RECEIPT TEMPLATE'),
              pw.SizedBox(height: 20),
              pw.Text(
                  'Conference: International Conference on AI & Computing 2026'),
              pw.SizedBox(height: 20),
              pw.Text('USER DETAILS:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Name: ${userProfile?.name ?? "N/A"}'),
              pw.Text('Email: ${userProfile?.email ?? "N/A"}'),
              pw.Text('Category: $roleDisplay'),
              pw.SizedBox(height: 20),
              pw.Text('PAYMENT DETAILS:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Amount to Pay: $feeAmount'),
              pw.SizedBox(height: 10),
              pw.Text('BANK ACCOUNT DETAILS (TRANSFER TO):',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Bank Name: ABC International Bank'),
              pw.Text('Account Name: AI Conference Organizing Committee'),
              pw.Text('Account Number: 987654321012'),
              pw.Text('IFSC Code: ABCI0001234'),
              pw.Text('Branch: Main City Branch'),
              pw.SizedBox(height: 30),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text('INSTRUCTIONS:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(
                  '1. Transfer the exact amount mentioned above to the bank account.'),
              pw.Text('2. Keep the transaction receipt/screenshot.'),
              pw.Text('3. Ensure your ID card (Student/Researcher) is ready.'),
              pw.Text(
                  '4. Upload both the receipt and your ID card in the manual verification section of the app.'),
              pw.SizedBox(height: 40),
              pw.Text(
                  'Generated on: ${DateFormat.yMMMd().add_Hm().format(DateTime.now())}'),
            ],
          ),
        ),
      ),
    );

    final bytes = await pdf.save();
    await FileSaver.instance.saveFile(
      'Payment_Receipt_Template.pdf',
      Uint8List.fromList(bytes),
      "pdf",
      mimeType: MimeType.PDF,
    );
  }
}
