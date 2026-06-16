import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/responsive.dart';

/// Ukurasa unaomruhusu msomaji kuongeza/kubadilisha makundi ya vitabu
/// anayopenda kutoka kwenye dashibodi yake (hakuna ukomo wa idadi).
class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final ApiService _api = ApiService();
  bool _loading = true;
  bool _saving = false;
  List<dynamic> _allCategories = [];
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchCategories(),
        _api.fetchFavoriteCategories(),
      ]);
      final cats = results[0] as List<dynamic>;
      final mine = results[1] as Map<String, dynamic>;
      final favIds = ((mine['favorite_categories'] as List?) ?? [])
          .map((c) => c['id'] as int)
          .toSet();
      if (mounted) {
        setState(() {
          _allCategories = cats;
          _selected
            ..clear()
            ..addAll(favIds);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.updateFavoriteCategories(_selected.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(S.categoriesSaved),
          backgroundColor: AppTheme.success,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppTheme.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: AppTheme.bg(context),
      appBar: AppBar(
        title: Text(S.myCategories),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          : CenteredContent(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.myCategoriesHint,
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary(context))),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allCategories.map((cat) {
                        final id = cat['id'] as int;
                        final name = cat['name']?.toString() ?? '';
                        final selected = _selected.contains(id);
                        return ChoiceChip(
                          label: Text(name),
                          selected: selected,
                          selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                              color: selected ? AppTheme.primary : AppTheme.textPrimary(context),
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal),
                          side: BorderSide(
                              color: selected ? AppTheme.primary : AppTheme.borderColor(context)),
                          onSelected: (_) {
                            setState(() {
                              if (selected) {
                                _selected.remove(id);
                              } else {
                                _selected.add(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                        child: _saving
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text(S.saveCategories,
                                style: const TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
