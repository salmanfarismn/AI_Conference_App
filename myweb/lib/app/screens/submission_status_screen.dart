import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/submission.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../widgets/parallax_background.dart';

class SubmissionStatusScreen extends StatefulWidget {
  const SubmissionStatusScreen({super.key});

  @override
  State<SubmissionStatusScreen> createState() => _SubmissionStatusScreenState();
}

class _SubmissionStatusScreenState extends State<SubmissionStatusScreen> with SingleTickerProviderStateMixin {
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
    final uid = AuthService.currentUser?.uid;
    
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

    if (uid == null) {
      return Theme(
        data: darkTheme,
        child: const Scaffold(
          body: Center(child: Text('Not logged in', style: TextStyle(color: Colors.white))),
        ),
      );
    }

    return Theme(
      data: darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: FutureBuilder(
            future: AuthService.getCurrentUserProfile(),
            builder: (context, snapshot) {
              final name = snapshot.data?.name ?? 'My Submissions';
              return Text(
                snapshot.connectionState == ConnectionState.done ? '$name - Submissions' : 'My Submissions',
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
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
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: FadeTransition(
                      opacity: _animationController,
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirestoreService.userSubmissionsStream(uid),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(color: accentViolet),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.redAccent),
                              ),
                            );
                          }
                          final docs = snapshot.data?.docs ?? [];
                          final submissions = docs
                              .map((d) => Submission.fromDoc(d.id, d.data()))
                              .toList();

                          if (submissions.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_rounded, size: 64, color: Colors.white.withOpacity(0.3)),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No submissions yet',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Submit from the home screen.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            itemCount: submissions.length,
                            itemBuilder: (context, index) {
                              final s = submissions[index];
                              return _GlassSubmissionCard(submission: s);
                            },
                          );
                        },
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
}

class _GlassSubmissionCard extends StatefulWidget {
  final Submission submission;

  const _GlassSubmissionCard({required this.submission});

  @override
  State<_GlassSubmissionCard> createState() => _GlassSubmissionCardState();
}

class _GlassSubmissionCardState extends State<_GlassSubmissionCard> {
  bool _expanded = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'under_review':
        return Colors.blueAccent;
      case 'revision_requested':
        return Colors.orangeAccent;
      case 'submitted':
        return const Color(0xFF7C4DFF); // Violet
      default:
        return Colors.amberAccent;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'under_review':
        return 'UNDER REVIEW';
      case 'revision_requested':
        return 'REVISION REQUESTED';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    final statusColor = _statusColor(sub.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: const Color(0xFF1E1B4B).withOpacity(0.4), // Dark Indigo tint
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
              children: [
                // Header: Title + Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sub.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor.withOpacity(0.5)),
                      ),
                      child: Text(
                        _statusLabel(sub.status),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // Details
                if (sub.authors.isNotEmpty) ...[
                  _buildInfoRow(
                    context,
                    Icons.person_rounded,
                    'Main Author',
                    sub.mainAuthor?.name ?? '',
                  ),
                  if (sub.mainAuthor?.affiliation != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 28, top: 4),
                      child: Text(
                        sub.mainAuthor!.affiliation,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                      ),
                    ),
                  if (sub.coAuthors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      context,
                      Icons.people_rounded,
                      'Co-Authors',
                      sub.coAuthors.map((a) => a.name).join(', '),
                    ),
                  ],
                ] else if (sub.author != null && sub.author!.isNotEmpty) ...[
                  _buildInfoRow(context, Icons.person_rounded, 'Author', sub.author!),
                ],

                const SizedBox(height: 12),
                
                _buildInfoRow(context, Icons.tag_rounded, 'Reference', sub.referenceNumber),
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  Icons.article_rounded,
                  'Type',
                  sub.submissionType == 'abstract' ? 'Abstract' : 'Full Paper',
                ),

                if (sub.createdAt != null) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    context,
                    Icons.calendar_today_rounded,
                    'Submitted',
                    DateFormat.yMMMd().add_Hm().format(sub.createdAt!),
                  ),
                ],

                // Review Comments
                if (sub.reviewComments != null && sub.reviewComments!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.comment_rounded, size: 16, color: Colors.amberAccent),
                            const SizedBox(width: 8),
                            const Text(
                              'Review Comments',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amberAccent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sub.reviewComments!,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (sub.reviewedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Reviewed on ${DateFormat.yMMMd().format(sub.reviewedAt!)}',
                              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                // Actions
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (sub.pdfUrl != null && sub.pdfUrl!.isNotEmpty)
                      OutlinedButton.icon(
                        onPressed: () async {
                          await launchUrlString(sub.pdfUrl!, webOnlyWindowName: '_blank');
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Download PDF'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF7C4DFF),
                          side: const BorderSide(color: Color(0xFF7C4DFF)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    
                    if ((sub.extractedText?.isNotEmpty ?? false))
                      TextButton.icon(
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        label: Text(_expanded ? 'Hide Document Text' : 'View Document Text'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                      ),
                  ],
                ),

                if (_expanded && (sub.extractedText?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Text(
                      sub.extractedText ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
