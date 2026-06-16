import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mtindo wa kusoma kitabu (maandishi):
/// - [scroll]: kurasa zote zinasomwa kwa kushuka chini (kama sasa)
/// - [paged]:  kurasa moja moja, kubonyeza kulia/kushoto kuendelea/kurudi
enum ReaderLayout { scroll, paged }

/// Mipangilio ya msomaji: ukubwa wa maandishi (text scale) na mandhari
/// (mwanga / giza / mfumo). Inahifadhiwa kwenye kifaa (SharedPreferences)
/// ili ibaki hata baada ya kufunga programu.
class SettingsProvider extends ChangeNotifier {
  static const String _kThemeMode  = 'settings_theme_mode';
  static const String _kTextScale  = 'settings_text_scale';
  static const String _kReaderLayout = 'settings_reader_layout';

  static const double minScale = 0.8;
  static const double maxScale = 1.6;
  static const double stepScale = 0.1;
  static const double defaultScale = 1.0;

  ThemeMode _themeMode = ThemeMode.system;
  double _textScale = defaultScale;
  ReaderLayout _readerLayout = ReaderLayout.scroll;
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  ReaderLayout get readerLayout => _readerLayout;
  bool get isLoaded => _loaded;

  bool get isDark => _themeMode == ThemeMode.dark;

  SettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_kThemeMode);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[modeIndex];
    }
    _textScale = prefs.getDouble(_kTextScale) ?? defaultScale;
    final layoutIndex = prefs.getInt(_kReaderLayout);
    if (layoutIndex != null && layoutIndex >= 0 &&
        layoutIndex < ReaderLayout.values.length) {
      _readerLayout = ReaderLayout.values[layoutIndex];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> setReaderLayout(ReaderLayout layout) async {
    _readerLayout = layout;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kReaderLayout, layout.index);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> toggleDarkMode(bool dark) async {
    await setThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
  }

  Future<void> setTextScale(double scale) async {
    final clamped = scale.clamp(minScale, maxScale);
    _textScale = clamped;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kTextScale, clamped);
  }

  Future<void> increaseTextSize() async {
    await setTextScale(_textScale + stepScale);
  }

  Future<void> decreaseTextSize() async {
    await setTextScale(_textScale - stepScale);
  }

  Future<void> resetTextSize() async {
    await setTextScale(defaultScale);
  }
}
