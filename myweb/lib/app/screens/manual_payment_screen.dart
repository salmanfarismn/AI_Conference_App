import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../widgets/parallax_background.dart';
import 'home_screen.dart';

class ManualPaymentScreen extends StatefulWidget {
  const ManualPaymentScreen({super.key});

  @override
  State<ManualPaymentScreen> createState() => _ManualPaymentScreenState();
}

class _ManualPaymentScreenState extends State<ManualPaymentScreen> {
  PlatformFile? _receiptFile;
  PlatformFile? _idCardFile;
  bool _isUploading = false;
  String? _error;

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() => _receiptFile = result.files.first);
    }
  }

  Future<void> _pickIdCard() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null) {
      setState(() => _idCardFile = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (_receiptFile == null || _idCardFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please upload both receipt and ID card.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      final uid = AuthService.currentUser?.uid;
      if (uid == null) throw Exception('User not logged in');

      // Upload receipt
      final receiptUrl = await StorageService.uploadPaymentFile(
        bytes: _receiptFile!.bytes!,
        type: 'receipt',
        extension: _receiptFile!.extension ?? 'jpg',
      );

      // Upload ID card
      final idCardUrl = await StorageService.uploadPaymentFile(
        bytes: _idCardFile!.bytes!,
        type: 'idcard',
        extension: _idCardFile!.extension ?? 'jpg',
      );

      // Update Firestore
      await FirestoreService.submitPaymentVerification(
        uid: uid,
        receiptUrl: receiptUrl,
        idCardUrl: idCardUrl,
      );

      if (!mounted) return;

      // Navigate to success/pending page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ManualPaymentPendingScreen(),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentViolet = Color(0xFF7C4DFF);
    const primaryIndigo = Color(0xFF6200EA);
    final uid = AuthService.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: uid != null ? FirestoreService.userProfileStream(uid) : null,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final status = snapshot.data?.data()?['paymentStatus'] as String?;
          if (status == 'verified') {
            return const ManualPaymentPendingScreen(); // This will show Success View
          }
          if (status == 'pending' && !_isUploading) {
            return const ManualPaymentPendingScreen();
          }
        }

        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Manual Payment Verification'),
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
          body: ParallaxBackground(
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildUploadCard(accentViolet, primaryIndigo),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUploadCard(Color accentViolet, Color primaryIndigo) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0xFF1E1B4B).withOpacity(0.6),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload Proof of Payment',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Please upload your payment receipt and ID card for verification.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Receipt Upload
          _buildFilePicker(
            label: 'Payment Receipt',
            file: _receiptFile,
            onPick: _pickReceipt,
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(height: 20),

          // ID Card Upload
          _buildFilePicker(
            label: 'ID Card (Student/Researcher)',
            file: _idCardFile,
            onPick: _pickIdCard,
            icon: Icons.badge_rounded,
          ),
          const SizedBox(height: 40),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          ElevatedButton(
            onPressed: _isUploading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: accentViolet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isUploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit Verification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker({
    required String label,
    required PlatformFile? file,
    required VoidCallback onPick,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: file != null
                    ? Colors.green.withOpacity(0.5)
                    : Colors.white10,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  file != null ? Icons.check_circle_rounded : icon,
                  color: file != null ? Colors.green : Colors.white38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file?.name ?? 'Tap to select image',
                    style: TextStyle(
                      color: file != null ? Colors.white : Colors.white38,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (file != null)
                  const Icon(Icons.edit_rounded,
                      size: 18, color: Colors.white24),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ManualPaymentPendingScreen extends StatelessWidget {
  const ManualPaymentPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Not logged in'));

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.userProfileStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data?.data() != null) {
          final data = snapshot.data!.data()!;
          final status = data['paymentStatus'] as String? ?? 'pending';

          if (status == 'verified') {
            return const _PaymentSuccessView();
          } else if (status == 'rejected') {
            return _PaymentRejectedView(reason: data['paymentRejectionReason']);
          }
        }

        return Scaffold(
          body: ParallaxBackground(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: const Color(0xFF1E1B4B).withOpacity(0.6),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_empty_rounded,
                          size: 64, color: Colors.orangeAccent),
                      const SizedBox(height: 24),
                      const Text(
                        'Verification Pending',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your payment proof has been submitted. An administrator will review it shortly. You will be redirected once it is accepted.',
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HomeScreen()),
                              (_) => false,
                            );
                          },
                          child: const Text('Go to Home'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PaymentSuccessView extends StatelessWidget {
  const _PaymentSuccessView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParallaxBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF1E1B4B).withOpacity(0.6),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline_rounded,
                      size: 64, color: Colors.greenAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'Payment Verified!',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Congratulations! Your payment has been successfully verified by the administrator. Your registration is now confirmed.',
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const HomeScreen()),
                          (_) => false,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Go to Home Screen',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentRejectedView extends StatelessWidget {
  final String? reason;
  const _PaymentRejectedView({this.reason});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ParallaxBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: const Color(0xFF1E1B4B).withOpacity(0.6),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded,
                      size: 64, color: Colors.redAccent),
                  const SizedBox(height: 24),
                  const Text(
                    'Verification Failed',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Reason: ${reason ?? "Your proof of payment was not accepted."}',
                    style: const TextStyle(color: Colors.redAccent),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ManualPaymentScreen()),
                        );
                      },
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
