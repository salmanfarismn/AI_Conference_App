/// User profile stored in Firestore `users` collection.
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role; // 'student' | 'scholar'
  final String? institution;
  final String paymentStatus; // 'none' | 'pending' | 'verified' | 'rejected'
  final String? receiptUrl;
  final String? idCardUrl;
  final String? paymentRejectionReason;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.institution,
    this.paymentStatus = 'none',
    this.receiptUrl,
    this.idCardUrl,
    this.paymentRejectionReason,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> map) {
    return UserProfile(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      role: map['role'] as String? ?? 'student',
      institution: map['institution'] as String?,
      paymentStatus: map['paymentStatus'] as String? ?? 'none',
      receiptUrl: map['receiptUrl'] as String?,
      idCardUrl: map['idCardUrl'] as String?,
      paymentRejectionReason: map['paymentRejectionReason'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'institution': institution,
        'paymentStatus': paymentStatus,
        'receiptUrl': receiptUrl,
        'idCardUrl': idCardUrl,
        'paymentRejectionReason': paymentRejectionReason,
      };
}
