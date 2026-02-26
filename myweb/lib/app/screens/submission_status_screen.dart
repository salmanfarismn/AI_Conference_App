import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/submission.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../widgets/parallax_background.dart';
import 'paper_revision_screen.dart';

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
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
  bool _showVersionHistory = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'under_review':
        return Colors.blueAccent;
      case 'revision_requested':
      case 'accepted_with_revision':
        return Colors.orangeAccent;
      case 'pending_review':
        return Colors.cyanAccent;
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
      case 'accepted_with_revision':
        return 'REVISION REQUIRED';
      case 'pending_review':
        return 'PENDING REVIEW';
      default:
        return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.submission;
    final statusColor = _statusColor(sub.status);
    final needsRevision = sub.needsRevision;
    final isPendingReview = sub.isPendingReview;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: needsRevision
              ? Colors.orange.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
          width: needsRevision ? 1.5 : 1,
        ),
        color: const Color(0xFF1E1B4B).withOpacity(0.4), // Dark Indigo tint
        boxShadow: [
          BoxShadow(
            color: needsRevision
                ? Colors.orange.withOpacity(0.05)
                : Colors.black.withOpacity(0.2),
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
                // Header: Title + Status badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          // Show version number for full papers with revisions
                          if (sub.submissionType == 'fullpaper' && sub.currentVersion > 1) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Version ${sub.currentVersion}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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

                // ────────── REVISION REQUIRED BANNER ──────────
                if (needsRevision) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange.withOpacity(0.15),
                          Colors.deepOrange.withOpacity(0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.orange.withOpacity(0.2),
                              ),
                              child: const Icon(Icons.edit_note_rounded, size: 20, color: Colors.orangeAccent),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Revision Required',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orangeAccent,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Your paper has been reviewed and requires revisions. '
                          'Please upload a revised version addressing the feedback.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // ────────── PENDING REVIEW NOTICE ──────────
                if (isPendingReview && sub.submissionType == 'fullpaper') ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.cyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.cyan.withOpacity(0.2),
                          ),
                          child: const Icon(Icons.hourglass_top_rounded, size: 20, color: Colors.cyanAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Revised Paper Under Review',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version ${sub.currentVersion} has been submitted and is awaiting admin review.',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

                // ────────── VERSION HISTORY (expandable) ──────────
                if (sub.hasRevisions && sub.submissionType == 'fullpaper') ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setState(() => _showVersionHistory = !_showVersionHistory),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 16,
                            color: Colors.white.withOpacity(0.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${sub.versions.length} previous version${sub.versions.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              color: const Color(0xFF7C4DFF).withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _showVersionHistory ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                            size: 18,
                            color: const Color(0xFF7C4DFF).withOpacity(0.8),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_showVersionHistory) ...[
                    const SizedBox(height: 12),
                    _buildVersionTimeline(sub),
                  ],
                ],

                // Actions
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // ────────── UPLOAD REVISED PAPER BUTTON ──────────
                    if (needsRevision)
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PaperRevisionScreen(submission: sub),
                            ),
                          );
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: const Text('Upload Revised Paper'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.withOpacity(0.9),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          elevation: 4,
                          shadowColor: Colors.orange.withOpacity(0.3),
                        ),
                      ),

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

  /// Build version history timeline
  Widget _buildVersionTimeline(Submission sub) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...sub.versions.asMap().entries.map((entry) {
            final v = entry.value;
            final isLast = entry.key == sub.versions.length - 1;
            return _buildVersionItem(v, isLast);
          }),
        ],
      ),
    );
  }

  Widget _buildVersionItem(PaperVersion version, bool isLast) {
    final statusColor = _statusColor(version.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.3),
                    border: Border.all(color: statusColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'v${version.version}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(version.status),
                          style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  if (version.submittedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        DateFormat.yMMMd().add_Hm().format(version.submittedAt!),
                        style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
                      ),
                    ),
                  if (version.adminComment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        version.adminComment,
                        style: TextStyle(color: Colors.amber.withOpacity(0.7), fontSize: 11, fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (version.fileUrl.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: InkWell(
                        onTap: () async {
                          await launchUrlString(version.fileUrl, webOnlyWindowName: '_blank');
                        },
                        child: Text(
                          'View PDF →',
                          style: TextStyle(
                            color: const Color(0xFF7C4DFF).withOpacity(0.7),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
