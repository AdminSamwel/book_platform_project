import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api/';

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  /// Pata host ya msingi (bila '/api/') - inatumika kujenga link za
  /// kushare ukurasa wa kitabu (Open Graph landing page).
  static String shareHost() => baseUrl.replaceFirst(RegExp(r'api/?$'), '');

  // ========== HEADERS + TOKEN AUTO-REFRESH ==========
  Future<Map<String, String>> _getHeaders() async {
    String? token = await storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// DRF inaweza kurudisha orodha moja kwa moja AU ukurasa wenye
  /// 'results' (PageNumberPagination): { count, next, previous, results: [...] }
  List<dynamic> _asList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['results'] is List) {
      return decoded['results'] as List<dynamic>;
    }
    return [];
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

  Future<http.Response> _patchWithRefresh(String url, {Object? body}) async {
    var res = await http.patch(Uri.parse(url),
        body: body != null ? jsonEncode(body) : null,
        headers: await _getHeaders());
    if (res.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        res = await http.patch(Uri.parse(url),
            body: body != null ? jsonEncode(body) : null,
            headers: await _getHeaders());
      }
    }
    return res;
  }

  Future<http.Response> _deleteWithRefresh(String url) async {
    var res = await http.delete(Uri.parse(url), headers: await _getHeaders());
    if (res.statusCode == 401) {
      final refreshed = await _refreshToken();
      if (refreshed) {
        res = await http.delete(Uri.parse(url), headers: await _getHeaders());
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

  /// Usajili mpya kwa kutumia email AU namba ya simu kama [identifier].
  /// [referredByBookId] (hiari) - kitabu kilichoshirikiwa (share) ambacho
  /// kilimleta mtumiaji huyu kwenye usajili.
  Future<http.Response> register(
      String identifier, String password, String role,
      {List<int>? categoryIds, String? dateOfBirth, int? referredByBookId}) async {
    return http.post(
      Uri.parse('${baseUrl}users/register/'),
      body: jsonEncode({
        'identifier': identifier,
        'password': password,
        'role': role,
        if (categoryIds != null && categoryIds.isNotEmpty)
          'category_ids': categoryIds,
        if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
        if (referredByBookId != null) 'referred_by_book_id': referredByBookId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Thibitisha akaunti mpya kwa nambari ya OTP iliyotumwa kwa email.
  Future<http.Response> verifyOtp(String identifier, String code) async {
    return http.post(
      Uri.parse('${baseUrl}users/verify-otp/'),
      body: jsonEncode({'identifier': identifier, 'code': code}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Tuma tena nambari ya OTP kwa akaunti isiyothibitishwa bado.
  Future<http.Response> resendOtp(String identifier) async {
    return http.post(
      Uri.parse('${baseUrl}users/resend-otp/'),
      body: jsonEncode({'identifier': identifier}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Ingia/Jisajili kwa akaunti ya Google kwa kutumia ID token.
  Future<http.Response> googleAuth(String idToken, {int? referredByBookId}) async {
    return http.post(
      Uri.parse('${baseUrl}users/google-auth/'),
      body: jsonEncode({
        'id_token': idToken,
        if (referredByBookId != null) 'referred_by_book_id': referredByBookId,
      }),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ========== MAKUNDI ANAYOPENDA MSOMAJI ==========
  Future<Map<String, dynamic>> fetchFavoriteCategories() async {
    final res = await _getWithRefresh('${baseUrl}users/favorite-categories/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia makundi unayopenda');
  }

  Future<Map<String, dynamic>> updateFavoriteCategories(List<int> categoryIds) async {
    final res = await _patchWithRefresh('${baseUrl}users/favorite-categories/',
        body: {'category_ids': categoryIds});
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kuhifadhi makundi');
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

  /// Sasisha tarehe ya kuzaliwa ya mtumiaji — inatumika kuangalia
  /// kama anaweza kufungua vitabu vyenye kikomo cha umri.
  Future<http.Response> updateDateOfBirth(String dateOfBirth) async {
    return _patchWithRefresh('${baseUrl}users/profile/',
        body: {'date_of_birth': dateOfBirth});
  }

  /// Sasisha wasifu (bio na/au picha ya profaili - avatar) kwa pamoja.
  /// Inatumia multipart kwa sababu avatar ni faili la picha.
  Future<http.Response> updateProfileMultipart({
    String? bio,
    Uint8List? avatarBytes,
    String? avatarFileName,
  }) async {
    final token = await storage.read(key: 'access_token');
    const url = '${baseUrl}users/profile/';
    final request = http.MultipartRequest('PATCH', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';

    if (bio != null) request.fields['bio'] = bio;

    if (avatarBytes != null) {
      final ext = (avatarFileName ?? 'avatar.jpg').split('.').last.toLowerCase();
      request.files.add(http.MultipartFile.fromBytes(
        'avatar', avatarBytes,
        filename: avatarFileName ?? 'avatar.jpg',
        contentType: MediaType('image', ext == 'png' ? 'png' : 'jpeg'),
      ));
    }

    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// Badilisha nenosiri la mtumiaji aliyeingia.
  Future<http.Response> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    return _postWithRefresh('${baseUrl}users/change-password/', body: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  // ========== VITABU ==========
  Future<List<dynamic>> fetchBooks(
      {String? categorySlug, bool? isFree, String? search,
       bool? forYou, String? ordering}) async {
    String url = '${baseUrl}books/?';
    if (categorySlug != null) url += 'category__slug=$categorySlug&';
    if (isFree != null) url += 'is_free=${isFree ? 'true' : 'false'}&';
    if (search != null && search.isNotEmpty) {
      url += 'search=${Uri.encodeComponent(search)}&';
    }
    if (forYou == true) url += 'for_you=true&';
    if (ordering != null) url += 'ordering=$ordering&';
    final res = await _getWithRefresh(url);
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      // API may return paginated {results:[...]} or plain list
      if (body is Map && body.containsKey('results')) return body['results'];
      return body as List;
    }
    throw Exception('Imeshindwa kupakia vitabu');
  }

  // ========== TATHMINI / RATINGS ==========
  Future<List<dynamic>> fetchBookRatings(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/ratings/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia tathmini');
  }

  Future<Map<String, dynamic>?> fetchMyRating(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/rate/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    if (res.statusCode == 404) return null;
    throw Exception('Imeshindwa kupakia tathmini yako');
  }

  Future<Map<String, dynamic>> submitRating(int bookId, int score, String comment) async {
    final res = await _postWithRefresh('${baseUrl}books/$bookId/rate/',
        body: {'score': score, 'comment': comment});
    if (res.statusCode == 200 || res.statusCode == 201) return jsonDecode(res.body);
    final body = jsonDecode(res.body);
    throw Exception(body['detail'] ?? 'Imeshindwa kuhifadhi tathmini');
  }

  Future<Map<String, dynamic>> fetchBookDetail(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia maelezo');
  }

  /// Pata vitabu vyote vya mwandishi (hata visivyochapishwa)
  Future<List<dynamic>> fetchMyBooks() async {
    final res = await _getWithRefresh('${baseUrl}books/my-books/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia vitabu vyako');
  }

  /// Takwimu za kushare kitabu (clicks kwa kila mtandao + idadi ya
  /// watu walioandikishwa kupitia link ya kushare).
  Future<Map<String, dynamic>> fetchBookShareStats(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/share-stats/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia takwimu za kushare');
  }

  /// Pata taarifa za kitabu kwa mwandishi
  Future<Map<String, dynamic>> fetchBookForEdit(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/edit/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia taarifa za kitabu');
  }

  /// Hariri taarifa za kitabu
  Future<Map<String, dynamic>> updateBook({
    required int bookId,
    String? title,
    String? description,
    String? price,
    bool? isFree,
    int? categoryId,
    bool? isPublished,
    Uint8List? coverBytes,
    String? coverFileName,
    Uint8List? bookBytes,
    String? bookFileName,
    Uint8List? audioBytes,
    String? audioFileName,
    int? minPlanLevel,
    int? minAge,
  }) async {
    final token   = await storage.read(key: 'access_token');
    final url     = '${baseUrl}books/$bookId/edit/';
    final request = http.MultipartRequest('PATCH', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';

    if (title != null)       request.fields['title']        = title;
    if (description != null) request.fields['description']  = description;
    if (price != null)       request.fields['price']        = price;
    if (isFree != null)      request.fields['is_free']      = isFree.toString();
    if (isPublished != null) request.fields['is_published'] = isPublished.toString();
    if (categoryId != null)  request.fields['category']     = categoryId.toString();
    if (minPlanLevel != null) request.fields['min_plan_level'] = minPlanLevel.toString();
    if (minAge != null)      request.fields['min_age']      = minAge.toString();

    if (coverBytes != null) {
      final ext  = (coverFileName ?? 'cover.jpg').split('.').last.toLowerCase();
      request.files.add(http.MultipartFile.fromBytes(
        'cover_image', coverBytes,
        filename: coverFileName ?? 'cover.jpg',
        contentType: MediaType('image', ext == 'png' ? 'png' : 'jpeg'),
      ));
    }

    if (bookBytes != null) {
      final ext = (bookFileName ?? 'book.pdf').split('.').last.toLowerCase();
      final ct  = ext == 'pdf' ? MediaType('application', 'pdf')
          : ext == 'epub' ? MediaType('application', 'epub+zip')
          : MediaType('text', 'plain');
      request.files.add(http.MultipartFile.fromBytes(
        'raw_file', bookBytes,
        filename: bookFileName ?? 'book.pdf',
        contentType: ct,
      ));
    }

    if (audioBytes != null) {
      final ext  = (audioFileName ?? 'audio.mp3').split('.').last.toLowerCase();
      final mime = ext == 'wav' ? 'wav' : ext == 'ogg' ? 'ogg'
          : ext == 'm4a' ? 'mp4' : 'mpeg';
      request.files.add(http.MultipartFile.fromBytes(
        'audio_file', audioBytes,
        filename: audioFileName ?? 'audio.mp3',
        contentType: MediaType('audio', mime),
      ));
    }

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Hitilafu ya kuhariri: ${response.body}');
  }

  Future<String> fetchBookContent(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/content/');
    if (res.statusCode == 200) return res.body;
    if (res.statusCode == 403) throw Exception('Huna ruhusa. Nunua au jisajili.');
    throw Exception('Imeshindwa kupakia maudhui');
  }

  // Pata bytes za sauti ya kitabu
  Future<Map<String, dynamic>> fetchAudioBytes(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/audio/');
    if (res.statusCode == 200) {
      return {
        'bytes':        res.bodyBytes,
        'content_type': res.headers['content-type'] ?? 'audio/mpeg',
      };
    }
    if (res.statusCode == 403) throw Exception('Huna ruhusa ya kusikiliza.');
    if (res.statusCode == 404) throw Exception('Kitabu hiki hakina sauti.');
    throw Exception('Imeshindwa kupakia sauti');
  }

  // Pata bytes za kitabu pamoja na content-type
  Future<Map<String, dynamic>> fetchBookBytes(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}books/$bookId/content/');
    if (res.statusCode == 200) {
      return {
        'bytes': res.bodyBytes,
        'content_type': res.headers['content-type'] ?? 'text/plain',
      };
    }
    if (res.statusCode == 403) throw Exception('Huna ruhusa. Nunua au jisajili.');
    throw Exception('Imeshindwa kupakia maudhui');
  }

  Future<List<dynamic>> fetchCategories() async {
    final res = await _getWithRefresh('${baseUrl}books/categories/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
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

  // ========== MAKTABA (SAVED BOOKS) ==========

  Future<List<dynamic>> fetchLibrary() async {
    final res = await _getWithRefresh('${baseUrl}library/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia maktaba');
  }

  Future<bool> saveBook(int bookId) async {
    final res = await _postWithRefresh('${baseUrl}library/$bookId/save/');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body)['saved'] == true;
    }
    throw Exception('Imeshindwa kuhifadhi kitabu');
  }

  Future<bool> removeFromLibrary(int bookId) async {
    final token = await storage.read(key: 'access_token');
    final res = await http.delete(
      Uri.parse('${baseUrl}library/$bookId/save/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) return false;
    throw Exception('Imeshindwa kutoa kitabu');
  }

  Future<bool> checkSaved(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}library/$bookId/saved/');
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['saved'] == true;
    }
    return false;
  }

  // ========== WISHLIST ==========
  Future<List<dynamic>> fetchWishlist() async {
    final res = await _getWithRefresh('${baseUrl}library/wishlist/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia Wishlist');
  }

  Future<bool> addToWishlist(int bookId) async {
    final res = await _postWithRefresh('${baseUrl}library/wishlist/$bookId/');
    if (res.statusCode == 200 || res.statusCode == 201) {
      return jsonDecode(res.body)['in_wishlist'] == true;
    }
    throw Exception('Imeshindwa kuongeza kwenye Wishlist');
  }

  Future<bool> removeFromWishlist(int bookId) async {
    final res = await _deleteWithRefresh('${baseUrl}library/wishlist/$bookId/');
    if (res.statusCode == 200) return false;
    throw Exception('Imeshindwa kutoa kwenye Wishlist');
  }

  Future<bool> checkWishlist(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}library/wishlist/$bookId/check/');
    if (res.statusCode == 200) {
      return jsonDecode(res.body)['in_wishlist'] == true;
    }
    return false;
  }

  // ========== CART (KIKAPU) NA BILI ==========
  Future<Map<String, dynamic>> fetchCart() async {
    final res = await _getWithRefresh('${baseUrl}payments/cart/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia kikapu');
  }

  Future<void> addToCart(int bookId) async {
    final res = await _postWithRefresh('${baseUrl}payments/cart/$bookId/');
    if (res.statusCode == 200 || res.statusCode == 201) return;
    final data = jsonDecode(res.body);
    throw Exception(data['detail'] ?? 'Imeshindwa kuongeza kwenye kikapu');
  }

  Future<void> removeFromCart(int bookId) async {
    final res = await _deleteWithRefresh('${baseUrl}payments/cart/$bookId/');
    if (res.statusCode == 200) return;
    throw Exception('Imeshindwa kutoa kwenye kikapu');
  }

  /// Lipia vitabu vya kikapu. Kama [bookIds] ni null, vitabu VYOTE
  /// vitalipiwa (jumla ya bili). Vinginevyo ni bei ya vile vilivyochaguliwa.
  Future<Map<String, dynamic>> checkoutCart({List<int>? bookIds}) async {
    final res = await _postWithRefresh(
      '${baseUrl}payments/cart/checkout/',
      body: bookIds != null ? {'book_ids': bookIds} : {},
    );
    final data = jsonDecode(res.body);
    if (res.statusCode == 201) return data;
    throw Exception(data['detail'] ?? 'Imeshindwa kukamilisha malipo');
  }

  // ========== WASOMAJI WA MWANDISHI ==========
  Future<Map<String, dynamic>> fetchAuthorReaders() async {
    final res = await _getWithRefresh('${baseUrl}payments/my-readers/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia takwimu za wasomaji');
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
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
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

  Future<Map<String, dynamic>> fetchSystemSettings() async {
    final res = await _getWithRefresh('${baseUrl}subscriptions/settings/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia mipangilio');
  }

  Future<Map<String, dynamic>> updateSystemSettings(Map<String, dynamic> data) async {
    final res = await _patchWithRefresh(
        '${baseUrl}subscriptions/settings/', body: data);
    if (res.statusCode == 200) return jsonDecode(res.body);
    final body = jsonDecode(res.body);
    throw Exception(body['detail'] ?? 'Imeshindwa kuhifadhi mipangilio (${res.statusCode})');
  }

  Future<Map<String, dynamic>> fetchFreeBookSelection() async {
    final res = await _getWithRefresh('${baseUrl}subscriptions/free-book-selection/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia uchaguzi wa kitabu');
  }

  Future<Map<String, dynamic>> selectFreeBook(int bookId) async {
    final res = await _postWithRefresh(
        '${baseUrl}subscriptions/free-book-selection/',
        body: {'book_id': bookId});
    if (res.statusCode == 201) return jsonDecode(res.body);
    final body = jsonDecode(res.body);
    throw Exception(body['detail'] ?? 'Imeshindwa kuchagua kitabu (${res.statusCode})');
  }

  Future<Map<String, dynamic>> fetchSubscriptionUsage() async {
    final res = await _getWithRefresh('${baseUrl}subscriptions/usage/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia matumizi ya usajili');
  }

  // ========== MAONI / COMMENTS ==========
  Future<List<dynamic>> fetchComments(int bookId) async {
    final res = await _getWithRefresh('${baseUrl}comments/$bookId/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia maoni');
  }

  Future<Map<String, dynamic>> postComment(
      int bookId, String text, {int? parentId}) async {
    final body = <String, dynamic>{'text': text};
    if (parentId != null) body['parent'] = parentId;
    final res = await _postWithRefresh(
        '${baseUrl}comments/$bookId/', body: body);
    if (res.statusCode == 201) return jsonDecode(res.body);
    throw Exception('Imeshindwa kutuma maoni (${res.statusCode})');
  }

  Future<void> deleteComment(int bookId, int commentId) async {
    final token = await storage.read(key: 'access_token');
    final res   = await http.delete(
      Uri.parse('${baseUrl}comments/$bookId/$commentId/delete/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 204) {
      throw Exception('Imeshindwa kufuta (${res.statusCode})');
    }
  }

  Future<List<dynamic>> reactToComment(
      int bookId, int commentId, String emoji) async {
    final token = await storage.read(key: 'access_token');
    final res   = await http.post(
      Uri.parse('${baseUrl}comments/$bookId/$commentId/react/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type':  'application/json',
      },
      body: jsonEncode({'emoji': emoji}),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(res.body) as Map)['reactions'] as List;
    }
    throw Exception('Imeshindwa ku-react');
  }

  /// Ripoti ujumbe (kwa lugha chafu, unyanyasaji n.k)
  Future<Map<String, dynamic>> reportComment(
      int bookId, int commentId, String reason, {String details = ''}) async {
    final res = await _postWithRefresh(
      '${baseUrl}comments/$bookId/$commentId/report/',
      body: {'reason': reason, 'details': details},
    );
    if (res.statusCode == 201) return jsonDecode(res.body);
    if (res.statusCode == 400) {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Tayari umeripoti ujumbe huu.');
    }
    throw Exception('Imeshindwa kuripoti ujumbe (${res.statusCode})');
  }

  // ========== ARIFA / NOTIFICATIONS ==========
  Future<List<dynamic>> fetchNotifications() async {
    final res = await _getWithRefresh('${baseUrl}comments/notifications/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia arifa');
  }

  Future<int> fetchUnreadNotificationCount() async {
    final res = await _getWithRefresh('${baseUrl}comments/notifications/unread-count/');
    if (res.statusCode == 200) {
      return (jsonDecode(res.body)['unread_count'] as num).toInt();
    }
    return 0;
  }

  Future<void> markNotificationRead(int notifId) async {
    await _postWithRefresh('${baseUrl}comments/notifications/$notifId/read/');
  }

  Future<void> markAllNotificationsRead() async {
    await _postWithRefresh('${baseUrl}comments/notifications/read-all/');
  }

  /// Mwandishi anatuma ujumbe kwa wasomaji wote wa kitabu (waliokinunua au
  /// wenye usajili hai). Inarudisha idadi ya watu walipokea ujumbe.
  Future<int> broadcastToReaders(int bookId, String message) async {
    final res = await _postWithRefresh(
      '${baseUrl}comments/$bookId/broadcast/',
      body: {'message': message},
    );
    if (res.statusCode == 201) {
      return (jsonDecode(res.body)['sent_to'] as num).toInt();
    }
    if (res.statusCode == 400 || res.statusCode == 403) {
      final data = jsonDecode(res.body);
      throw Exception(data['detail'] ?? 'Imeshindwa kutuma ujumbe');
    }
    throw Exception('Imeshindwa kutuma ujumbe (${res.statusCode})');
  }

  // ========== ADMIN PANEL ==========
  Future<Map<String, dynamic>> fetchAdminStats() async {
    final res = await _getWithRefresh('${baseUrl}admin-panel/stats/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia takwimu');
  }

  Future<List<dynamic>> fetchAdminUsers({String? search, String? role}) async {
    String url = '${baseUrl}admin-panel/users/?';
    if (search != null && search.isNotEmpty) url += 'search=$search&';
    if (role != null && role.isNotEmpty) url += 'role=$role&';
    final res = await _getWithRefresh(url);
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia watumiaji');
  }

  Future<Map<String, dynamic>> toggleUserBan(int userId, {String? reason}) async {
    final res = await _postWithRefresh('${baseUrl}admin-panel/users/$userId/ban/',
        body: {'reason': reason ?? ''});
    if (res.statusCode == 200) return jsonDecode(res.body);
    final data = jsonDecode(res.body);
    throw Exception(data['detail'] ?? 'Imeshindwa kubadilisha hali ya mtumiaji');
  }

  Future<List<dynamic>> fetchAdminBooks({String? search, bool? published}) async {
    String url = '${baseUrl}admin-panel/books/?';
    if (search != null && search.isNotEmpty) url += 'search=$search&';
    if (published != null) url += 'published=$published&';
    final res = await _getWithRefresh(url);
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia vitabu');
  }

  Future<Map<String, dynamic>> toggleBookPublish(int bookId) async {
    final res = await _postWithRefresh('${baseUrl}admin-panel/books/$bookId/toggle/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kubadilisha hali ya kitabu');
  }

  Future<void> deleteAdminBook(int bookId) async {
    final res = await _deleteWithRefresh('${baseUrl}admin-panel/books/$bookId/delete/');
    if (res.statusCode != 204) throw Exception('Imeshindwa kufuta kitabu');
  }

  Future<List<dynamic>> fetchAdminPlans() async {
    final res = await _getWithRefresh('${baseUrl}admin-panel/plans/');
    if (res.statusCode == 200) return _asList(jsonDecode(res.body));
    throw Exception('Imeshindwa kupakia mipango');
  }

  Future<Map<String, dynamic>> updateAdminPlan(int planId, Map<String, dynamic> body) async {
    final res = await _patchWithRefresh('${baseUrl}admin-panel/plans/$planId/', body: body);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kusasisha mpango');
  }

  // ========== ROYALTIES / MGAWANYO WA MAPATO ==========
  Future<Map<String, dynamic>> fetchRoyaltySettings() async {
    final res = await _getWithRefresh('${baseUrl}royalties/admin/settings/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia mipangilio ya mapato');
  }

  Future<Map<String, dynamic>> updateRoyaltySettings(Map<String, dynamic> body) async {
    final res = await _patchWithRefresh('${baseUrl}royalties/admin/settings/', body: body);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kusasisha mipangilio ya mapato');
  }

  Future<Map<String, dynamic>> fetchRevenuePool({int? year, int? month}) async {
    String url = '${baseUrl}royalties/admin/pool/?';
    if (year != null) url += 'year=$year&';
    if (month != null) url += 'month=$month&';
    final res = await _getWithRefresh(url);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia kasha la mapato');
  }

  Future<Map<String, dynamic>> distributeRevenuePool({required int year, required int month}) async {
    final res = await _postWithRefresh('${baseUrl}royalties/admin/distribute/',
        body: {'year': year, 'month': month});
    if (res.statusCode == 200) return jsonDecode(res.body);
    final data = jsonDecode(res.body);
    throw Exception(data['detail'] ?? 'Imeshindwa kugawa mapato');
  }

  Future<Map<String, dynamic>> fetchMyEarnings() async {
    final res = await _getWithRefresh('${baseUrl}royalties/my-earnings/');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Imeshindwa kupakia mapato yako');
  }
}

