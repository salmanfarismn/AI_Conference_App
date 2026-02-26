import 'author.dart';

/// A single version entry in the paper's revision history.
class PaperVersion {
  final int version;
  final String fileUrl;
  final DateTime? submittedAt;
  final String status;
  final String adminComment;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final bool isCurrent;

  PaperVersion({
    required this.version,
    required this.fileUrl,
    this.submittedAt,
    required this.status,
    this.adminComment = '',
    this.reviewedBy,
    this.reviewedAt,
    this.isCurrent = false,
  });

  factory PaperVersion.fromMap(Map<String, dynamic> map) {
    // Parse submittedAt
    DateTime? submittedAt;
    final ts = map['submittedAt'];
    if (ts is DateTime) {
      submittedAt = ts;
    } else if (ts != null) {
      try {
        submittedAt = (ts as dynamic).toDate();
      } catch (_) {
        // Try parsing ISO string
        try {
          submittedAt = DateTime.parse(ts.toString());
        } catch (_) {}
      }
    }

    // Parse reviewedAt
    DateTime? reviewedAt;
    final rts = map['reviewedAt'];
    if (rts is DateTime) {
      reviewedAt = rts;
    } else if (rts != null) {
      try {
        reviewedAt = (rts as dynamic).toDate();
      } catch (_) {
        try {
          reviewedAt = DateTime.parse(rts.toString());
        } catch (_) {}
      }
    }

    return PaperVersion(
      version: (map['version'] as num?)?.toInt() ?? 1,
      fileUrl: map['fileUrl'] as String? ?? '',
      submittedAt: submittedAt,
      status: map['status'] as String? ?? '',
      adminComment: map['adminComment'] as String? ?? '',
      reviewedBy: map['reviewedBy'] as String?,
      reviewedAt: reviewedAt,
      isCurrent: map['isCurrent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'version': version,
        'fileUrl': fileUrl,
        'submittedAt': submittedAt?.toIso8601String(),
        'status': status,
        'adminComment': adminComment,
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'isCurrent': isCurrent,
      };
}

/// Submission stored in Firestore `submissions` collection.
/// Extended to support full paper submissions with multiple authors and review workflow.
/// Now includes revision history with version tracking.
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
  final String status; // 'submitted' | 'pending' | 'under_review' | 'accepted' | 'rejected' | 'accepted_with_revision' | 'pending_review'
  final String submissionType; // 'abstract' | 'fullpaper'
  final DateTime? createdAt;
  final DateTime? updatedAt;
  
  // Review fields
  final String? reviewComments;
  final String? reviewedBy; // Admin uid who reviewed
  final DateTime? reviewedAt;

  // Revision fields
  final int currentVersion;
  final List<PaperVersion> versions;
  final DateTime? lastRevisionAt;

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
    this.currentVersion = 1,
    this.versions = const [],
    this.lastRevisionAt,
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

    // Parse lastRevisionAt
    Object? revisionTs = data['lastRevisionAt'];
    DateTime? lastRevisionAt;
    if (revisionTs is DateTime) {
      lastRevisionAt = revisionTs;
    } else if (revisionTs != null) {
      try {
        lastRevisionAt = (revisionTs as dynamic).toDate();
      } catch (_) {}
    }

    // Parse authors list
    List<Author> authors = [];
    if (data['authors'] != null && data['authors'] is List) {
      authors = (data['authors'] as List)
          .map((a) => Author.fromMap(a as Map<String, dynamic>))
          .toList();
    }

    // Parse versions list
    List<PaperVersion> versions = [];
    if (data['versions'] != null && data['versions'] is List) {
      versions = (data['versions'] as List)
          .map((v) => PaperVersion.fromMap(v as Map<String, dynamic>))
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
      currentVersion: (data['currentVersion'] as num?)?.toInt() ?? 1,
      versions: versions,
      lastRevisionAt: lastRevisionAt,
    );
  }

  /// Whether this submission requires revision
  bool get needsRevision => status == 'accepted_with_revision';

  /// Whether the paper is currently under review after a revision
  bool get isPendingReview => status == 'pending_review';

  /// Whether this is a revised submission (has version history)
  bool get hasRevisions => versions.isNotEmpty;

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
