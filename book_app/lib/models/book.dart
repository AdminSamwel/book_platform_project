class Book {
  final int id;
  final String title;
  final String authorName;
  final double price;
  final bool isFree;
  final String? coverImage;
  final String? categoryName;
  final String? description;
  final double avgRating;
  final int ratingsCount;
  final int purchasesCount;
  final bool isLocked;
  final String? requiredPlanName;
  final int minAge;
  final bool isAgeRestricted;

  Book({
    required this.id,
    required this.title,
    required this.authorName,
    required this.price,
    required this.isFree,
    this.coverImage,
    this.categoryName,
    this.description,
    this.avgRating = 0,
    this.ratingsCount = 0,
    this.purchasesCount = 0,
    this.isLocked = false,
    this.requiredPlanName,
    this.minAge = 0,
    this.isAgeRestricted = false,
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
      avgRating: (json['avg_rating'] is num)
          ? (json['avg_rating'] as num).toDouble() : 0,
      ratingsCount: (json['ratings_count'] is num)
          ? (json['ratings_count'] as num).toInt() : 0,
      purchasesCount: (json['purchases_count'] is num)
          ? (json['purchases_count'] as num).toInt() : 0,
      isLocked: json['is_locked'] ?? false,
      requiredPlanName: json['required_plan_name'],
      minAge: (json['min_age'] is num) ? (json['min_age'] as num).toInt() : 0,
      isAgeRestricted: json['is_age_restricted'] ?? false,
    );
  }
}
