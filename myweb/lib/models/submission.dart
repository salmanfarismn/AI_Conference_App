import 'author.dart';

/// Submission stored in Firestore `submissions` collection.
/// Extended to support full paper submissions with multiple authors and review workflow.
class Submission {
  final String id;
  final String uid;
  final String referenceNumber;
  final String title;
  final String? author; // Legacy: single author string for backward compat
  final List<Author> authors; // New: list of authors (max 5, first is main author)
  final String? pdfUrl;
  final String? docBase64;
  final String? docName;
  final String? extractedText;
  final String status; // 'submitted' | 'pending' | 'under_review' | 'accepted' | 'rejected' | 'revision_requested'
  final String submissionType; // 'abstract' | 'fullpaper'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Review fields
  final String? reviewComments;
  final String? reviewedBy; // Admin uid who reviewed
  final DateTime? reviewedAt;

  Submission({
    required this.id,
    required this.uid,
    required this.referenceNumber,
    required this.title,
    this.author,
    this.authors = const [],
    this.pdfUrl,
    this.docBase64,
    this.docName,
    this.extractedText,
    required this.status,
    required this.submissionType,
    this.createdAt,
    this.updatedAt,
    this.reviewComments,
    this.reviewedBy,
    this.reviewedAt,
  });

  factory Submission.fromDoc(String id, Map<String, dynamic> data) {
    // Parse createdAt
    Object? ts = data['createdAt'];
    DateTime? createdAt;
    if (ts is DateTime) {
      createdAt = ts;
    } else if (ts != null) {
      try {
        createdAt = (ts as dynamic).toDate();
      } catch (_) {}
    }

    // Parse updatedAt
    Object? updatedTs = data['updatedAt'];
    DateTime? updatedAt;
    if (updatedTs is DateTime) {
      updatedAt = updatedTs;
    } else if (updatedTs != null) {
      try {
        updatedAt = (updatedTs as dynamic).toDate();
      } catch (_) {}
    }

    // Parse reviewedAt
    Object? reviewTs = data['reviewedAt'];
    DateTime? reviewedAt;
    if (reviewTs is DateTime) {
      reviewedAt = reviewTs;
    } else if (reviewTs != null) {
      try {
        reviewedAt = (reviewTs as dynamic).toDate();
      } catch (_) {}
    }

    // Parse authors list
    List<Author> authors = [];
    if (data['authors'] != null && data['authors'] is List) {
      authors = (data['authors'] as List)
          .map((a) => Author.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    return Submission(
      id: id,
      uid: data['uid'] as String? ?? '',
      referenceNumber: data['referenceNumber'] as String? ?? '',
      title: data['title'] as String? ?? '',
      author: data['author'] as String?,
      authors: authors,
      pdfUrl: data['pdfUrl'] as String?,
      docBase64: data['docBase64'] as String?,
      docName: data['docName'] as String?,
      extractedText: data['extractedText'] as String?,
      status: (data['status'] as String? ?? 'pending').toLowerCase(),
      submissionType: data['submissionType'] as String? ?? 'abstract',
      createdAt: createdAt,
      updatedAt: updatedAt,
      reviewComments: data['reviewComments'] as String?,
      reviewedBy: data['reviewedBy'] as String?,
      reviewedAt: reviewedAt,
    );
  }

  /// Get display string for all authors
  String get authorsDisplay {
    if (authors.isNotEmpty) {
      return authors.map((a) => a.name).join(', ');
    }
    return author ?? '';
  }

  /// Get main author (first author in list, or fall back to legacy author field)
  Author? get mainAuthor {
    if (authors.isNotEmpty) {
      return authors.firstWhere((a) => a.isMainAuthor, orElse: () => authors.first);
    }
    return null;
  }

  /// Get co-authors (all authors except main)
  List<Author> get coAuthors {
    if (authors.length <= 1) return [];
    return authors.where((a) => !a.isMainAuthor).toList();
  }
}
