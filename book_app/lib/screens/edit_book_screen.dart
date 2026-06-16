import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_image.dart';

class EditBookScreen extends StatefulWidget {
  final int bookId;

  const EditBookScreen({super.key, required this.bookId});

  @override
  State<EditBookScreen> createState() => _EditBookScreenState();
}

class _EditBookScreenState extends State<EditBookScreen> {
  final ApiService _api    = ApiService();
  final _formKey           = GlobalKey<FormState>();
  final _titleCtrl         = TextEditingController();
  final _descCtrl          = TextEditingController();
  final _priceCtrl         = TextEditingController(text: '0');

  bool           _loading     = true;
  bool           _saving      = false;
  bool           _isFree      = true;
  bool           _isPublished = false;
  int?           _selectedCategoryId;
  List<dynamic>  _categories  = [];
  String?        _existingCoverUrl;
  List<dynamic>  _plans       = [];
  int            _minPlanLevel = 0;
  int            _minAge      = 0;

  // Faili mpya (optional)
  Uint8List? _newCoverBytes;
  String?    _newCoverFileName;
  Uint8List? _newBookBytes;
  String?    _newBookFileName;
  Uint8List? _newAudioBytes;
  String?    _newAudioFileName;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _api.fetchBookForEdit(widget.bookId),
        _api.fetchCategories(),
        _api.fetchPlans(),
      ]);
      final book  = results[0] as Map<String, dynamic>;
      final cats  = results[1] as List<dynamic>;
      final plans = results[2] as List<dynamic>;
      plans.sort((a, b) => (a['level'] as int).compareTo(b['level'] as int));

      _titleCtrl.text      = book['title'] ?? '';
      _descCtrl.text       = book['description'] ?? '';
      _priceCtrl.text      = book['price']?.toString() ?? '0';
      _isFree              = book['is_free'] == true;
      _isPublished         = book['is_published'] == true;
      _existingCoverUrl    = book['cover_image']?.toString();
      _selectedCategoryId  = book['category'] as int?;
      _minPlanLevel        = (book['min_plan_level'] as int?) ?? 0;
      _minAge              = (book['min_age'] as int?) ?? 0;

      if (mounted) setState(() { _categories = cats; _plans = plans; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
          backgroundColor: AppTheme.danger,
        ));
      }
    }
  }

  Future<void> _pickCover() async {
    final r = await FilePicker.platform.pickFiles(
        type: FileType.image, withData: true);
    if (r != null && r.files.first.bytes != null) {
      setState(() {
        _newCoverBytes    = r.files.first.bytes;
        _newCoverFileName = r.files.first.name;
      });
    }
  }

  Future<void> _pickBookFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'epub'],
      withData: true,
    );
    if (r != null && r.files.first.bytes != null) {
      setState(() {
        _newBookBytes    = r.files.first.bytes;
        _newBookFileName = r.files.first.name;
      });
    }
  }

  Future<void> _pickAudio() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
      withData: true,
    );
    if (r != null && r.files.first.bytes != null) {
      setState(() {
        _newAudioBytes    = r.files.first.bytes;
        _newAudioFileName = r.files.first.name;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.updateBook(
        bookId:        widget.bookId,
        title:         _titleCtrl.text.trim(),
        description:   _descCtrl.text.trim(),
        price:         _isFree ? '0.00' : _priceCtrl.text.trim(),
        isFree:        _isFree,
        isPublished:   _isPublished,
        categoryId:    _selectedCategoryId,
        coverBytes:    _newCoverBytes,
        coverFileName: _newCoverFileName,
        bookBytes:     _newBookBytes,
        bookFileName:  _newBookFileName,
        audioBytes:    _newAudioBytes,
        audioFileName: _newAudioFileName,
        minPlanLevel:  _minPlanLevel,
        minAge:        _minAge,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.t('Kitabu kimehifadhiwa!', 'Book saved successfully!')),
          backgroundColor: AppTheme.success,
        ));
        Navigator.pop(context, true); // true = mabadiliko yametokea
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString().replaceAll('Exception: ', '')),
        backgroundColor: AppTheme.danger,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
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
    context.watch<LanguageProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t('Hariri Kitabu', 'Edit Book')),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          if (!_saving)
            TextButton.icon(
              icon: const Icon(Icons.check_rounded, color: Colors.white),
              label: Text(S.save,
                  style: const TextStyle(color: Colors.white,
                      fontWeight: FontWeight.bold)),
              onPressed: _save,
            )
          else
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Picha ya Jalada ──
                    _sectionTitle(S.t('Picha ya Jalada', 'Cover Image')),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickCover,
                      child: Container(
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.3)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_newCoverBytes != null)
                              Image.memory(_newCoverBytes!, fit: BoxFit.cover)
                            else if (_existingCoverUrl != null &&
                                _existingCoverUrl!.isNotEmpty)
                              safeNetworkImage(_existingCoverUrl,
                                  fit: BoxFit.cover)
                            else
                              Container(
                                color: AppTheme.primary.withValues(alpha: 0.06),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_rounded,
                                        size: 40,
                                        color: AppTheme.primary
                                            .withValues(alpha: 0.5)),
                                    const SizedBox(height: 8),
                                    Text(S.addCover,
                                        style: TextStyle(
                                            color: AppTheme.textSecondary(context),
                                            fontSize: 13)),
                                  ],
                                ),
                              ),
                            // Overlay ya "Badilisha"
                            Positioned(
                              bottom: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.edit_rounded,
                                        color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      S.t('Badilisha', 'Change'),
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Taarifa za Msingi ──
                    _sectionTitle(S.t('Taarifa za Kitabu', 'Book Information')),
                    const SizedBox(height: 8),

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

                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: S.bookDesc,
                        prefixIcon: const Icon(Icons.description_rounded),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? S.descRequired : null,
                    ),
                    const SizedBox(height: 12),

                    // Kategoria
                    if (_categories.isNotEmpty)
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
                        onChanged: (v) =>
                            setState(() => _selectedCategoryId = v),
                      ),
                    const SizedBox(height: 12),

                    // Bei
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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

                    // Hali ya Uchapishaji
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.card(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: SwitchListTile(
                        title: Text(S.t('Chapisha', 'Publish'),
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(_isPublished
                            ? S.t('Inaonekana kwa wasomaji',
                                'Visible to readers')
                            : S.t('Haionekani bado (rasimu)',
                                'Not visible yet (draft)')),
                        value: _isPublished,
                        activeThumbColor: AppTheme.primary,
                        onChanged: (v) => setState(() => _isPublished = v),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kikomo cha Umri
                    _minAgePicker(),
                    const SizedBox(height: 20),

                    // ── Faili ──
                    _sectionTitle(S.t('Badilisha Faili (Si Lazima)',
                        'Replace Files (Optional)')),
                    const SizedBox(height: 8),
                    Text(
                      S.t(
                        'Acha wazi kama hutaki kubadilisha faili.',
                        'Leave empty if you don\'t want to replace the file.',
                      ),
                      style: TextStyle(
                          color: AppTheme.textSecondary(context), fontSize: 12),
                    ),
                    const SizedBox(height: 12),

                    // Faili la kitabu
                    _filePickerTile(
                      icon:      Icons.upload_file_rounded,
                      label:     S.t('Badilisha Faili la Kitabu',
                                     'Replace Book File'),
                      fileName:  _newBookFileName,
                      color:     AppTheme.primary,
                      onTap:     _pickBookFile,
                      extensions: 'PDF, TXT, EPUB',
                    ),
                    const SizedBox(height: 10),

                    // Faili la sauti
                    _filePickerTile(
                      icon:      Icons.headphones_rounded,
                      label:     S.t('Badilisha Faili la Sauti',
                                     'Replace Audio File'),
                      fileName:  _newAudioFileName,
                      color:     const Color(0xFF7C3AED),
                      onTap:     _pickAudio,
                      extensions: 'MP3, WAV, OGG, M4A',
                    ),
                    const SizedBox(height: 28),

                    // Kitufe cha Hifadhi
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _saving
                              ? S.t('Inahifadhi...', 'Saving...')
                              : S.t('Hifadhi Mabadiliko', 'Save Changes'),
                          style: const TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [
      Container(
        width: 4, height: 18,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(text, style: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold,
          color: AppTheme.textPrimary(context))),
    ]),
  );

  Widget _filePickerTile({
    required IconData icon,
    required String label,
    required String? fileName,
    required Color color,
    required VoidCallback onTap,
    required String extensions,
  }) {
    final hasFile = fileName != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasFile ? color.withValues(alpha: 0.06) : AppTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? color : AppTheme.borderColor(context),
            width: hasFile ? 2 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: (hasFile ? color : AppTheme.textSecondary(context))
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(hasFile ? Icons.check_circle_rounded : icon,
                color: hasFile ? color : AppTheme.textSecondary(context), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hasFile ? S.t('Faili Jipya Limechaguliwa', 'New file selected') : label,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: hasFile ? color : AppTheme.textPrimary(context))),
              Text(fileName ?? extensions,
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary(context)),
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary(context)),
        ]),
      ),
    );
  }
}
