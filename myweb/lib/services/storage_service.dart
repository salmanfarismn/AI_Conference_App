import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StorageService {
  static final _storage = FirebaseStorage.instance;

  /// Upload PDF bytes and return download URL.
  /// Path: submissions/{uid}/{refNumber}_{type}.pdf
  static Future<String> uploadSubmissionPdf({
    required Uint8List bytes,
    required String referenceNumber,
    required String submissionType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final name = '${referenceNumber}_$submissionType.pdf'.replaceAll('/', '_');
    final ref = _storage.ref().child('submissions').child(uid).child(name);
    try {
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
      final snapshot = await uploadTask;
      if (snapshot.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          message: 'Upload failed, task state: ${snapshot.state}',
        );
      }
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      rethrow;
    } catch (e) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Unknown upload error: $e',
      );
    }
  }

  /// Upload DOCX bytes and return download URL.
  /// Path: submissions/{uid}/{refNumber}_{type}.docx
  static Future<String> uploadSubmissionDocx({
    required Uint8List bytes,
    required String referenceNumber,
    required String submissionType,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final name = '${referenceNumber}_$submissionType.docx'.replaceAll('/', '_');
    final ref = _storage.ref().child('submissions').child(uid).child(name);
    try {
      final uploadTask = ref.putData(bytes, SettableMetadata(contentType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
      final snapshot = await uploadTask;
      if (snapshot.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          message: 'Upload failed, task state: ${snapshot.state}',
        );
      }
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      rethrow;
    } catch (e) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Unknown upload error: $e',
      );
    }
  }

  /// Upload full paper PDF with size validation.
  /// Max size: 10MB. Only PDF allowed.
  /// Path: papers/{uid}/{refNumber}_fullpaper.pdf
  static Future<String> uploadFullPaperPdf({
    required Uint8List bytes,
    required String referenceNumber,
  }) async {
    // Validate file size (10MB max)
    const maxSize = 10 * 1024 * 1024; // 10MB in bytes
    if (bytes.length > maxSize) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'File size exceeds 10MB limit. Please upload a smaller file.',
      );
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    final name = '${referenceNumber}_fullpaper.pdf'.replaceAll('/', '_');
    final ref = _storage.ref().child('papers').child(uid).child(name);
    
    try {
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'application/pdf'),
      );
      final snapshot = await uploadTask;
      
      if (snapshot.state != TaskState.success) {
        throw FirebaseException(
          plugin: 'firebase_storage',
          message: 'Upload failed, task state: ${snapshot.state}',
        );
      }
      
      final url = await ref.getDownloadURL();
      return url;
    } on FirebaseException catch (e) {
      rethrow;
    } catch (e) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Unknown upload error: $e',
      );
    }
  }
}
