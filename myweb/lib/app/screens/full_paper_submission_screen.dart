import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/author.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'home_screen.dart';

class FullPaperSubmissionScreen extends StatefulWidget {
  const FullPaperSubmissionScreen({super.key});

  @override
  State<FullPaperSubmissionScreen> createState() => _FullPaperSubmissionScreenState();
}

class _FullPaperSubmissionScreenState extends State<FullPaperSubmissionScreen> {
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

  @override
  void dispose() {
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

      // Main author (first in list, marked as main)
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

  // ——— UI ———

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Full Paper'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Paper Title
              _buildSectionHeader('Paper Information'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Paper Title *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => _validateRequired(v, 'Title'),
              ),

              const SizedBox(height: 24),

              // Main Author Section
              _buildSectionHeader('Main Author (Required)'),
              const SizedBox(height: 8),
              _buildMainAuthorForm(),

              const SizedBox(height: 24),

              // Co-Authors Section
              _buildSectionHeader('Co-Authors (Optional, max 5)'),
              const SizedBox(height: 8),
              ..._buildCoAuthorForms(),
              if (_coAuthors.length < 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _addCoAuthor,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Co-Author'),
                  ),
                ),

              const SizedBox(height: 24),

              // PDF Upload Section
              _buildSectionHeader('Paper File'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        _pickedFile != null ? Icons.picture_as_pdf : Icons.upload_file,
                        size: 48,
                        color: _pickedFile != null ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _pickedFile != null
                            ? _pickedFile!.name
                            : 'No file selected',
                        style: TextStyle(
                          color: _pickedFile != null ? Colors.black : Colors.grey,
                        ),
                      ),
                      if (_pickedFile != null)
                        Text(
                          '${(_pickedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _uploading ? null : _pickPdf,
                        icon: const Icon(Icons.attach_file),
                        label: Text(_pickedFile != null ? 'Change PDF' : 'Select PDF (max 10MB)'),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Submit Button
              FilledButton(
                onPressed: _uploading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _uploading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Submit Paper', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildMainAuthorForm() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: _mainAuthorNameController,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) => _validateRequired(v, 'Name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mainAuthorAffiliationController,
              decoration: const InputDecoration(
                labelText: 'Affiliation *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (v) => _validateRequired(v, 'Affiliation'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mainAuthorEmailController,
              decoration: const InputDecoration(
                labelText: 'Email *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mainAuthorPhoneController,
              decoration: const InputDecoration(
                labelText: 'Phone *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]')),
              ],
              validator: _validatePhone,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCoAuthorForms() {
    return _coAuthors.asMap().entries.map((entry) {
      final index = entry.key;
      final coAuthor = entry.value;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Co-Author ${index + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _removeCoAuthor(index),
                    tooltip: 'Remove',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: coAuthor.nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (v) => _validateRequired(v, 'Name'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: coAuthor.affiliationController,
                decoration: const InputDecoration(
                  labelText: 'Affiliation *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (v) => _validateRequired(v, 'Affiliation'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: coAuthor.emailController,
                decoration: const InputDecoration(
                  labelText: 'Email (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: coAuthor.phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d\s\-\+\(\)]')),
                ],
              ),
            ],
          ),
        ),
      );
    }).toList();
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
