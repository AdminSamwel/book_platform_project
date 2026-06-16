import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/language_toggle.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final ApiService _api     = ApiService();
  static const _storage     = FlutterSecureStorage();
  final _formKey            = GlobalKey<FormState>();
  final _titleCtrl          = TextEditingController();
  final _descCtrl           = TextEditingController();
  final _priceCtrl          = TextEditingController(text: '0');
  // Library metadata controllers
  final _isbnCtrl           = TextEditingController();
  final _authorsCtrl        = TextEditingController();
  final _publisherCtrl      = TextEditingController();
  final _yearCtrl           = TextEditingController();
  final _editionCtrl        = TextEditingController();
  final _pageCountCtrl      = TextEditingController();
  final _languageCtrl       = TextEditingController(text: 'Kiswahili');

  Uint8List? _bookBytes;
  String?    _bookFileName;
  Uint8List? _coverBytes;
  String?    _coverFileName;
  Uint8List? _audioBytes;
  String?    _audioFileName;

  bool          _isFree    = true;
  bool          _uploading = false;
  List<dynamic> _categories = [];
  int?          _selectedCategoryId;
  List<dynamic> _plans      = [];
  int           _minPlanLevel = 0;
  int           _minAge      = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadPlans();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.fetchCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _api.fetchPlans();
      plans.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));
      if (mounted) setState(() => _plans = plans);
    } catch (_) {}
  }

  Future<void> _pickBookFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'epub'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _bookBytes    = file.bytes;
          _bookFileName = file.name;
        });
      }
    }
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _coverBytes    = file.bytes;
          _coverFileName = file.name;
        });
      }
    }
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.bytes != null) {
        setState(() {
          _audioBytes    = file.bytes;
          _audioFileName = file.name;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bookBytes == null) {
      _showError(S.pickFileFirst);
      return;
    }
    if (_bookBytes == null && _audioBytes == null) {
      _showError(S.fileRequired);
      return;
    }
    setState(() => _uploading = true);
    try {
      final token   = await _storage.read(key: 'access_token');
      const url     = '${ApiService.baseUrl}books/create/';
      final request = http.MultipartRequest('POST', Uri.parse(url));

      request.headers['Authorization'] = 'Bearer $token';
      request.fields['title']          = _titleCtrl.text.trim();
      request.fields['description']    = _descCtrl.text.trim();
      request.fields['price']          = _isFree ? '0.00' : _priceCtrl.text.trim();
      request.fields['is_free']        = _isFree.toString();
      request.fields['is_published']   = 'true';
      request.fields['min_plan_level'] = _minPlanLevel.toString();
      request.fields['min_age']        = _minAge.toString();
      if (_selectedCategoryId != null) {
        request.fields['category'] = _selectedCategoryId.toString();
      }
      // Library metadata (send only non-empty values)
      if (_isbnCtrl.text.trim().isNotEmpty)
        request.fields['isbn']           = _isbnCtrl.text.trim();
      if (_authorsCtrl.text.trim().isNotEmpty)
        request.fields['book_authors']   = _authorsCtrl.text.trim();
      if (_publisherCtrl.text.trim().isNotEmpty)
        request.fields['publisher']      = _publisherCtrl.text.trim();
      if (_yearCtrl.text.trim().isNotEmpty)
        request.fields['year_published'] = _yearCtrl.text.trim();
      if (_editionCtrl.text.trim().isNotEmpty)
        request.fields['edition']        = _editionCtrl.text.trim();
      if (_pageCountCtrl.text.trim().isNotEmpty)
        request.fields['page_count']     = _pageCountCtrl.text.trim();
      if (_languageCtrl.text.trim().isNotEmpty)
        request.fields['book_language']  = _languageCtrl.text.trim();

      // Faili la kitabu kwa bytes (inafanya kazi web + mobile)
      final ext = (_bookFileName ?? '').split('.').last.toLowerCase();
      final contentType = ext == 'pdf'
          ? MediaType('application', 'pdf')
          : ext == 'epub'
              ? MediaType('application', 'epub+zip')
              : MediaType('text', 'plain');

      request.files.add(http.MultipartFile.fromBytes(
        'raw_file',
        _bookBytes!,
        filename: _bookFileName ?? 'kitabu.txt',
        contentType: contentType,
      ));

      if (_coverBytes != null) {
        final coverExt = (_coverFileName ?? 'cover.jpg').split('.').last.toLowerCase();
        request.files.add(http.MultipartFile.fromBytes(
          'cover_image',
          _coverBytes!,
          filename: _coverFileName ?? 'cover.jpg',
          contentType: MediaType('image', coverExt == 'png' ? 'png' : 'jpeg'),
        ));
      }

      // Faili la sauti (optional)
      if (_audioBytes != null) {
        final audioExt = (_audioFileName ?? 'audio.mp3').split('.').last.toLowerCase();
        final audioMime = audioExt == 'wav' ? 'wav'
            : audioExt == 'ogg' ? 'ogg'
            : audioExt == 'm4a' ? 'mp4' : 'mpeg';
        request.files.add(http.MultipartFile.fromBytes(
          'audio_file', _audioBytes!,
          filename: _audioFileName ?? 'audio.mp3',
          contentType: MediaType('audio', audioMime),
        ));
      }

      final streamed  = await request.send();
      final response  = await http.Response.fromStream(streamed);

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(S.uploadSuccess),
            backgroundColor: AppTheme.success,
          ));
          Navigator.pop(context);
        }
      } else {
        _showError('Hitilafu ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _showError('Hitilafu: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.danger,
    ));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _isbnCtrl.dispose();
    _authorsCtrl.dispose();
    _publisherCtrl.dispose();
    _yearCtrl.dispose();
    _editionCtrl.dispose();
    _pageCountCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  // ── Section Header Widget ─────────────────────────────────────────────────
  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.08),
            AppTheme.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontSize: 14)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Plan-availability picker ──────────────────────────────────────────────
  Widget _planLevelPicker() {
    final levels = _plans.isNotEmpty
        ? (_plans.map((p) => p['level'] as int).toSet().toList()..sort())
        : [0, 1, 2, 3];

    String labelFor(int level) {
      if (level == 0) return S.planLevelAll;
      final plan = _plans.firstWhere(
        (p) => p['level'] == level,
        orElse: () => null,
      );
      final name = plan != null ? plan['name'] as String : 'Level $level';
      return '$name ${S.planLevelFrom}';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonFormField<int>(
        initialValue: _minPlanLevel,
        decoration: InputDecoration(
          labelText: S.availableTo,
          helperText: S.availableToDesc,
          helperMaxLines: 3,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.workspace_premium_rounded),
        ),
        items: levels
            .map((lvl) => DropdownMenuItem(
                  value: lvl,
                  child: Text(labelFor(lvl)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _minPlanLevel = v ?? 0),
      ),
    );
  }

  // ── Age-restriction picker ────────────────────────────────────────────────
  Widget _minAgePicker() {
    const ages = [0, 12, 16, 18];
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: DropdownButtonFormField<int>(
        initialValue: _minAge,
        decoration: InputDecoration(
          labelText: S.minAgeLabel,
          helperText: S.minAgeDesc,
          helperMaxLines: 3,
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.gpp_maybe_rounded),
        ),
        items: ages
            .map((age) => DropdownMenuItem(
                  value: age,
                  child: Text(S.minAgeOption(age)),
                ))
            .toList(),
        onChanged: (v) => setState(() => _minAge = v ?? 0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    return Scaffold(
      appBar: AppBar(
        title: Text(S.uploadTitle),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: const [LanguageDropdown(), SizedBox(width: 8)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              // ── Basic Info Section Header ──
              _sectionHeader(Icons.book_rounded, S.bookInfo, ''),
              const SizedBox(height: 12),

              // Picha ya jalada
              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: _coverBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.memory(_coverBytes!,
                              fit: BoxFit.cover, width: double.infinity))
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_rounded,
                                size: 40,
                                color: AppTheme.primary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(S.addCover,
                                style: TextStyle(
                                    color: AppTheme.textSecondary(context), fontSize: 13)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Jina
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: S.bookTitle,
                  prefixIcon: const Icon(Icons.title_rounded),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? S.titleRequired : null,
              ),
              const SizedBox(height: 12),

              // Maelezo
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: S.bookDesc,
                  prefixIcon: const Icon(Icons.description_rounded),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? S.descRequired : null,
              ),
              const SizedBox(height: 12),

              // ── Metadata Section Header ──
              const SizedBox(height: 20),
              _sectionHeader(Icons.library_books_rounded, S.metadataTitle,
                  S.metaSectionNote),
              const SizedBox(height: 12),

              // ISBN
              TextFormField(
                controller: _isbnCtrl,
                decoration: InputDecoration(
                  labelText: '${S.isbn} ${S.optional}',
                  hintText: S.isbnHint,
                  prefixIcon: const Icon(Icons.tag_rounded),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                  if (digits.length != 10 && digits.length != 13) {
                    return S.isbnInvalid;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Waandishi
              TextFormField(
                controller: _authorsCtrl,
                decoration: InputDecoration(
                  labelText: '${S.bookAuthors} ${S.optional}',
                  hintText: S.bookAuthorsHint,
                  prefixIcon: const Icon(Icons.people_alt_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Mchapishaji
              TextFormField(
                controller: _publisherCtrl,
                decoration: InputDecoration(
                  labelText: '${S.publisher} ${S.optional}',
                  hintText: S.publisherHint,
                  prefixIcon: const Icon(Icons.business_rounded),
                ),
              ),
              const SizedBox(height: 12),

              // Mwaka & Toleo (row)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _yearCtrl,
                      decoration: InputDecoration(
                        labelText: '${S.yearPublished} ${S.optional}',
                        hintText: S.yearHint,
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final yr = int.tryParse(v.trim());
                        if (yr == null || yr < 1800 ||
                            yr > DateTime.now().year + 1) {
                          return S.yearInvalid;
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _editionCtrl,
                      decoration: InputDecoration(
                        labelText: '${S.edition} ${S.optional}',
                        hintText: S.editionHint,
                        prefixIcon: const Icon(Icons.layers_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Kurasa & Lugha (row)
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _pageCountCtrl,
                      decoration: InputDecoration(
                        labelText: '${S.pageCount} ${S.optional}',
                        hintText: S.pageCountHint,
                        prefixIcon: const Icon(Icons.menu_book_rounded),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _languageCtrl,
                      decoration: InputDecoration(
                        labelText: S.bookLanguage,
                        prefixIcon: const Icon(Icons.translate_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Kategoria & Bei Section Header ──
              _sectionHeader(Icons.sell_rounded, S.category, ''),
              const SizedBox(height: 12),

              // Kategoria
              if (_categories.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: S.category,
                    prefixIcon: const Icon(Icons.category_rounded),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(S.anyCategory)),
                    ..._categories.map((c) => DropdownMenuItem(
                          value: c['id'] as int,
                          child: Text(c['name']),
                        )),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
                const SizedBox(height: 12),
              ],

              // Bure au Bei
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.card(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: SwitchListTile(
                  title: Text(S.freeBook,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(_isFree ? S.freeDesc : S.paidDesc),
                  value: _isFree,
                  activeThumbColor: AppTheme.success,
                  onChanged: (v) => setState(() {
                    _isFree = v;
                    if (v) _minPlanLevel = 0;
                  }),
                ),
              ),

              if (!_isFree) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: S.price,
                    prefixIcon: const Icon(Icons.attach_money_rounded),
                  ),
                  validator: (v) {
                    if (_isFree) return null;
                    if (v == null || double.tryParse(v) == null) {
                      return S.priceInvalid;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _planLevelPicker(),
              ],
              const SizedBox(height: 12),

              // Kikomo cha Umri
              _minAgePicker(),
              const SizedBox(height: 16),

              // ── Files Section Header ──
              _sectionHeader(Icons.attach_file_rounded, S.chooseBookFile, ''),
              const SizedBox(height: 12),

              // Chagua faili la kitabu
              InkWell(
                onTap: _pickBookFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _bookBytes != null
                        ? AppTheme.success.withValues(alpha: 0.06)
                        : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _bookBytes != null
                          ? AppTheme.success
                          : AppTheme.borderColor(context),
                      width: _bookBytes != null ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_bookBytes != null
                                  ? AppTheme.success
                                  : AppTheme.primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _bookBytes != null
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          color: _bookBytes != null
                              ? AppTheme.success
                              : AppTheme.primary,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _bookBytes != null
                                  ? S.fileChosen
                                  : S.chooseBookFile,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _bookBytes != null
                                    ? AppTheme.success
                                    : AppTheme.textPrimary(context),
                              ),
                            ),
                            Text(
                              _bookFileName ?? 'txt, pdf, au epub',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary(context)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary(context)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Faili la Sauti (optional) ──
              InkWell(
                onTap: _pickAudioFile,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _audioBytes != null
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.06)
                        : AppTheme.card(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _audioBytes != null
                          ? const Color(0xFF7C3AED) : AppTheme.borderColor(context),
                      width: _audioBytes != null ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (_audioBytes != null
                                ? const Color(0xFF7C3AED)
                                : AppTheme.textSecondary(context))
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _audioBytes != null
                            ? Icons.check_circle_rounded
                            : Icons.headphones_rounded,
                        color: _audioBytes != null
                            ? const Color(0xFF7C3AED) : AppTheme.textSecondary(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _audioBytes != null
                              ? S.audioChosen
                              : S.addAudio,
                          style: TextStyle(fontWeight: FontWeight.w600,
                            color: _audioBytes != null
                                ? const Color(0xFF7C3AED) : AppTheme.textPrimary(context)),
                        ),
                        Text(_audioFileName ?? 'mp3, wav, ogg, m4a',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textSecondary(context)),
                          overflow: TextOverflow.ellipsis),
                      ],
                    )),
                    Icon(Icons.chevron_right_rounded,
                        color: AppTheme.textSecondary(context)),
                  ]),
                ),
              ),
              const SizedBox(height: 28),

              // Kitufe cha kupakia
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _uploading ? null : _submit,
                  child: _uploading
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2)),
                            const SizedBox(width: 12),
                            Text(S.uploading),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_rounded),
                            const SizedBox(width: 8),
                            Text(S.uploadBtn,
                                style: const TextStyle(fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                S.encryptNote,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
