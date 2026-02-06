import 'dart:ui';
import 'dart:typed_data';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart' as xml;

import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../widgets/parallax_background.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

class SubmitPaperScreen extends StatefulWidget {
  final String submissionType; // 'abstract' | 'fullpaper'

  const SubmitPaperScreen({
    super.key,
    required this.submissionType,
  });

  @override
  State<SubmitPaperScreen> createState() => _SubmitPaperScreenState();
}

class _SubmitPaperScreenState extends State<SubmitPaperScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

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
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  String get _typeLabel =>
      widget.submissionType == 'abstract' ? 'Abstract' : 'Full Paper';

  // ---------------- FILE PICKER ----------------

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['docx'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;

    if (file.extension?.toLowerCase() != 'docx') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a .docx Word document only.'),
        ),
      );
      return;
    }

    setState(() => _pickedFile = file);
  }

  // ---------------- SUBMIT ----------------

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();

    if (title.isEmpty) {
      _showError('Enter a title for your submission.');
      return;
    }

    if (author.isEmpty) {
      _showError('Enter the author name.');
      return;
    }

    if (_pickedFile == null) {
      _showError('Please select a Word document (.docx).');
      return;
    }

    final Uint8List? bytes = _pickedFile!.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showError('Unable to read file. Please try again.');
      return;
    }

    setState(() => _uploading = true);

    try {
      final referenceNumber = await FirestoreService.getNextReferenceNumber();

      final extractedText = _extractTextFromDocx(bytes);

      // Convert bytes to base64 and store inside Firestore document
      final docBase64 = base64Encode(bytes);

      await FirestoreService.addSubmission(
        uid: AuthService.currentUser!.uid,
        title: title,
        author: author,
        submissionType: widget.submissionType,
        referenceNumber: referenceNumber,
        extractedText: extractedText.isEmpty ? null : extractedText,
        docBase64: docBase64,
        docName: _pickedFile?.name,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submitted successfully. Reference: $referenceNumber'),
          backgroundColor: Colors.green,
        ),
      );

      if (AuthService.isAnonymous) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
          (_) => false,
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Submission failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ---------------- DOCX TEXT EXTRACTION ----------------

  String _extractTextFromDocx(Uint8List bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final docXml = archive.firstWhere(
        (file) => file.name == 'word/document.xml',
      );

      final xmlContent = String.fromCharCodes(docXml.content as List<int>);
      final document = xml.XmlDocument.parse(xmlContent);

      return document.findAllElements('w:t').map((e) => e.text).join(' ');
    } catch (_) {
      return '';
    }
  }

  // ---------------- UI HELPERS ----------------

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    // Custom Indigo/Violet Dark Theme
    const primaryIndigo = Color(0xFF6200EA); // Deep Indigo
    const accentViolet = Color(0xFF7C4DFF); // Violet
    
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accentViolet,
        secondary: primaryIndigo, 
        surface: Color(0xFF0F0E1C),
        error: Color(0xFFFF5252),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.black.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accentViolet, width: 1.5),
        ),
        labelStyle: TextStyle(color: Colors.white70),
        prefixIconColor: Colors.white60,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        bodyLarge: TextStyle(color: Colors.white),
      ),
    );

    return Theme(
      data: darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text('Submit $_typeLabel'),
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
                    // Taking half of the horizontal space
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: FadeTransition(
                        opacity: _animationController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 10),
                            Center(
                              child: Text(
                                'Submit Your $_typeLabel',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),
                             Center(
                              child: Text(
                                'Share your findings with the world.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white60,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 40),

                            // Paper Info Section
                            _buildGlassSection(
                              title: 'Submission Details',
                              icon: Icons.description_rounded,
                              children: [
                                TextField(
                                  controller: _titleController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Title',
                                    prefixIcon: Icon(Icons.title_rounded),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _authorController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    labelText: 'Author Name',
                                    prefixIcon: Icon(Icons.person_rounded),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // File Upload
                            _buildUploadSection(accentViolet),

                            const SizedBox(height: 40),

                            // Submit Button
                            SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _uploading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: accentViolet,
                                  foregroundColor: Colors.white,
                                  shadowColor: accentViolet.withOpacity(0.5),
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: _uploading
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white70,
                                        ),
                                      )
                                    : const Text(
                                        'SUBMIT',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
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

  Widget _buildGlassSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C4DFF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: const Color(0xFF7C4DFF)),
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
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadSection(Color accentColor) {
    final bool hasFile = _pickedFile != null;
    return GestureDetector(
      onTap: _uploading ? null : _pickDocument,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: hasFile 
              ? accentColor.withOpacity(0.05) 
              : Colors.black.withOpacity(0.2),
          border: Border.all(
            color: hasFile 
                ? accentColor 
                : Colors.white.withOpacity(0.15),
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
                hasFile ? Icons.check_rounded : Icons.cloud_upload_outlined,
                size: 40,
                color: hasFile ? accentColor : Colors.white60,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasFile ? _pickedFile!.name : 'Click to Upload Document (.docx)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: hasFile ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
