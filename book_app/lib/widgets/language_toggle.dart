import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../theme/app_theme.dart';
import 'theme_toggle.dart';

/// Mandhari thabiti ya kitufe cha lugha — rangi haitegemei usuli wa ukurasa,
/// hivyo kinaonekana wazi popote (vichwa vya rangi au usuli mweupe).
const Color _kPillText   = AppTheme.primary;
const Color _kPillBorder = Color(0x294F46E5); // AppTheme.primary @ 16%
final List<BoxShadow> _kPillShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.12),
    blurRadius: 8,
    offset: const Offset(0, 2),
  ),
];

/// Kitufe cha kubadilisha lugha — Kiswahili 🇹🇿 / English 🇬🇧
class LanguageToggle extends StatelessWidget {
  /// Onyesha jina la lugha pamoja na bendera
  final bool showLabel;

  const LanguageToggle({
    super.key,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final langProv = context.watch<LanguageProvider>();
    final isSw     = langProv.isSwahili;

    return Tooltip(
      message: isSw ? 'Switch to English' : 'Badilisha kwa Kiswahili',
      child: GestureDetector(
        onTap: () => langProv.toggle(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
              horizontal: showLabel ? 10 : 6, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kPillBorder, width: 1),
            boxShadow: _kPillShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bendera
              Text(
                isSw ? '🇹🇿' : '🇬🇧',
                style: const TextStyle(fontSize: 16),
              ),
              if (showLabel) ...[
                const SizedBox(width: 5),
                Text(
                  isSw ? 'SW' : 'EN',
                  style: const TextStyle(
                    color: _kPillText,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: _kPillText, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown ya kubadilisha lugha — inaonyesha chaguo zote
class LanguageDropdown extends StatelessWidget {
  const LanguageDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final langProv = context.watch<LanguageProvider>();
    final isSw     = langProv.isSwahili;

    final langDropdown = PopupMenuButton<AppLang>(
      initialValue: langProv.lang,
      onSelected: langProv.setLang,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      offset: const Offset(0, 44),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: AppLang.sw,
          child: Row(children: [
            const Text('🇹🇿', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Kiswahili',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Text('Lugha ya Tanzania',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
            const Spacer(),
            if (isSw) const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4F46E5), size: 18),
          ]),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: AppLang.en,
          child: Row(children: [
            const Text('🇬🇧', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('English',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Text('United Kingdom',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
            ]),
            const Spacer(),
            if (!isSw) const Icon(Icons.check_circle_rounded,
                color: Color(0xFF4F46E5), size: 18),
          ]),
        ),
      ],
      child: Tooltip(
        message: isSw ? 'Switch to English' : 'Badilisha kwa Kiswahili',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppTheme.card(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _kPillBorder, width: 1),
            boxShadow: _kPillShadow,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(isSw ? '🇹🇿' : '🇬🇧',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 5),
            Text(isSw ? 'SW' : 'EN',
                style: const TextStyle(
                    color: _kPillText, fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: _kPillText, size: 14),
          ]),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ThemeToggleButton(),
        const SizedBox(width: 8),
        langDropdown,
      ],
    );
  }
}
