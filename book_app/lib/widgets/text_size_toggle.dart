import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// Kitufe cha haraka cha kuongeza/kupunguza ukubwa wa maandishi.
/// Kinapatikana kwenye dashboard ili kumsaidia mtumiaji aone vizuri.
class TextSizeToggle extends StatelessWidget {
  /// Ikiwa kweli, inaonyesha pill yenye rangi nyepesi (kwa usuli mweupe).
  /// Ikiwa sivyo, inafuata rangi za AppTheme.card (kwa usuli wa rangi).
  final bool light;

  const TextSizeToggle({super.key, this.light = false});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final fg = light ? Colors.white : AppTheme.primary;
    final bg = light
        ? Colors.white.withValues(alpha: 0.15)
        : AppTheme.card(context);
    final border = light
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0x294F46E5);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(
            icon: Icons.text_decrease_rounded,
            color: fg,
            enabled: settings.textScale >
                SettingsProvider.minScale + 0.001,
            onTap: settings.decreaseTextSize,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${(settings.textScale * 100).round()}%',
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _btn(
            icon: Icons.text_increase_rounded,
            color: fg,
            enabled: settings.textScale <
                SettingsProvider.maxScale - 0.001,
            onTap: settings.increaseTextSize,
          ),
        ],
      ),
    );
  }

  Widget _btn({
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Icon(icon, size: 17,
            color: enabled ? color : color.withValues(alpha: 0.35)),
      ),
    );
  }
}
