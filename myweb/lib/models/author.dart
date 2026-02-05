/// Author information for paper submissions.
/// Main author has all fields required; co-authors only need name and affiliation.
class Author {
  final String name;
  final String affiliation;
  final String? email; // Required only for main author
  final String? phone; // Required only for main author
  final bool isMainAuthor;

  Author({
    required this.name,
    required this.affiliation,
    this.email,
    this.phone,
    this.isMainAuthor = false,
  });

  factory Author.fromMap(Map<String, dynamic> map) {
    return Author(
      name: map['name'] as String? ?? '',
      affiliation: map['affiliation'] as String? ?? '',
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      isMainAuthor: map['isMainAuthor'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'affiliation': affiliation,
        'email': email,
        'phone': phone,
        'isMainAuthor': isMainAuthor,
      };

  Author copyWith({
    String? name,
    String? affiliation,
    String? email,
    String? phone,
    bool? isMainAuthor,
  }) {
    return Author(
      name: name ?? this.name,
      affiliation: affiliation ?? this.affiliation,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isMainAuthor: isMainAuthor ?? this.isMainAuthor,
    );
  }
}
