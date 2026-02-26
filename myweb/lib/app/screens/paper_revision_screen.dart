import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../../models/submission.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/cloudinary_service.dart';
import '../widgets/parallax_background.dart';
import 'home_screen.dart';

/// Screen for uploading a revised paper when admin marks "accepted_with_revision".
/// Shows admin comments, version history timeline, and file upload.
class PaperRevisionScreen extends StatefulWidget {
  final Submission submission;

  const PaperRevisionScreen({
    super.key,
    required this.submission,
  });

  @override
  State<PaperRevisionScreen> createState() => _PaperRevisionScreenState();
}

class _PaperRevisionScreenState extends State<PaperRevisionScreen>
    with SingleTickerProviderStateMixin {
  PlatformFile? _pickedFile;
  bool _uploading = false;
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

  // ——— File picker ———

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    // Validate file type
    if (file.extension?.toLowerCase() != 'pdf') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file only.')),
      );
      return;
    }

    // Validate file size (10MB max)
    const maxSize = 10 * 1024 * 1024;
    if ((file.size) > maxSize) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File size must be less than 10MB.')),
      );
      return;
    }

    setState(() => _pickedFile = file);
  }

  // ——— Submit Revision ———

  Future<void> _submitRevision() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file.')),
      );
      return;
    }

    final Uint8List? bytes = _pickedFile!.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unable to read file. Please try again.')),
      );
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in.')),
      );
      return;
    }

    // Verify ownership
    if (widget.submission.uid != uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('You are not authorized to revise this submission.')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      final newVersion = widget.submission.currentVersion + 1;
      final referenceNumber = widget.submission.referenceNumber;

      // Upload revised PDF to Cloudinary
      final pdfUrl = await CloudinaryService.uploadRevisionPdf(
        bytes: bytes,
        referenceNumber: referenceNumber,
        versionNumber: newVersion,
      );

      // Update Firestore with new version
      await FirestoreService.resubmitPaperRevision(
        docId: widget.submission.id,
        newPdfUrl: pdfUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Revised paper submitted successfully! Now version $newVersion.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Revision failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      textTheme: const TextTheme(
        titleLarge:
            TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        bodyLarge: TextStyle(color: Colors.white),
      ),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Submit Revision'),
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
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: FadeTransition(
                      opacity: _animationController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ——— Revision Required Banner ———
                          _buildRevisionBanner(),
                          const SizedBox(height: 24),

                          // ——— Paper Info ———
                          _buildPaperInfoSection(),
                          const SizedBox(height: 24),

                          // ——— Admin Comments ———
                          if (widget.submission.reviewComments != null &&
                              widget.submission.reviewComments!.isNotEmpty)
                            _buildAdminCommentsSection(),
                          if (widget.submission.reviewComments != null &&
                              widget.submission.reviewComments!.isNotEmpty)
                            const SizedBox(height: 24),

                          // ——— Version History Timeline ———
                          if (widget.submission.hasRevisions)
                            _buildVersionHistorySection(),
                          if (widget.submission.hasRevisions)
                            const SizedBox(height: 24),

                          // ——— Upload Section ———
                          _buildUploadSection(accentViolet),
                          const SizedBox(height: 32),

                          // ——— Submit Button ———
                          SizedBox(
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _uploading ? null : _submitRevision,
                              icon: _uploading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white70,
                                      ),
                                    )
                                  : const Icon(Icons.upload_file_rounded),
                              label: Text(
                                _uploading
                                    ? 'UPLOADING...'
                                    : 'SUBMIT REVISED PAPER',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentViolet,
                                foregroundColor: Colors.white,
                                shadowColor: accentViolet.withOpacity(0.5),
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
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

  // ——— UI Components ———

  Widget _buildRevisionBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Colors.orange.withOpacity(0.2),
            Colors.deepOrange.withOpacity(0.1),
          ],
        ),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.orange.withOpacity(0.2),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.orangeAccent,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Revision Required',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your paper has been reviewed and requires revisions. '
                  'Please upload a revised version addressing the feedback below.',
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
      ),
    );
  }

  Widget _buildPaperInfoSection() {
    final sub = widget.submission;
    return _buildGlassSection(
      title: 'Paper Details',
      icon: Icons.article_rounded,
      children: [
        _buildInfoRow(Icons.tag_rounded, 'Reference', sub.referenceNumber),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.title_rounded, 'Title', sub.title),
        const SizedBox(height: 12),
        _buildInfoRow(
            Icons.person_rounded, 'Authors', sub.authorsDisplay),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.layers_rounded, 'Current Version',
            'v${sub.currentVersion}'),
        if (sub.pdfUrl != null && sub.pdfUrl!.isNotEmpty) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              await launchUrlString(sub.pdfUrl!,
                  webOnlyWindowName: '_blank');
            },
            icon:
                const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Current Version'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF7C4DFF),
              side: const BorderSide(color: Color(0xFF7C4DFF)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAdminCommentsSection() {
    return _buildGlassSection(
      title: 'Reviewer Feedback',
      icon: Icons.rate_review_rounded,
      accentColor: Colors.amber,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.submission.reviewComments!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              if (widget.submission.reviewedAt != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Reviewed on ${DateFormat.yMMMd().add_Hm().format(widget.submission.reviewedAt!)}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionHistorySection() {
    final versions = widget.submission.versions;
    return _buildGlassSection(
      title: 'Version History',
      icon: Icons.history_rounded,
      accentColor: const Color(0xFF7C4DFF),
      children: [
        ...versions.asMap().entries.map((entry) {
          final v = entry.value;
          final isLast = entry.key == versions.length - 1;
          return _buildVersionTimelineItem(v, isLast);
        }),
      ],
    );
  }

  Widget _buildVersionTimelineItem(PaperVersion version, bool isLast) {
    final statusColor = _getStatusColor(version.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
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
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
              ],
            ),
          ),
          // Version info
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Version ${version.version}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _getStatusLabel(version.status),
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (version.submittedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd()
                          .add_Hm()
                          .format(version.submittedAt!),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (version.adminComment.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Feedback: ${version.adminComment}',
                      style: TextStyle(
                        color: Colors.amber.withOpacity(0.8),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (version.fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        await launchUrlString(version.fileUrl,
                            webOnlyWindowName: '_blank');
                      },
                      child: Text(
                        'View PDF →',
                        style: TextStyle(
                          color: const Color(0xFF7C4DFF).withOpacity(0.8),
                          fontSize: 12,
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

  Widget _buildUploadSection(Color accentColor) {
    final bool hasFile = _pickedFile != null;
    return GestureDetector(
      onTap: _uploading ? null : _pickPdf,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: hasFile
              ? accentColor.withOpacity(0.05)
              : Colors.black.withOpacity(0.2),
          border: Border.all(
            color: hasFile ? accentColor : Colors.white.withOpacity(0.15),
            style: BorderStyle.solid,
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hasFile
                    ? accentColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
              ),
              child: Icon(
                hasFile
                    ? Icons.check_rounded
                    : Icons.cloud_upload_outlined,
                size: 40,
                color: hasFile ? accentColor : Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFile
                  ? _pickedFile!.name
                  : 'Click to Upload Revised PDF',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasFile ? Colors.white : Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFile
                  ? '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB'
                  : 'PDF only • Maximum file size: 10MB',
              style: TextStyle(
                color: hasFile ? accentColor : Colors.white38,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color accentColor = const Color(0xFF7C4DFF),
  }) {
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
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: accentColor),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      case 'accepted_with_revision':
        return Colors.orangeAccent;
      case 'pending_review':
        return Colors.blueAccent;
      case 'submitted':
        return const Color(0xFF7C4DFF);
      default:
        return Colors.amberAccent;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'accepted_with_revision':
        return 'REVISION REQUESTED';
      case 'pending_review':
        return 'PENDING REVIEW';
      default:
        return status.toUpperCase();
    }
  }
}
