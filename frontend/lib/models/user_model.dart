class User {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final DateTime createdAt;
  final String? profilePicture;
  final bool isActive;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.createdAt,
    this.profilePicture,
    this.isActive = true,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle different ID field formats
    String userId = '';
    if (json.containsKey('_id')) {
      userId = json['_id'].toString();
    } else if (json.containsKey('id')) {
      userId = json['id'].toString();
    } else if (json.containsKey('user_id')) {
      userId = json['user_id'].toString();
    }

    // Handle date field
    DateTime createdDate;
    try {
      createdDate = json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now();
    } catch (e) {
      createdDate = DateTime.now();
    }

    return User(
      id: userId,
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      role: json['role'] ?? 'user',
      profilePicture: json['profile_picture'],
      isActive: json['is_active'] ?? true,
      createdAt: createdDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'profile_picture': profilePicture,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? profilePicture,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
