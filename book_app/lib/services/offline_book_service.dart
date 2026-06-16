import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Huduma ya kuhifadhi vitabu vilivyonunuliwa kwa matumizi ya nje ya mtandao (offline).
/// Kwenye web: hutumii path_provider (haitumiki web), badala yake hutumia
/// SharedPreferences (localStorage) kuhifadhi base64 ya maudhui ya vitabu vidogo.
/// Kwenye mobile/desktop: huhifadhi faili kwenye hifadhi ya ndani ya kifaa.
class OfflineBookService {
  static const String _indexKey = 'offline_books_index';
  static const int _maxWebCacheBytes = 5 * 1024 * 1024; // 5 MB limit kwa web

  static OfflineBookService? _instance;
  static OfflineBookService get instance => _instance ??= OfflineBookService._();
  OfflineBookService._();

  /// Hifadhi kitabu kwenye hifadhi ya ndani.
  /// [bookId] - ID ya kitabu, [bytes] - maudhui, [contentType] - aina ya faili,
  /// [title] - jina la kitabu.
  Future<bool> saveBook({
    required int bookId,
    required Uint8List bytes,
    required String contentType,
    required String title,
  }) async {
    try {
      if (kIsWeb) {
        return _saveWebBook(bookId: bookId, bytes: bytes,
            contentType: contentType, title: title);
      } else {
        return _saveNativeBook(bookId: bookId, bytes: bytes,
            contentType: contentType, title: title);
      }
    } catch (_) {
      return false;
    }
  }

  /// Pata maudhui ya kitabu kilichohifadhiwa. Inarudisha null kama hakipo.
  Future<Map<String, dynamic>?> getBook(int bookId) async {
    try {
      if (kIsWeb) {
        return _getWebBook(bookId);
      } else {
        return _getNativeBook(bookId);
      }
    } catch (_) {
      return null;
    }
  }

  /// Angalia kama kitabu kiko offline.
  Future<bool> isAvailableOffline(int bookId) async {
    final index = await _loadIndex();
    return index.containsKey('$bookId');
  }

  /// Pata orodha ya vitabu vilivyohifadhiwa.
  Future<List<Map<String, dynamic>>> listOfflineBooks() async {
    final index = await _loadIndex();
    return index.values.map((v) => Map<String, dynamic>.from(v as Map)).toList();
  }

  /// Futa kitabu kutoka hifadhi ya nje ya mtandao.
  Future<void> deleteBook(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _loadIndex();
    index.remove('$bookId');
    await prefs.setString(_indexKey, jsonEncode(index));

    if (!kIsWeb) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/offline_books/$bookId.bin');
        if (await file.exists()) await file.delete();
      } catch (_) {}
    } else {
      await prefs.remove('offline_book_$bookId');
    }
  }

  // ── Web implementation ──────────────────────────────────────────────────────

  Future<bool> _saveWebBook({
    required int bookId,
    required Uint8List bytes,
    required String contentType,
    required String title,
  }) async {
    if (bytes.length > _maxWebCacheBytes) return false;
    final prefs = await SharedPreferences.getInstance();
    final b64 = base64Encode(bytes);
    await prefs.setString('offline_book_$bookId', b64);
    await _updateIndex(bookId, {
      'book_id': bookId,
      'title': title,
      'content_type': contentType,
      'size': bytes.length,
      'cached_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<Map<String, dynamic>?> _getWebBook(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final b64 = prefs.getString('offline_book_$bookId');
    if (b64 == null) return null;
    final index = await _loadIndex();
    final meta = index['$bookId'];
    return {
      'bytes': base64Decode(b64),
      'content_type': (meta as Map?)?['content_type'] ?? 'text/plain',
    };
  }

  // ── Native (mobile/desktop) implementation ──────────────────────────────────

  Future<bool> _saveNativeBook({
    required int bookId,
    required Uint8List bytes,
    required String contentType,
    required String title,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/offline_books');
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File('${folder.path}/$bookId.bin');
    await file.writeAsBytes(bytes);
    await _updateIndex(bookId, {
      'book_id': bookId,
      'title': title,
      'content_type': contentType,
      'size': bytes.length,
      'path': file.path,
      'cached_at': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<Map<String, dynamic>?> _getNativeBook(int bookId) async {
    final index = await _loadIndex();
    final meta = index['$bookId'] as Map?;
    if (meta == null) return null;
    final path = meta['path'] as String?;
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    return {
      'bytes': await file.readAsBytes(),
      'content_type': meta['content_type'] ?? 'text/plain',
    };
  }

  // ── Index helpers ────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _updateIndex(int bookId, Map<String, dynamic> meta) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _loadIndex();
    index['$bookId'] = meta;
    await prefs.setString(_indexKey, jsonEncode(index));
  }
}
