import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/book.dart';

class BookProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  List<Book> _books = [];
  List<Book> _myLibrary = [];
  bool _isLoading = false;

  List<Book> get books => _books;
  List<Book> get myLibrary => _myLibrary;
  bool get isLoading => _isLoading;

  Future<void> fetchBooks({String? categorySlug, bool? isFree}) async {
    _isLoading = true; notifyListeners();
    try {
      final results = await _api.fetchBooks(categorySlug: categorySlug, isFree: isFree);
      _books = results.map((json) => Book.fromJson(json)).toList();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<Map<String, dynamic>> fetchBookDetail(int bookId) async {
    return await _api.fetchBookDetail(bookId);
  }

  Future<String> fetchBookContent(int bookId) async {
    return await _api.fetchBookContent(bookId);
  }

  Future<void> fetchMyLibrary() async {
    _isLoading = true; notifyListeners();
    try {
      final results = await _api.fetchMyLibrary();
      // mylibrary returns list of purchase objects, each has 'book' field
      _myLibrary = results.map((p) => Book.fromJson(p['book'])).toList();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  Future<void> purchaseBook(int bookId) async {
    final res = await _api.purchaseBook(bookId);
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Imeshindwa kununua');
    }
    await fetchMyLibrary();
  }
}