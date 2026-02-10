import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';
import '../models/submission.dart';
import '../models/app_settings.dart';

class FirestoreService {
  static final _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');
  static CollectionReference<Map<String, dynamic>> get _submissions =>
      _firestore.collection('submissions');
  static DocumentReference<Map<String, dynamic>> get _appSettings =>
      _firestore.collection('app_settings').doc('settings');
  static DocumentReference<Map<String, dynamic>> get _counters =>
      _firestore.collection('counters').doc('submission_ref');

  // ——— Users ———
  static Future<void> setUserProfile(UserProfile profile) async {
    await _users.doc(profile.uid).set(profile.toMap(), SetOptions(merge: true));
  }

  static Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (doc.data() == null) return null;
    return UserProfile.fromMap(uid, doc.data()!);
  }

  static Stream<DocumentSnapshot<Map<String, dynamic>>> userProfileStream(String uid) {
    return _users.doc(uid).snapshots();
  }

  // ——— Submissions ———
  static Stream<QuerySnapshot<Map<String, dynamic>>> submissionsStream() {
    return _submissions.orderBy('createdAt', descending: true).snapshots();
  }

  static Future<List<Submission>> getSubmissions() async {
    final snap = await _submissions.orderBy('createdAt', descending: true).get();
    return snap.docs.map((d) => Submission.fromDoc(d.id, d.data())).toList();
  }

  static Future<void> updateSubmissionStatus(String docId, String status) async {
    await _submissions.doc(docId).update({'status': status});
  }

  /// Returns next reference number: UCCICON26-01, UCCICON26-02, ...
  static Future<String> getNextReferenceNumber() async {
    return _firestore.runTransaction<String>((tx) async {
      final ref = await tx.get(_counters);
      int last = 0;
      if (ref.exists && ref.data() != null) {
        last = (ref.data()!['lastNumber'] as num?)?.toInt() ?? 0;
      }
      final next = last + 1;
      tx.set(_counters, {'lastNumber': next}, SetOptions(merge: true));
      return 'UCCICON26-${next.toString().padLeft(2, '0')}';
    });
  }

  static Future<String> addSubmission({
  required String uid,
  required String title,
  required String author,
  String? pdfUrl,
  String? extractedText,
  String? docBase64,
  String? docName,
  required String submissionType,
  String? referenceNumber,
}) async {
  final refNumber = referenceNumber ?? await getNextReferenceNumber();
  final docRef = _submissions.doc();

  final data = <String, dynamic>{
    'uid': uid,
    'referenceNumber': refNumber,
    'title': title,
    'author': author,
    'extractedText': extractedText ?? '',
    'status': 'pending',
    'submissionType': submissionType,
    'createdAt': FieldValue.serverTimestamp(),
  };

  // If a file URL from storage is provided, keep it for backward compat.
  if (pdfUrl != null && pdfUrl.isNotEmpty) {
    data['pdfUrl'] = pdfUrl;
  }

  // If the caller provided the document as base64, store it directly in the doc.
  if (docBase64 != null && docBase64.isNotEmpty) {
    data['docBase64'] = docBase64;
    if (docName != null && docName.isNotEmpty) {
      data['docName'] = docName;
    }
  }

  await docRef.set(data);
  return docRef.id;
}

  static Stream<QuerySnapshot<Map<String, dynamic>>> userSubmissionsStream(String uid) {
    return _submissions.where('uid', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();
  }

  /// Check if user has an accepted abstract submission.
  /// Returns true if user has at least one abstract with status 'accepted'.
  static Future<bool> hasAcceptedAbstract(String uid) async {
    final snap = await _submissions
        .where('uid', isEqualTo: uid)
        .where('submissionType', isEqualTo: 'abstract')
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// Get the user's accepted abstract submission (if any).
  static Future<Submission?> getAcceptedAbstract(String uid) async {
    final snap = await _submissions
        .where('uid', isEqualTo: uid)
        .where('submissionType', isEqualTo: 'abstract')
        .where('status', isEqualTo: 'accepted')
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Submission.fromDoc(snap.docs.first.id, snap.docs.first.data());
  }

  // ——— App settings ———
  static Stream<DocumentSnapshot<Map<String, dynamic>>> appSettingsStream() {
    return _appSettings.snapshots();
  }

  static Future<AppSettings> getAppSettings() async {
    final snap = await _appSettings.get();
    return AppSettings.fromMap(snap.data());
  }

  static Future<void> setAbstractSubmissionOpen(bool value) async {
    await _appSettings.set({'abstractSubmissionOpen': value}, SetOptions(merge: true));
  }

  static Future<void> setFullPaperSubmissionOpen(bool value) async {
    await _appSettings.set({'fullPaperSubmissionOpen': value}, SetOptions(merge: true));
  }

  static Future<void> updateAppSetting(String key, bool value) async {
    await _appSettings.set({key: value}, SetOptions(merge: true));
  }

  // ——— Full Paper Submission ———
  
  /// Add a full paper submission with multiple authors and PDF.
  static Future<String> addFullPaperSubmission({
    required String uid,
    required String title,
    required List<Map<String, dynamic>> authors,
    required String pdfUrl,
    String? referenceNumber,
  }) async {
    final refNumber = referenceNumber ?? await getNextReferenceNumber();
    final docRef = _submissions.doc();

    final data = <String, dynamic>{
      'uid': uid,
      'referenceNumber': refNumber,
      'title': title,
      'authors': authors,
      'pdfUrl': pdfUrl,
      'status': 'submitted',
      'submissionType': 'fullpaper',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await docRef.set(data);
    return docRef.id;
  }

  /// Update submission status with review comments (admin only).
  static Future<void> updateSubmissionStatusWithReview({
    required String docId,
    required String status,
    required String reviewedBy,
    String? reviewComments,
  }) async {
    final data = <String, dynamic>{
      'status': status,
      'reviewedBy': reviewedBy,
      'reviewedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (reviewComments != null && reviewComments.isNotEmpty) {
      data['reviewComments'] = reviewComments;
    }

    await _submissions.doc(docId).update(data);
  }

  /// Get a single submission by ID.
  static Future<Submission?> getSubmissionById(String docId) async {
    final doc = await _submissions.doc(docId).get();
    if (!doc.exists || doc.data() == null) return null;
    return Submission.fromDoc(doc.id, doc.data()!);
  }
}
