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

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'all';

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
            leading: const Icon(Icons.settings),
            title: const Text('Settings (later)'),
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by reference or title',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                  DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                  DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                ],
                onChanged: (v) => setState(() => _statusFilter = v ?? 'all'),
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
              onAccept: () => FirestoreService.updateSubmissionStatus(
                  filtered[index].id, 'accepted'),
              onReject: () => FirestoreService.updateSubmissionStatus(
                  filtered[index].id, 'rejected'),
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
          s.title.toLowerCase().contains(query);

      final matchesStatus = _statusFilter == 'all' || s.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }
}

// ===================== SUBMISSION CARD =====================

class _SubmissionCard extends StatelessWidget {
  final Submission submission;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _SubmissionCard({
    required this.submission,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(submission.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Ref: ${submission.referenceNumber}'),
            Text('Author: ${submission.author}',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('Type: ${submission.submissionType}'),
            const SizedBox(height: 4),
            Chip(
              label: Text(submission.status.toUpperCase()),
              backgroundColor: Color.fromRGBO(
                _statusColor(submission.status).red,
                _statusColor(submission.status).green,
                _statusColor(submission.status).blue,
                0.15,
              ),
              labelStyle: TextStyle(color: _statusColor(submission.status)),
            ),
            if (submission.createdAt != null)
              Text(
                'Submitted: ${DateFormat.yMMMd().add_Hm().format(submission.createdAt!)}',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),

            // 🔹 Preview extracted text
            if (submission.extractedText != null &&
                submission.extractedText!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  submission.extractedText!,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            const SizedBox(height: 10),
            Row(
              children: [
                if (submission.status == 'pending') ...[
                  FilledButton(
                      onPressed: onAccept, child: const Text('Accept')),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onReject,
                    style:
                        OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                ],
                const Spacer(),

                // Open PDF URL
                if (submission.pdfUrl != null && submission.pdfUrl!.isNotEmpty)
                  IconButton(
                    tooltip: 'Open PDF',
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      await launchUrlString(submission.pdfUrl!,
                          webOnlyWindowName: '_blank');
                    },
                  ),

                // View Full Text
                if (submission.extractedText != null &&
                    submission.extractedText!.isNotEmpty)
                  IconButton(
                    tooltip: 'View Full Text',
                    icon: const Icon(Icons.article_outlined),
                    onPressed: () async {
                      final encoded = Uri.dataFromString(
                        submission.extractedText!,
                        mimeType: 'text/plain',
                        encoding: utf8,
                      ).toString();
                      await launchUrlString(encoded,
                          webOnlyWindowName: '_blank');
                    },
                  ),

                // Download as PDF
                if (submission.extractedText != null &&
                    submission.extractedText!.isNotEmpty)
                  IconButton(
                    tooltip: 'Download PDF',
                    icon: const Icon(Icons.picture_as_pdf),
                    onPressed: () async {
                      final pdf = pw.Document();
                      pdf.addPage(
                        pw.Page(
                          build: (context) => pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                  'Reference: ${submission.referenceNumber}',
                                  style: pw.TextStyle(
                                      fontSize: 14,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text('Title: ${submission.title}',
                                  style: pw.TextStyle(fontSize: 12)),
                              pw.Text('Author: ${submission.author}',
                                  style: pw.TextStyle(fontSize: 12)),
                              pw.SizedBox(height: 10),
                              pw.Text(submission.extractedText!,
                                  style: pw.TextStyle(fontSize: 11)),
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
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
