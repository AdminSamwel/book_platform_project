import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/book.dart';

class BookProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  List<Book> _books = [];
  List<Book> _myLibrary = [];
  List<Book> _bestSellers = [];
  List<Book> _forYou = [];
  bool _isLoading = false;

  List<Book> get books => _books;
  List<Book> get myLibrary => _myLibrary;
  List<Book> get bestSellers => _bestSellers;
  List<Book> get forYou => _forYou;
  bool get isLoading => _isLoading;

  Future<void> fetchBooks({String? categorySlug, bool? isFree, String? search,
      bool? forYou, String? ordering}) async {
    _isLoading = true; notifyListeners();
    try {
      final results = await _api.fetchBooks(categorySlug: categorySlug,
          isFree: isFree, search: search, forYou: forYou, ordering: ordering);
      _books = results.map((json) => Book.fromJson(json)).toList();
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  /// Vitabu vinavyosomwa/vinavyonunuliwa zaidi ("Best Sellers")
  Future<void> fetchBestSellers() async {
    try {
      final results = await _api.fetchBooks(ordering: '-purchases_count');
      _bestSellers = results.take(5).map((json) => Book.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  /// Vitabu vya makundi anayopenda msomaji ("For You")
  Future<void> fetchForYou() async {
    try {
      final results = await _api.fetchBooks(forYou: true);
      _forYou = results.map((json) => Book.fromJson(json)).toList();
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
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

  Future<Map<String, dynamic>> purchaseBook(int bookId) async {
    final res = await _api.purchaseBook(bookId);
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body);
      throw Exception(body['detail'] ?? 'Imeshindwa kununua');
    }
    await fetchMyLibrary();
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

