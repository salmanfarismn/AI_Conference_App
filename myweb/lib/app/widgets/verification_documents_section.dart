import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/auth_service.dart';
import '../../services/verification_service.dart';

/// A self-contained widget that shows the "Verification Documents" section
/// on the user dashboard. Only visible after paymentStatus == "paid".
///
/// Displays:
///   - Upload ID Card button
///   - Upload Payment Receipt button
///   - Upload status with indicators
///   - Verification status badge
///
/// This widget does NOT modify any existing dashboard code.
class VerificationDocumentsSection extends StatefulWidget {
  final Color accentColor;

  const VerificationDocumentsSection({
    super.key,
    this.accentColor = const Color(0xFF7C4DFF),
  });

  @override
  State<VerificationDocumentsSection> createState() =>
      _VerificationDocumentsSectionState();
}

class _VerificationDocumentsSectionState
    extends State<VerificationDocumentsSection> {
  bool _isLoading = true;
  bool _isUploadingIdCard = false;
  bool _isUploadingReceipt = false;

  String? _idCardUrl;
  String? _paymentReceiptUrl;
  String _verificationStatus = 'not_submitted';

  @override
  void initState() {
    super.initState();
    _loadVerificationStatus();
  }

  Future<void> _loadVerificationStatus() async {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);

    final result = await VerificationService.getVerificationStatus(uid);

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result['success'] == true) {
          _idCardUrl = result['idCardUrl'] as String?;
          _paymentReceiptUrl = result['paymentReceiptImageUrl'] as String?;
          _verificationStatus =
              (result['verificationStatus'] as String?) ?? 'not_submitted';
        }
      });
    }
  }

  Future<void> _pickAndUploadIdCard() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      _showSnackBar('File size exceeds 5MB limit.', isError: true);
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploadingIdCard = true);

    final uploadResult = await VerificationService.uploadIdCard(
      userId: uid,
      fileBytes: file.bytes!,
      fileName: file.name,
    );

    if (mounted) {
      setState(() => _isUploadingIdCard = false);

      if (uploadResult['success'] == true) {
        _showSnackBar('ID Card uploaded successfully!');
        _loadVerificationStatus();
      } else {
        _showSnackBar(
          uploadResult['error'] ?? 'Upload failed.',
          isError: true,
        );
      }
    }
  }

  Future<void> _pickAndUploadReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    // Validate file size (5MB max)
    if (file.size > 5 * 1024 * 1024) {
      _showSnackBar('File size exceeds 5MB limit.', isError: true);
      return;
    }

    final uid = AuthService.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploadingReceipt = true);

    final uploadResult = await VerificationService.uploadPaymentReceipt(
      userId: uid,
      fileBytes: file.bytes!,
      fileName: file.name,
    );

    if (mounted) {
      setState(() => _isUploadingReceipt = false);

      if (uploadResult['success'] == true) {
        _showSnackBar('Payment receipt uploaded successfully!');
        _loadVerificationStatus();
      } else {
        _showSnackBar(
          uploadResult['error'] ?? 'Upload failed.',
          isError: true,
        );
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final isApproved = _verificationStatus == 'approved';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),

        // Section header
        Text(
          'VERIFICATION DOCUMENTS',
          style: TextStyle(
            color: widget.accentColor,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Status badge
        _buildStatusBadge(),
        const SizedBox(height: 16),

        // ID Card upload
        _buildUploadCard(
          title: 'ID Card',
          subtitle: _idCardUrl != null
              ? 'Uploaded ✓'
              : 'Government or Institution ID Card',
          icon: Icons.badge_rounded,
          imageUrl: _idCardUrl,
          isUploading: _isUploadingIdCard,
          isDisabled: isApproved,
          onUpload: _pickAndUploadIdCard,
        ),
        const SizedBox(height: 12),

        // Payment Receipt upload
        _buildUploadCard(
          title: 'Payment Receipt',
          subtitle: _paymentReceiptUrl != null
              ? 'Uploaded ✓'
              : 'Payment receipt image for manual verification',
          icon: Icons.receipt_long_rounded,
          imageUrl: _paymentReceiptUrl,
          isUploading: _isUploadingReceipt,
          isDisabled: isApproved,
          onUpload: _pickAndUploadReceipt,
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    late final Color bgColor;
    late final Color textColor;
    late final IconData iconData;
    late final String label;

    switch (_verificationStatus) {
      case 'approved':
        bgColor = Colors.green.withOpacity(0.15);
        textColor = Colors.green;
        iconData = Icons.verified_rounded;
        label = 'Verified ✅';
        break;
      case 'rejected':
        bgColor = Colors.red.withOpacity(0.15);
        textColor = Colors.red;
        iconData = Icons.cancel_rounded;
        label = 'Rejected – Please Reupload';
        break;
      case 'pending':
        bgColor = Colors.amber.withOpacity(0.15);
        textColor = Colors.amber;
        iconData = Icons.hourglass_top_rounded;
        label = 'Pending Verification';
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.15);
        textColor = Colors.grey;
        iconData = Icons.upload_file_rounded;
        label = 'Upload Required';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, color: textColor, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String? imageUrl,
    required bool isUploading,
    required bool isDisabled,
    required VoidCallback onUpload,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        color: const Color(0xFF1E1B4B).withOpacity(0.4),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Upload row
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isDisabled || isUploading ? null : onUpload,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: imageUrl != null
                                ? Colors.green.withOpacity(0.2)
                                : widget.accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: isUploading
                              ? SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: widget.accentColor,
                                  ),
                                )
                              : Icon(
                                  imageUrl != null
                                      ? Icons.check_circle_rounded
                                      : icon,
                                  color: imageUrl != null
                                      ? Colors.green
                                      : widget.accentColor,
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
                                  color: isDisabled
                                      ? Colors.white60
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isUploading
                                    ? 'Uploading...'
                                    : isDisabled
                                        ? 'Verified — re-upload disabled'
                                        : subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isUploading
                                      ? Colors.amber
                                      : (isDisabled
                                          ? Colors.white38
                                          : Colors.white70),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isDisabled && !isUploading)
                          Icon(
                            imageUrl != null
                                ? Icons.refresh_rounded
                                : Icons.upload_rounded,
                            color: Colors.white54,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Image preview (if uploaded)
              if (imageUrl != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return SizedBox(
                            height: 100,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stack) {
                          return SizedBox(
                            height: 80,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.broken_image,
                                      color: Colors.white38, size: 32),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Image preview unavailable',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
