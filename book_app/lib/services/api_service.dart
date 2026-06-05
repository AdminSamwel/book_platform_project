import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://192.168.3.57:8000/api/';

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  // ========== HEADERS + TOKEN AUTO-REFRESH ==========
  Future<Map<String, String>> _getHeaders() async {
    String? token = await storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> _getWithRefresh(String url) async {
    var res = await http.get(Uri.parse(url), headers: await _getHeaders());
    if (res.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        res = await http.get(Uri.parse(url), headers: await _getHeaders());
      }
    }
    return res;
  }

  Future<http.Response> _postWithRefresh(String url, {Object? body}) async {
    var res = await http.post(Uri.parse(url),
        body: body != null ? jsonEncode(body) : null,
        headers: await _getHeaders());
    if (res.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        res = await http.post(Uri.parse(url),
            body: body != null ? jsonEncode(body) : null,
            headers: await _getHeaders());
      }
    }
    return res;
  }

  Future<bool> _refreshToken() async {
    final refresh = await storage.read(key: 'refresh_token');
    if (refresh == null) return false;
    final res = await http.post(
      Uri.parse('${baseUrl}token/refresh/'),
      body: jsonEncode({'refresh': refresh}),
      headers: {'Content-Type': 'application/json'},
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await storage.write(key: 'access_token', value: data['access']);
      return true;
    }
    await storage.deleteAll();
    return false;
  }

  // ========== AUTH ==========
  Future<http.Response> login(String username, String password) async {
    return http.post(
      Uri.parse('${baseUrl}token/'),
      body: jsonEncode({'username': username, 'password': password}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<http.Response> register(
      String username, String password, String role) async {
    return http.post(
      Uri.parse('${baseUrl}users/register/'),
      body: jsonEncode(
          {'username': username, 'password': password, 'role': role}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ========== PROFILE ==========
  Future<Map<String, dynamic>> fetchProfile() async {
    final res = await _getWithRefresh('${baseUrl}users/profile/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia wasifu');
  }

  Future<http.Response> updateProfile({String? bio}) async {
    return _postWithRefresh('${baseUrl}users/profile/',
        body: {'bio': bio ?? ''});
  }

  // ========== VITABU ==========
  Future<List<dynamic>> fetchBooks(
      {String? categorySlug, bool? isFree, String? search}) async {
    String url = '${baseUrl}books/?';
    if (categorySlug != null) url += 'category__slug=$categorySlug&';
    if (isFree != null) url += 'is_free=${isFree ? 'true' : 'false'}&';
    if (search != null && search.isNotEmpty) {
      url += 'search=${Uri.encodeComponent(search)}&';
    }
    final res = await _getWithRefresh(url);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      // API may return paginated {results:[...]} or plain list
      if (body is Map && body.containsKey('results')) return body['results'];
      return body as List;
    }
    throw Exception('Imeshindwa kupakia vitabu');
  }

  Future<Map<String, dynamic>> fetchBookDetail(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia maelezo');
  }

  Future<String> fetchBookContent(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/content/');
    if (res.statusCode == 200) return res.body;
    if (res.statusCode == 403) {
      throw Exception('Huna ruhusa. Nunua au jisajili.');
    }
    throw Exception('Imeshindwa kupakia maudhui');
  }

  Future<List<dynamic>> fetchCategories() async {
    final res = await _getWithRefresh('${baseUrl}books/categories/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia kategoria');
  }

  Future<http.Response> uploadBook({
    required String title,
    required String description,
    required String price,
    required bool isFree,
    required File bookFile,
    File? coverImage,
    int? categoryId,
  }) async {
    final token = await storage.read(key: 'access_token');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${baseUrl}books/create/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['title'] = title;
    request.fields['description'] = description;
    request.fields['price'] = price;
    request.fields['is_free'] = isFree.toString();
    request.fields['is_published'] = 'true';
    if (categoryId != null) request.fields['category'] = categoryId.toString();
    request.files.add(await http.MultipartFile.fromPath(
      'raw_file',
      bookFile.path,
      contentType: MediaType('application', 'octet-stream'),
    ));
    if (coverImage != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'cover_image',
        coverImage.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  // ========== MANUNUZI ==========
  Future<http.Response> purchaseBook(int bookId) async {
    return _postWithRefresh('${baseUrl}payments/purchase/$bookId/');
  }

  Future<List<dynamic>> fetchMyLibrary() async {
    final res = await _getWithRefresh('${baseUrl}payments/mylibrary/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia maktaba');
  }

  // ========== WALLET ==========
  Future<Map<String, dynamic>> fetchWallet() async {
    final res = await _getWithRefresh('${baseUrl}wallet/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia mizania');
  }

  Future<http.Response> topUpWallet(double amount) async {
    return _postWithRefresh('${baseUrl}wallet/topup/',
        body: {'amount': amount.toString()});
  }

  // ========== USAJILI ==========
  Future<List<dynamic>> fetchPlans() async {
    final res = await _getWithRefresh('${baseUrl}subscriptions/plans/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia mipango');
  }

  Future<http.Response> subscribe(int planId) async {
    return _postWithRefresh('${baseUrl}subscriptions/subscribe/$planId/');
  }

  Future<Map<String, dynamic>?> fetchActiveSubscription() async {
    final res = await _getWithRefresh('${baseUrl}subscriptions/active/');
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      if (body == null || body is Map && body.isEmpty) return null;
      return body as Map<String, dynamic>;
    }
    return null;
  }

  // ========== MAONI ==========
  Future<List<dynamic>> fetchComments(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}comments/$bookId/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia maoni');
  }

  Future<http.Response> postComment(int bookId, String text) async {
    return _postWithRefresh('${baseUrl}comments/$bookId/',
        body: {'text': text});
  }
}
