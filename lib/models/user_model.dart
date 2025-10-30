class User {
  final String firstName;
  final String lastName;
  final String avatar;
  final bool isAvailable;

  User({
    required this.firstName,
    required this.lastName,
    required this.avatar,
    this.isAvailable = true,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      avatar: json['avatar'] as String,
      isAvailable: json['is_available'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'first_name': firstName,
        'last_name': lastName,
        'avatar': avatar,
        'is_available': isAvailable,
      };
}
