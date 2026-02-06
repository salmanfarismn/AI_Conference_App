import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/author.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import '../widgets/parallax_background.dart';
import 'home_screen.dart';

class FullPaperSubmissionScreen extends StatefulWidget {
  const FullPaperSubmissionScreen({super.key});

  @override
  State<FullPaperSubmissionScreen> createState() => _FullPaperSubmissionScreenState();
}

class _FullPaperSubmissionScreenState extends State<FullPaperSubmissionScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  // Main author controllers
  final _mainAuthorNameController = TextEditingController();
  final _mainAuthorAffiliationController = TextEditingController();
  final _mainAuthorEmailController = TextEditingController();
  final _mainAuthorPhoneController = TextEditingController();
  
  // Co-authors (max 5)
  final List<_CoAuthorFields> _coAuthors = [];
  
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
    _mainAuthorNameController.dispose();
    _mainAuthorAffiliationController.dispose();
    _mainAuthorEmailController.dispose();
    _mainAuthorPhoneController.dispose();
    for (final coAuthor in _coAuthors) {
      coAuthor.dispose();
    }
    super.dispose();
  }

  // ——— Validation ———

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final phoneRegex = RegExp(r'^[\d\s\-\+\(\)]{7,20}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Enter a valid phone number';
    }
    return null;
  }

  // ——— Co-author management ———

  void _addCoAuthor() {
    if (_coAuthors.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 5 co-authors allowed')),
      );
      return;
    }
    setState(() {
      _coAuthors.add(_CoAuthorFields());
    });
  }

  void _removeCoAuthor(int index) {
    setState(() {
      _coAuthors[index].dispose();
      _coAuthors.removeAt(index);
    });
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

  // ——— Submit ———

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file.')),
      );
      return;
    }

    final Uint8List? bytes = _pickedFile!.bytes;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read file. Please try again.')),
      );
      return;
    }

    setState(() => _uploading = true);

    try {
      // Get reference number first
      final referenceNumber = await FirestoreService.getNextReferenceNumber();

      // Upload PDF
      final pdfUrl = await StorageService.uploadFullPaperPdf(
        bytes: bytes,
        referenceNumber: referenceNumber,
      );

      // Build authors list
      final authors = <Map<String, dynamic>>[];

      // Main author
      authors.add(Author(
        name: _mainAuthorNameController.text.trim(),
        affiliation: _mainAuthorAffiliationController.text.trim(),
        email: _mainAuthorEmailController.text.trim(),
        phone: _mainAuthorPhoneController.text.trim(),
        isMainAuthor: true,
      ).toMap());

      // Co-authors
      for (final coAuthor in _coAuthors) {
        if (coAuthor.nameController.text.trim().isNotEmpty) {
          authors.add(Author(
            name: coAuthor.nameController.text.trim(),
            affiliation: coAuthor.affiliationController.text.trim(),
            email: coAuthor.emailController.text.trim().isNotEmpty
                ? coAuthor.emailController.text.trim()
                : null,
            phone: coAuthor.phoneController.text.trim().isNotEmpty
                ? coAuthor.phoneController.text.trim()
                : null,
            isMainAuthor: false,
          ).toMap());
        }
      }

      // Submit to Firestore
      await FirestoreService.addFullPaperSubmission(
        uid: AuthService.currentUser!.uid,
        title: _titleController.text.trim(),
        authors: authors,
        pdfUrl: pdfUrl,
        referenceNumber: referenceNumber,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paper submitted successfully! Reference: $referenceNumber'),
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
        SnackBar(content: Text('Submission failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ——— UI Components ———

  @override
  Widget build(BuildContext context) {
    // Custom Indigo/Violet Dark Theme
    const primaryIndigo = Color(0xFF6200EA); // Deep Indigo
    const accentViolet = Color(0xFF7C4DFF); // Violet
    
    final darkTheme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: accentViolet,
        secondary: primaryIndigo, 
        surface: Color(0xFF0F0E1C), // Deep dark slightly purple surface
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
          title: const Text('Full Paper Submission'),
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
                      child: Form(
                        key: _formKey,
                        child: FadeTransition(
                          opacity: _animationController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  'Submit Your Research',
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

                              // Paper Info
                              _buildGlassSection(
                                title: 'Paper Information',
                                icon: Icons.article_rounded,
                                children: [
                                  TextFormField(
                                    controller: _titleController,
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    decoration: const InputDecoration(
                                      labelText: 'Paper Title',
                                      prefixIcon: Icon(Icons.title_rounded),
                                    ),
                                    validator: (v) => _validateRequired(v, 'Title'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Main Author
                              _buildGlassSection(
                                title: 'Main Author',
                                icon: Icons.person_rounded,
                                children: [
                                  _buildAuthorInputs(
                                    nameCtrl: _mainAuthorNameController,
                                    affCtrl: _mainAuthorAffiliationController,
                                    emailCtrl: _mainAuthorEmailController,
                                    phoneCtrl: _mainAuthorPhoneController,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Co-Authors
                              Column(
                                children: [
                                  ..._coAuthors.asMap().entries.map((entry) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 24),
                                      child: _buildGlassSection(
                                        title: 'Co-Author ${entry.key + 1}',
                                        icon: Icons.group_add_rounded,
                                        onRemove: () => _removeCoAuthor(entry.key),
                                        children: [
                                          _buildAuthorInputs(
                                            nameCtrl: entry.value.nameController,
                                            affCtrl: entry.value.affiliationController,
                                            emailCtrl: entry.value.emailController,
                                            phoneCtrl: entry.value.phoneController,
                                            isOptionalEmailPhone: true,
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),

                              if (_coAuthors.length < 5)
                                Center(
                                  child: ConsumerHoverButton(
                                    onTap: _addCoAuthor,
                                    label: 'Add Co-Author',
                                    icon: Icons.add_circle_outline_rounded,
                                  ),
                                ),
                              
                              const SizedBox(height: 32),

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
                                          'SUBMIT PAPER',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
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
      ),
    );
  }

  Widget _buildGlassSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onRemove,
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
                    if (onRemove != null) ...[
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white54),
                        onPressed: onRemove,
                      )
                    ]
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

  Widget _buildAuthorInputs({
    required TextEditingController nameCtrl,
    required TextEditingController affCtrl,
    required TextEditingController emailCtrl,
    required TextEditingController phoneCtrl,
    bool isOptionalEmailPhone = false,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => _validateRequired(v, 'Name'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: affCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Affiliation',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (v) => _validateRequired(v, 'Affiliation'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isOptionalEmailPhone ? 'Email (Optional)' : 'Email',
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: isOptionalEmailPhone
                    ? (v) => v != null && v.isNotEmpty ? _validateEmail(v) : null
                    : _validateEmail,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: phoneCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: isOptionalEmailPhone ? 'Phone (Optional)' : 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]')),
                ],
                validator: isOptionalEmailPhone ? null : _validatePhone,
              ),
            ),
          ],
        ),
      ],
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
              hasFile ? _pickedFile!.name : 'Click to Upload PDF',
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
                  : 'Maximum file size: 10MB',
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
}

/// Helper class to manage co-author form controllers
class _CoAuthorFields {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController affiliationController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  void dispose() {
    nameController.dispose();
    affiliationController.dispose();
    emailController.dispose();
    phoneController.dispose();
  }
}

class ConsumerHoverButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;

  const ConsumerHoverButton({
    super.key,
    required this.onTap,
    required this.label,
    required this.icon,
  });

  @override
  State<ConsumerHoverButton> createState() => _ConsumerHoverButtonState();
}

class _ConsumerHoverButtonState extends State<ConsumerHoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF7C4DFF);
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isHovered ? accentColor : Colors.white38,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon, 
                color: _isHovered ? accentColor : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
