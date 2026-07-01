import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted offline book cache — internal to the app only.
///
/// On web: content is XOR-encrypted with a device-specific key and stored
/// in SharedPreferences (browser localStorage). The raw bytes are never
/// accessible without the key stored in FlutterSecureStorage.
///
/// This is NOT a file export: there is no path on disk the user (or another
/// app) can open, share, or copy — [getBook] is the only way to read the
/// cached bytes back, and only [ReaderScreen] calls it, decrypting into
/// memory just long enough to render the page. Only purchased/free books are
/// ever written here (see `canDownload` in ReaderScreen) — books unlocked
/// through a monthly subscription are never cached and must be read online.
class OfflineBookService {
  static const String _indexKey    = 'offline_books_index';
  static const String _drmKeyId    = 'offline_drm_key';
  static const int    _nonceLen    = 16;
  // Max raw content size to cache (10 MB)
  static const int    _maxBytes    = 10 * 1024 * 1024;

  static OfflineBookService? _instance;
  static OfflineBookService get instance => _instance ??= OfflineBookService._();
  OfflineBookService._();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // ── Device key ────────────────────────────────────────────────────────────

  Future<List<int>> _getDeviceKey() async {
    var hex = await _storage.read(key: _drmKeyId);
    if (hex == null) {
      final rng = math.Random.secure();
      final raw = List<int>.generate(32, (_) => rng.nextInt(256));
      hex = raw.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      await _storage.write(key: _drmKeyId, value: hex);
    }
    final key = <int>[];
    for (int i = 0; i < hex.length; i += 2) {
      key.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return key;
  }

  // ── XOR encryption ────────────────────────────────────────────────────────
  // A 16-byte random nonce is prepended so identical books produce different
  // ciphertext on each save.  XOR(data, key, nonce) is fast for large PDFs.

  Future<Uint8List> _encrypt(Uint8List data) async {
    final key   = await _getDeviceKey();
    final rng   = math.Random.secure();
    final nonce = List<int>.generate(_nonceLen, (_) => rng.nextInt(256));
    final enc   = Uint8List(data.length);
    for (int i = 0; i < data.length; i++) {
      enc[i] = data[i] ^ key[i % key.length] ^ nonce[i % _nonceLen];
    }
    return Uint8List.fromList([...nonce, ...enc]);
  }

  Future<Uint8List> _decrypt(Uint8List blob) async {
    if (blob.length <= _nonceLen) throw Exception('Corrupted cache');
    final key   = await _getDeviceKey();
    final nonce = blob.sublist(0, _nonceLen);
    final enc   = blob.sublist(_nonceLen);
    final dec   = Uint8List(enc.length);
    for (int i = 0; i < enc.length; i++) {
      dec[i] = enc[i] ^ key[i % key.length] ^ nonce[i % _nonceLen];
    }
    return dec;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Encrypt and save a book. Returns false if content is too large.
  Future<bool> saveBook({
    required int    bookId,
    required Uint8List bytes,
    required String contentType,
    required String title,
  }) async {
    try {
      if (bytes.length > _maxBytes) return false;
      final prefs     = await SharedPreferences.getInstance();
      final encrypted = await _encrypt(bytes);
      final b64       = base64Encode(encrypted);
      await prefs.setString('offline_book_$bookId', b64);
      await _updateIndex(bookId, {
        'book_id':      bookId,
        'title':        title,
        'content_type': contentType,
        'size':         bytes.length,
        'cached_at':    DateTime.now().toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Decrypt and return cached book. Returns null if not available.
  Future<Map<String, dynamic>?> getBook(int bookId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final b64   = prefs.getString('offline_book_$bookId');
      if (b64 == null) return null;
      final encrypted = base64Decode(b64);
      final decrypted = await _decrypt(encrypted);
      final index     = await _loadIndex();
      final meta      = index['$bookId'] as Map?;
      return {
        'bytes':        decrypted,
        'content_type': meta?['content_type'] ?? 'text/plain',
        'title':        meta?['title'] ?? '',
      };
    } catch (_) {
      return null;
    }
  }

  Future<bool> isAvailableOffline(int bookId) async {
    final index = await _loadIndex();
    return index.containsKey('$bookId');
  }

  Future<List<Map<String, dynamic>>> listOfflineBooks() async {
    final index = await _loadIndex();
    return index.values
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
  }

  Future<void> deleteBook(int bookId) async {
    final prefs = await SharedPreferences.getInstance();
    final index = await _loadIndex();
    index.remove('$bookId');
    await prefs.setString(_indexKey, jsonEncode(index));
    await prefs.remove('offline_book_$bookId');
  }

  // ── Index helpers ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _loadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_indexKey);
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
