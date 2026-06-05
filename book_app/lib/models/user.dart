class User {
  final int id;
  final String username;
  final String role;
  final String? bio;
  final String? avatar;

  User({required this.id, required this.username, required this.role, this.bio, this.avatar});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      bio: json['bio'],
      avatar: json['avatar'],
    );
  }
}