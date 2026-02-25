import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Conference Brochure',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const BrochureScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class BrochureScreen extends StatefulWidget {
  const BrochureScreen({super.key});

  @override
  State<BrochureScreen> createState() => _BrochureScreenState();
}

class _BrochureScreenState extends State<BrochureScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();

  // 🔹 Open conference website
  Future<void> _openConferenceWebsite() async {
    final Uri url = Uri.parse('https://conference.uccimt.edu.in');
    try {
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      )) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // 🔹 Open paper submission link
  Future<void> _openPaperSubmission() async {
    final Uri url = Uri.parse('https://m-app-754d5.web.app');
    try {
      if (!await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      )) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch $url')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conference Brochure 2026'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              _pdfViewerKey.currentState?.openBookmarkView();
            },
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () {
              _pdfViewerController.zoomLevel = 2.0;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 🔹 Quick Links Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(
                  onPressed: _openConferenceWebsite,
                  icon: const Icon(Icons.web),
                  label: const Text('Visit Website'),
                ),
                VerticalDivider(color: Colors.indigo.shade200),
                TextButton.icon(
                  onPressed: _openPaperSubmission,
                  icon: const Icon(Icons.description),
                  label: const Text('Submit Paper'),
                ),
              ],
            ),
          ),
          // 🔹 PDF Viewer
          Expanded(
            child: SfPdfViewer.asset(
              'assets/conference_document.pdf',
              key: _pdfViewerKey,
              controller: _pdfViewerController,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPaperSubmission,
        label: const Text('Submit Paper Now'),
        icon: const Icon(Icons.send),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}
