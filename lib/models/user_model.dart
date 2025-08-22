// user_model.dart
enum UserType { buyer, admin }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserType userType;
  final String? profileImage;
  final DateTime? createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.userType,
    this.profileImage,
    this.createdAt,
  });

  // Helper methods
  bool get isAdmin => userType == UserType.admin;

  // Helper method to parse UserType from string
  static UserType _parseUserType(String? userTypeString) {
    if (userTypeString == null) return UserType.buyer;

    String cleanType = userTypeString.toLowerCase();
    if (cleanType.contains('admin')) return UserType.admin;
    if (cleanType.contains('buyer')) return UserType.buyer;

    try {
      return UserType.values.firstWhere(
        (type) => type.toString() == userTypeString,
        orElse: () => UserType.buyer,
      );
    } catch (e) {
      return UserType.buyer;
    }
  }

  // Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'userType': userType.toString(),
      'profileImage': profileImage,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  // Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      userType: _parseUserType(json['userType']),
      profileImage: json['profileImage'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  // Copy UserModel with updated fields
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    UserType? userType,
    String? profileImage,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      userType: userType ?? this.userType,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, phone: $phone, userType: $userType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
