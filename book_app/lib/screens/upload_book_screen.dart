import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class UploadBookScreen extends StatefulWidget {
  const UploadBookScreen({super.key});

  @override
  State<UploadBookScreen> createState() => _UploadBookScreenState();
}

class _UploadBookScreenState extends State<UploadBookScreen> {
  final ApiService _api = ApiService();
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _priceCtrl = TextEditingController(text: '0');

  File? _bookFile;
  String? _bookFileName;
  File? _coverFile;
  bool _isFree = true;
  bool _uploading = false;
  List<dynamic> _categories = [];
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.fetchCategories();
      setState(() => _categories = cats);
    } catch (_) {}
  }

  Future<void> _pickBookFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'pdf', 'epub'],
    );
    if (result != null) {
      setState(() {
        _bookFile = File(result.files.single.path!);
        _bookFileName = result.files.single.name;
      });
    }
  }

  Future<void> _pickCover() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (img != null) setState(() => _coverFile = File(img.path));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_bookFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chagua faili la kitabu kwanza')));
      return;
    }

    setState(() => _uploading = true);
    try {
      final res = await _api.uploadBook(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: _isFree ? '0.00' : _priceCtrl.text.trim(),
        isFree: _isFree,
        bookFile: _bookFile!,
        coverImage: _coverFile,
        categoryId: _selectedCategoryId,
      );
      if (res.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kitabu kimepakiwa na kusimbwa kwa usalama!')));
          Navigator.pop(context);
        }
      } else {
        throw Exception('Hitilafu: ${res.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pakia Kitabu Kipya'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image
              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.indigo.shade200),
                  ),
                  child: _coverFile != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(_coverFile!, fit: BoxFit.cover, width: double.infinity))
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 40, color: Colors.indigo),
                            SizedBox(height: 8),
                            Text('Bonyeza kuongeza picha ya jalada', style: TextStyle(color: Colors.indigo)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jina la Kitabu *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Jina linahitajika' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Maelezo *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Maelezo yanahitajika' : null,
              ),
              const SizedBox(height: 12),

              // Category
              if (_categories.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.category),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Kategoria yoyote')),
                    ..._categories.map((c) => DropdownMenuItem(
                      value: c['id'] as int,
                      child: Text(c['name']),
                    )),
                  ],
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                ),
              const SizedBox(height: 12),

              // Free toggle
              SwitchListTile(
                title: const Text('Kitabu cha Bure'),
                subtitle: const Text('Wasomaji watasoma bila malipo'),
                value: _isFree,
                activeThumbColor: Colors.indigo,
                onChanged: (v) => setState(() => _isFree = v),
              ),

              // Price (shown only if not free)
              if (!_isFree)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: _priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Bei (TZS) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    validator: (v) {
                      if (_isFree) return null;
                      if (v == null || double.tryParse(v) == null) return 'Bei si sahihi';
                      return null;
                    },
                  ),
                ),

              // Book file
              OutlinedButton.icon(
                icon: const Icon(Icons.attach_file),
                label: Text(_bookFileName ?? 'Chagua Faili la Kitabu (txt/pdf/epub) *'),
                onPressed: _pickBookFile,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.indigo,
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(width: 12),
                          Text('Inapakia na kusimba...'),
                        ],
                      )
                    : const Text('Pakia Kitabu', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
