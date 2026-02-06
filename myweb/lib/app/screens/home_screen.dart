import 'dart:ui';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/app_settings.dart';
import '../widgets/parallax_background.dart';
import 'welcome_screen.dart';
import 'submission_status_screen.dart';
import 'submit_paper_screen.dart';
import 'full_paper_submission_screen.dart';
import '../widgets/glass_navbar.dart';

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
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.5,
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcome() {
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
                      size: 180,
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
                            padding: const EdgeInsets.all(32),
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
                                  style: const TextStyle(
                                    fontSize: 32,
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
                                      Text(
                                        'Submit your abstract or full paper below.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white.withOpacity(0.8),
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
