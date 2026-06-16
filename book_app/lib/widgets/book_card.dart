import 'package:flutter/material.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';
import 'safe_image.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: safeNetworkImage(book.coverImage, width: 50, height: 60),
        ),
        title: Text(book.title,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(book.authorName,
            style: TextStyle(color: AppTheme.textSecondary(context))),
        trailing: Text(
          book.isFree ? 'Bure' : 'TZS ${book.price}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: book.isFree ? AppTheme.success : AppTheme.primary,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
