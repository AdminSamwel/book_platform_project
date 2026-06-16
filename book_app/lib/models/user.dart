class User {
  final int id;
  final String username;
  final String role;
  final String? bio;
  final String? avatar;
  final String? dateOfBirth;
  final int? age;

  User({required this.id, required this.username, required this.role, this.bio, this.avatar,
      this.dateOfBirth, this.age});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      bio: json['bio'],
      avatar: json['avatar'],
      dateOfBirth: json['date_of_birth'],
      age: (json['age'] is num) ? (json['age'] as num).toInt() : null,
    );
  }
}

