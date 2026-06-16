import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_strings.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

/// Sheet ya kushare kitabu kwenye mitandao ya kijamii (WhatsApp, Facebook,
/// Twitter/X, Telegram), kunakili link, au kushare kwa njia nyingine
/// (share_plus). Kila link inajumuisha `ref=<userId>` ili msomaji
/// atakayejiunga kupitia link hiyo aweze kuhusishwa na mwandishi/mshiriki.
class ShareBookSheet extends StatelessWidget {
  final Map<String, dynamic> book;

  const ShareBookSheet({super.key, required this.book});

  static Future<void> show(BuildContext context, Map<String, dynamic> book) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => ShareBookSheet(book: book),
    );
  }

  String _baseShareUrl() {
    final shareUrl = book['share_url']?.toString();
    if (shareUrl != null && shareUrl.isNotEmpty) return shareUrl;
    return '${ApiService.shareHost()}share/book/${book['id']}/';
  }

  String _linkFor(BuildContext context, String platform) {
    final auth = context.read<AuthProvider>();
    final uri  = Uri.parse(_baseShareUrl());
    final params = Map<String, String>.from(uri.queryParameters);
    if (auth.userId != null) params['ref'] = auth.userId!.toString();
    params['src'] = platform;
    return uri.replace(queryParameters: params).toString();
  }

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = book['title']?.toString() ?? '';
    final textColor = AppTheme.textPrimary(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(S.shareBook,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: const Text('WhatsApp'),
              onTap: () {
                Navigator.pop(context);
                _openUrl('https://wa.me/?text=${Uri.encodeComponent('$title\n${_linkFor(context, 'whatsapp')}')}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.facebook, color: Color(0xFF1877F2)),
              title: const Text('Facebook'),
              onTap: () {
                Navigator.pop(context);
                _openUrl('https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(_linkFor(context, 'facebook'))}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded, color: Colors.black),
              title: const Text('Twitter / X'),
              onTap: () {
                Navigator.pop(context);
                _openUrl('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(title)}&url=${Uri.encodeComponent(_linkFor(context, 'twitter'))}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.send_rounded, color: Color(0xFF26A5E4)),
              title: const Text('Telegram'),
              onTap: () {
                Navigator.pop(context);
                _openUrl('https://t.me/share/url?url=${Uri.encodeComponent(_linkFor(context, 'telegram'))}&text=${Uri.encodeComponent(title)}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: AppTheme.primary),
              title: Text(S.copyLink),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final link = _linkFor(context, 'copy');
                Navigator.pop(context);
                await Clipboard.setData(ClipboardData(text: link));
                messenger.showSnackBar(SnackBar(
                  content: Text(S.linkCopied),
                  backgroundColor: AppTheme.success,
                ));
              },
            ),
            ListTile(
              leading: Icon(Icons.share_rounded, color: AppTheme.textSecondary(context)),
              title: Text(S.shareOther),
              onTap: () {
                final link = _linkFor(context, 'other');
                Navigator.pop(context);
                Share.share('$title\n$link');
              },
            ),
          ],
        ),
      ),
    );
  }
}
