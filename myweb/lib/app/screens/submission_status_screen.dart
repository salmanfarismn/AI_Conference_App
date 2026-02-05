import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../models/submission.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';

class SubmissionStatusScreen extends StatelessWidget {
  const SubmissionStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder(
          future: AuthService.getCurrentUserProfile(),
          builder: (context, snapshot) {
            final name = snapshot.data?.name ?? 'My Submissions';
            return Text('${snapshot.connectionState == ConnectionState.done ? name : 'My Submissions'} - Submissions');
          },
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.userSubmissionsStream(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];
          final submissions = docs
              .map((d) => Submission.fromDoc(d.id, d.data()))
              .toList();
          if (submissions.isEmpty) {
            return const Center(
              child: Text('No submissions yet.\nSubmit from the home screen.'),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              final s = submissions[index];
              return _SubmissionCard(submission: s);
            },
          );
        },
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final Submission submission;

  const _SubmissionCard({required this.submission});

  @override
  State<_SubmissionCard> createState() => _SubmissionCardState();
}

class _SubmissionCardState extends State<_SubmissionCard> {
  bool _expanded = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'under_review':
        return Colors.blue;
      case 'revision_requested':
        return Colors.orange;
      case 'submitted':
        return Colors.teal;
      default:
        return Colors.orange;
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
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    sub.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(sub.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(sub.status),
                    style: TextStyle(
                      color: _statusColor(sub.status),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Authors section
            if (sub.authors.isNotEmpty) ...[
              _buildInfoRow(
                context,
                Icons.person,
                'Main Author',
                sub.mainAuthor?.name ?? '',
              ),
              if (sub.mainAuthor?.affiliation != null)
                Padding(
                  padding: const EdgeInsets.only(left: 32, top: 2),
                  child: Text(
                    sub.mainAuthor!.affiliation,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
                ),
              if (sub.coAuthors.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoRow(
                  context,
                  Icons.people,
                  'Co-Authors',
                  sub.coAuthors.map((a) => a.name).join(', '),
                ),
              ],
            ] else if (sub.author != null && sub.author!.isNotEmpty) ...[
              _buildInfoRow(context, Icons.person, 'Author', sub.author!),
            ],

            const SizedBox(height: 8),

            // Reference and type
            _buildInfoRow(context, Icons.tag, 'Reference', sub.referenceNumber),
            const SizedBox(height: 4),
            _buildInfoRow(
              context,
              Icons.description,
              'Type',
              sub.submissionType == 'abstract' ? 'Abstract' : 'Full Paper',
            ),

            // Submission date
            if (sub.createdAt != null) ...[
              const SizedBox(height: 4),
              _buildInfoRow(
                context,
                Icons.calendar_today,
                'Submitted',
                DateFormat.yMMMd().add_Hm().format(sub.createdAt!),
              ),
            ],

            // Review comments section
            if (sub.reviewComments != null && sub.reviewComments!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.comment, size: 18, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Review Comments',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.amber.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sub.reviewComments!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if (sub.reviewedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Reviewed on ${DateFormat.yMMMd().format(sub.reviewedAt!)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Download paper button
            if (sub.pdfUrl != null && sub.pdfUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await launchUrlString(sub.pdfUrl!, webOnlyWindowName: '_blank');
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Paper'),
              ),
            ],

            // Document preview (for abstracts with extracted text)
            if ((sub.extractedText?.isNotEmpty ?? false)) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? 'Hide document' : 'View document'),
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      sub.extractedText ?? '',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ],
          ],
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
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
