import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:file_saver/file_saver.dart';

import '../models/submission.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'admin_login_screen.dart';
import 'admin_verification_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildSubmissionsList()),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 40),
                SizedBox(height: 12),
                Text('Conference Admin',
                    style: TextStyle(color: Colors.white, fontSize: 20)),
                Text('Admin Panel', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Users (later)'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.verified_user),
            title: const Text('Document Verification'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminVerificationScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              _showSettingsDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final isMobile = MediaQuery.of(context).size.width <= 640;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by reference, title, or author',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 12),
              isMobile
                  ? Column(
                      children: [
                        DropdownButtonFormField<String>(
                          value: _statusFilter,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Status')),
                            DropdownMenuItem(value: 'pending', child: Text('Pending')),
                            DropdownMenuItem(value: 'pending_review', child: Text('Revised')),
                            DropdownMenuItem(value: 'accepted_with_revision', child: Text('Revision Required')),
                            DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                            DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                          ],
                          onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _typeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Type',
                            border: OutlineInputBorder(),
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All Types')),
                            DropdownMenuItem(value: 'abstract', child: Text('Abstract')),
                            DropdownMenuItem(value: 'fullpaper', child: Text('Full Paper')),
                          ],
                          onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        // Status filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: const InputDecoration(
                              labelText: 'Status',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status')),
                              DropdownMenuItem(value: 'pending', child: Text('Pending')),
                              DropdownMenuItem(value: 'pending_review', child: Text('Revised')),
                              DropdownMenuItem(value: 'accepted_with_revision', child: Text('Revision Required')),
                              DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                              DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                            ],
                            onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Type filter
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _typeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Types')),
                              DropdownMenuItem(value: 'abstract', child: Text('Abstract')),
                              DropdownMenuItem(value: 'fullpaper', child: Text('Full Paper')),
                            ],
                            onChanged: (v) => setState(() => _typeFilter = v ?? 'all'),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmissionsList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.submissionsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final submissions = snapshot.data?.docs
                .map((d) => Submission.fromDoc(d.id, d.data()))
                .toList() ??
            [];

        final filtered = _applyFilters(submissions);

        if (filtered.isEmpty) {
          return const Center(child: Text('No submissions found'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _SubmissionCard(
              submission: filtered[index],
              onReview: () => _showReviewDialog(filtered[index]),
            );
          },
        );
      },
    );
  }

  List<Submission> _applyFilters(List<Submission> list) {
    final query = _searchController.text.toLowerCase();

    return list.where((s) {
      final matchesSearch = query.isEmpty ||
          s.referenceNumber.toLowerCase().contains(query) ||
          s.title.toLowerCase().contains(query) ||
          s.authorsDisplay.toLowerCase().contains(query);

      final matchesStatus = _statusFilter == 'all' || s.status == _statusFilter;
      final matchesType = _typeFilter == 'all' || s.submissionType == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  Future<void> _showSettingsDialog() async {
    // Get current settings
    final settings = await FirestoreService.getAppSettings();
    bool abstractOpen = settings.abstractSubmissionOpen;
    bool fullPaperOpen = settings.fullPaperSubmissionOpen;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submission Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Abstract Submission'),
                subtitle: Text(abstractOpen ? 'Open' : 'Closed'),
                value: abstractOpen,
                onChanged: (value) async {
                  setDialogState(() => abstractOpen = value);
                  await FirestoreService.setAbstractSubmissionOpen(value);
                },
              ),
              SwitchListTile(
                title: const Text('Full Paper Submission'),
                subtitle: Text(fullPaperOpen ? 'Open' : 'Closed'),
                value: fullPaperOpen,
                onChanged: (value) async {
                  setDialogState(() => fullPaperOpen = value);
                  await FirestoreService.setFullPaperSubmissionOpen(value);
                },
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  // Helper to map legacy statuses to valid options
  String _mapToValidStatus(String status) {
    const validStatuses = ['accepted', 'accepted_with_revision', 'rejected'];
    if (validStatuses.contains(status)) {
      return status;
    }
    // Map legacy statuses to a default valid status
    return 'accepted'; // Default for submissions that haven't been reviewed with new statuses
  }

  Future<void> _showReviewDialog(Submission submission) async {
    String selectedStatus = _mapToValidStatus(submission.status);
    final commentsController = TextEditingController(text: submission.reviewComments ?? '');
    bool showVersionHistory = submission.hasRevisions;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Expanded(child: Text('Review: ${submission.referenceNumber}')),
              // Show version badge for full papers
              if (submission.submissionType == 'fullpaper' && submission.currentVersion > 0)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: Text(
                    'v${submission.currentVersion}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo.shade700,
                    ),
                  ),
                ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width > 600 ? 500 : double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  
                  // Authors info
                  if (submission.authors.isNotEmpty) ...[
                    const Text('Authors:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ...submission.authors.map((a) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${a.isMainAuthor ? "• " : "  "}${a.name}${a.isMainAuthor ? " (Main)" : ""}',
                            style: TextStyle(
                              fontWeight: a.isMainAuthor ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          if (a.affiliation.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                a.affiliation,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ),
                          if (a.email != null && a.email!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 16),
                              child: Text(
                                a.email!,
                                style: TextStyle(fontSize: 12, color: Colors.blue.shade600),
                              ),
                            ),
                        ],
                      ),
                    )),
                    const SizedBox(height: 16),
                  ],

                  // ──────────── VERSION HISTORY (for revised papers) ────────────
                  if (submission.hasRevisions && submission.submissionType == 'fullpaper') ...[
                    InkWell(
                      onTap: () => setDialogState(() => showVersionHistory = !showVersionHistory),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 18, color: Colors.indigo.shade600),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Revision History (${submission.versions.length} previous versions)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.indigo.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Icon(
                              showVersionHistory ? Icons.expand_less : Icons.expand_more,
                              color: Colors.indigo.shade600,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (showVersionHistory) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ...submission.versions.asMap().entries.map((entry) {
                              final v = entry.value;
                              final isLast = entry.key == submission.versions.length - 1;
                              return _buildAdminVersionItem(v, isLast);
                            }),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],

                  // Current PDF link
                  if (submission.pdfUrl != null && submission.pdfUrl!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.picture_as_pdf, size: 18, color: Colors.red.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              submission.currentVersion > 1
                                  ? 'Current Version (v${submission.currentVersion}) PDF'
                                  : 'Submitted PDF',
                              style: TextStyle(fontSize: 13, color: Colors.blue.shade700),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await launchUrlString(submission.pdfUrl!, webOnlyWindowName: '_blank');
                            },
                            child: const Text('View', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Status dropdown
                  DropdownButtonFormField<String>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'accepted', child: Text('Accept')),
                      DropdownMenuItem(value: 'accepted_with_revision', child: Text('Request Revision')),
                      DropdownMenuItem(value: 'rejected', child: Text('Reject')),
                    ],
                    onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'pending'),
                  ),
                  const SizedBox(height: 16),

                  // Review comments
                  TextField(
                    controller: commentsController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Review Comments',
                      hintText: selectedStatus == 'accepted_with_revision'
                          ? 'Provide clear instructions for the author to address in their revision...'
                          : 'Add feedback for the author...',
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),

                  // Warning for accepted_with_revision
                  if (selectedStatus == 'accepted_with_revision') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'The author will be notified to submit a revised paper. '
                              'Please provide clear feedback about what needs to be changed.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade800,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await FirestoreService.updateSubmissionStatusWithReview(
                    docId: submission.id,
                    status: selectedStatus,
                    reviewedBy: AuthService.currentUser?.uid ?? '',
                    reviewComments: commentsController.text.trim(),
                  );
                  if (!mounted) return;
                  // Close dialog first, then show success snackbar using the parent context
                  Navigator.of(context).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Review saved successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Save Review'),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a single version item for the admin review dialog's version history
  Widget _buildAdminVersionItem(PaperVersion version, bool isLast) {
    Color statusColor;
    switch (version.status) {
      case 'accepted':
        statusColor = Colors.green;
        break;
      case 'accepted_with_revision':
        statusColor = Colors.orange;
        break;
      case 'rejected':
        statusColor = Colors.red;
        break;
      case 'pending_review':
        statusColor = Colors.blue;
        break;
      default:
        statusColor = Colors.grey;
    }

    String statusLabel;
    switch (version.status) {
      case 'accepted_with_revision':
        statusLabel = 'REVISION REQUESTED';
        break;
      case 'pending_review':
        statusLabel = 'REVISED';
        break;
      case 'pending':
        statusLabel = 'PENDING';
        break;
      default:
        statusLabel = version.status.toUpperCase();
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.2),
                    border: Border.all(color: statusColor, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Version ${version.version}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (version.submittedAt != null)
                    Text(
                      DateFormat.yMMMd().add_Hm().format(version.submittedAt!),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  if (version.adminComment.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Comment: ${version.adminComment}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.amber.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (version.fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    InkWell(
                      onTap: () async {
                        await launchUrlString(version.fileUrl, webOnlyWindowName: '_blank');
                      },
                      child: Text(
                        'View PDF →',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== SUBMISSION CARD =====================

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  final VoidCallback onReview;

  const _SubmissionCard({
    required this.submission,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 640;
    final statusColor = _statusColor(submission.status);
    final statusLabel = _statusLabel(submission.status);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onReview,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: PAPER INFO ---
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          submission.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ref: ${submission.referenceNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildTypeBadge(),
                ],
              ),
              const SizedBox(height: 12),
              
              // Authors with better grouping
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      submission.authorsDisplay,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // --- SECTION 2: SUBMISSION INFO ---
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Version Info
                  if (submission.submissionType == 'fullpaper')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree_outlined, size: 16, color: Colors.indigo.shade400),
                        const SizedBox(width: 6),
                        Text(
                          submission.currentVersion > 1 
                              ? 'Version: ${submission.currentVersion} (Revised)' 
                              : 'Version: 1 (Original)',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.indigo.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                  // Date
                  if (submission.createdAt != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat.yMMMd().format(submission.createdAt!),
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                ],
              ),

              // --- SECTION 3: ADMIN ACTIONS & COMMENTS ---
              if (submission.reviewComments != null && submission.reviewComments!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.comment_outlined, size: 14, color: Colors.amber.shade800),
                            const SizedBox(width: 6),
                            Text(
                              'Latest Admin Comment:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          submission.reviewComments!,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),
              
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onReview,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Evaluate Submission'),
                  ),
                  const Spacer(),
                  _buildQuickActions(context),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge() {
    final isFullPaper = submission.submissionType == 'fullpaper';
    final color = isFullPaper ? Colors.purple : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        isFullPaper ? 'Full Paper' : 'Abstract',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (submission.pdfUrl != null && submission.pdfUrl!.isNotEmpty)
          _QuickActionButton(
            icon: Icons.picture_as_pdf_outlined,
            tooltip: 'View PDF',
            onPressed: () => launchUrlString(submission.pdfUrl!, webOnlyWindowName: '_blank'),
            color: Colors.red.shade600,
          ),
        if (submission.extractedText != null && submission.extractedText!.isNotEmpty) ...[
          _QuickActionButton(
            icon: Icons.article_outlined,
            tooltip: 'View Text',
            onPressed: () async {
              final encoded = Uri.dataFromString(
                submission.extractedText!,
                mimeType: 'text/plain',
                encoding: utf8,
              ).toString();
              await launchUrlString(encoded, webOnlyWindowName: '_blank');
            },
            color: Colors.blue.shade600,
          ),
          _QuickActionButton(
            icon: Icons.download_outlined,
            tooltip: 'Export PDF',
            onPressed: () => _exportAsPdf(submission),
            color: Colors.green.shade600,
          ),
        ],
      ],
    );
  }

  Future<void> _exportAsPdf(Submission submission) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Reference: ${submission.referenceNumber}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text('Title: ${submission.title}', style: pw.TextStyle(fontSize: 12)),
            pw.Text('Authors: ${submission.authorsDisplay}', style: pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 10),
            pw.Text(submission.extractedText!, style: pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );

    final bytes = await pdf.save();
    await FileSaver.instance.saveFile(
      '${submission.referenceNumber}.pdf',
      Uint8List.fromList(bytes),
      "pdf",
      mimeType: MimeType.PDF,
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return 'ACCEPTED';
      case 'accepted_with_revision':
        return 'REVISION REQUIRED';
      case 'pending_review':
        return 'REVISED';
      case 'pending':
        return 'PENDING';
      case 'rejected':
        return 'REJECTED';
      default:
        return status.toUpperCase();
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'accepted_with_revision':
        return Colors.orange;
      case 'pending_review':
        return Colors.blue;
      case 'pending':
        return Colors.amber;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon, color: color, size: 22),
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.all(8),
      splashRadius: 24,
    );
  }
}
