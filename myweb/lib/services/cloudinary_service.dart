import 'dart:typed_data';
import 'package:cloudinary_public/cloudinary_public.dart';

/// Service for uploading files to Cloudinary.
class CloudinaryService {
  static final _cloudinary = CloudinaryPublic(
    'dy5kx6nfl',           // Cloud Name
    'full_paper_submission', // Upload Preset
    cache: false,
  );

  /// Upload full paper PDF to Cloudinary.
  /// Returns the secure URL of the uploaded file.
  static Future<String> uploadFullPaperPdf({
    required Uint8List bytes,
    required String referenceNumber,
  }) async {
    // Validate file size (10MB max)
    const maxSize = 10 * 1024 * 1024;
    if (bytes.length > maxSize) {
      throw Exception('File size exceeds 10MB limit. Please upload a smaller file.');
    }

    try {
      final fileName = '${referenceNumber}_fullpaper.pdf';
      
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          resourceType: CloudinaryResourceType.Auto, // Auto-detect for proper PDF handling
        ),
      );

      return response.secureUrl;
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// Upload revised paper PDF to Cloudinary.
  /// Uses version number in filename to prevent overwriting previous versions.
  /// Returns the secure URL of the uploaded file.
  static Future<String> uploadRevisionPdf({
    required Uint8List bytes,
    required String referenceNumber,
    required int versionNumber,
  }) async {
    // Validate file size (10MB max)
    const maxSize = 10 * 1024 * 1024;
    if (bytes.length > maxSize) {
      throw Exception('File size exceeds 10MB limit. Please upload a smaller file.');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${referenceNumber}_v${versionNumber}_$timestamp.pdf';
      
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromBytesData(
          bytes,
          identifier: fileName,
          resourceType: CloudinaryResourceType.Auto,
        ),
      );

      return response.secureUrl;
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary upload failed: ${e.message}');
    } catch (e) {
      throw Exception('Revision upload error: $e');
    }
  }
}
