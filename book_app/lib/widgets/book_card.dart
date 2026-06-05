import 'package:flutter/material.dart';
import '../models/book.dart';

class BookCard extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: book.coverImage != null
            ? Image.network(book.coverImage!, width: 50, fit: BoxFit.cover)
            : const Icon(Icons.book, size: 40),
        title: Text(book.title),
        subtitle: Text(book.authorName),
        trailing: Text(
          book.isFree ? 'Bure' : 'TZS ${book.price}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onTap: onTap,
      ),
    );
  }
}
