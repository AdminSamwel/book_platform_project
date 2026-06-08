class Book {
  final int id;
  final String title;
  final String authorName;
  final double price;
  final bool isFree;
  final String? coverImage;
  final String? categoryName;
  final String? description;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    required this.price,
    required this.isFree,
    this.coverImage,
    this.categoryName,
    this.description,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'],
      title: json['title'],
      authorName: json['author_name'] ?? '',
      price: double.parse(json['price'] ?? '0'),
      isFree: json['is_free'] ?? false,
      coverImage: json['cover_image'],
      categoryName: json['category_name'],
      description: json['description'],
    );
  }
}
