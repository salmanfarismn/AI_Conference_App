import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../models/app_settings.dart';
import 'welcome_screen.dart';
import 'submission_status_screen.dart';
import 'submit_paper_screen.dart';
import 'full_paper_submission_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirestoreService.appSettingsStream(),
      builder: (context, snapshot) {
        final settings = snapshot.hasData && snapshot.data?.data() != null
            ? AppSettings.fromMap(snapshot.data!.data())
            : AppSettings();
        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder(
              future: AuthService.getCurrentUserProfile(),
              builder: (context, snapshot) {
                final name = snapshot.data?.name ?? 'Conference Submissions';
                return Text(snapshot.connectionState == ConnectionState.done && snapshot.hasData 
                  ? '${snapshot.data?.name} - Conference' 
                  : 'Conference Submissions');
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: _logout,
                tooltip: 'Logout',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWelcome(),
              const SizedBox(height: 24),
              _buildSubmissionCard(
                title: 'Abstract Submission',
                open: settings.abstractSubmissionOpen,
                onTap: () => _navigateToSubmit(context, 'abstract'),
              ),
              const SizedBox(height: 16),
              _buildSubmissionCard(
                title: 'Full Paper Submission',
                open: settings.fullPaperSubmissionOpen,
                onTap: () => _navigateToSubmit(context, 'fullpaper'),
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.list_alt),
                  title: const Text('My Submissions'),
                  subtitle: const Text('View status of your papers'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SubmissionStatusScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWelcome() {
    return FutureBuilder(
      future: AuthService.getCurrentUserProfile(),
      builder: (context, snapshot) {
        final name = snapshot.data?.name ?? 'User';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Welcome, $name',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Submit your abstract or full paper and track status here.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionCard({
    required String title,
    required bool open,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(
          open ? Icons.upload_file : Icons.block,
          color: open ? null : Colors.grey,
        ),
        title: Text(title),
        subtitle: Text(
          open ? 'Tap to submit' : 'Submission is currently closed by the admin.',
          style: TextStyle(
            color: open ? Colors.grey.shade600 : Colors.red.shade700,
          ),
        ),
        trailing: open ? const Icon(Icons.chevron_right) : null,
        onTap: open ? onTap : null,
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
