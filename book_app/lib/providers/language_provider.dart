import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

class LanguageProvider extends ChangeNotifier {
  AppLang _lang = AppLang.sw;

  AppLang get lang => _lang;
  bool get isSwahili => _lang == AppLang.sw;

  /// Badilisha lugha kati ya Kiswahili na English
  void toggle() {
    _lang = _lang == AppLang.sw ? AppLang.en : AppLang.sw;
    S.setLang(_lang);
    notifyListeners();
  }

  void setLang(AppLang lang) {
    _lang = lang;
    S.setLang(lang);
    notifyListeners();
  }
}
