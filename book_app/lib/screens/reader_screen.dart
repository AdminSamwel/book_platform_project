import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/offline_book_service.dart';
import '../theme/app_theme.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  // Kweli kwa vitabu vilivyonunuliwa/bure pekee — hivi ndivyo vinavyoruhusiwa
  // kuhifadhiwa kwenye kifaa kwa ajili ya usomaji nje ya mtandao. Vitabu
  // vinavyofikiwa kwa usajili wa kila mwezi tu (bila ununuzi) hupaswa
  // kusomwa ukiwa na mtandao pekee, hivyo havihifadhiwi humu.
  final bool canDownload;
  const ReaderScreen({super.key, required this.bookId, required this.canDownload});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ApiService _api = ApiService();

  bool    _loading  = true;
  String? _error;
  String? _fileType;

  // ── PDF viewer state ──────────────────────────────────────────────────────
  String? _viewId;
  ReaderLayout? _pdfLayoutBuilt;
  bool?   _pdfDarkBuilt;
  web.HTMLIFrameElement? _pdfIframe;
  String? _pdfBase64;

  // ── Text viewer state ─────────────────────────────────────────────────────
  String? _textViewId;
  web.HTMLIFrameElement? _textIframe;
  String? _rawText;
  double  _textFontBuilt = 0;
  bool?   _textDarkBuilt;

  // ── Shared UI controls ────────────────────────────────────────────────────
  double _fontSize = 16;
  bool   _darkMode = false;

  // ── DRM: username embedded as watermark on every page ─────────────────────
  String _watermark = '';

  // Blob URL ya iframe ya sasa — inafutwa (revoke) mara moja inapobadilishwa
  // au skrini hii ikifungwa, ili maudhui yaliyofunguliwa nje ya mtandao
  // yasibaki yanapatikana kwenye kumbukumbu ya kivinjari baada ya kuondoka.
  String? _activeBlobUrl;

  @override
  void initState() {
    super.initState();
    _darkMode  = context.read<SettingsProvider>().isDark;
    _watermark = context.read<AuthProvider>().username;
    if (_watermark.isEmpty) _watermark = 'Licensed User';
    _loadContent();
  }

  @override
  void dispose() {
    if (_activeBlobUrl != null) {
      web.URL.revokeObjectURL(_activeBlobUrl!);
      _activeBlobUrl = null;
    }
    super.dispose();
  }

  /// Tengeneza blob URL kwa HTML iliyotolewa, ukifuta (revoke) ile ya
  /// awali kwanza — kitabu hakiwahi kuwa faili linalofikika nje ya iframe
  /// hii, na haliachwi kwenye kumbukumbu baada ya kubadilishwa.
  String _trackedBlobUrl(String html) {
    if (_activeBlobUrl != null) {
      web.URL.revokeObjectURL(_activeBlobUrl!);
    }
    final blob = web.Blob(
      [html.toJS].toJS,
      web.BlobPropertyBag(type: 'text/html'),
    );
    final url = web.URL.createObjectURL(blob);
    _activeBlobUrl = url;
    return url;
  }

  // ── Content loading ───────────────────────────────────────────────────────

  Future<void> _loadContent() async {
    setState(() { _loading = true; _error = null; });

    Uint8List? bytes;
    String?    ct;
    bool       fromCache = false;

    // 1. Try fetching from server (online path)
    try {
      final result = await _api.fetchBookBytes(widget.bookId);
      bytes = result['bytes'] as Uint8List;
      ct    = (result['content_type'] as String).toLowerCase();

      // Cache encrypted in background — no await so reader opens immediately.
      // Only vitabu vilivyonunuliwa/bure vinaruhusiwa kuhifadhiwa offline;
      // usomaji wa usajili wa kila mwezi lazima ubaki mtandaoni tu.
      if (mounted && widget.canDownload) {
        final title = widget.bookId.toString();
        OfflineBookService.instance.saveBook(
          bookId: widget.bookId, bytes: bytes,
          contentType: ct, title: title,
        );
      }
    } catch (_) {
      // 2. Server unreachable or offline — try encrypted local cache
      // (tu kwa vitabu vinavyoruhusiwa kupakuliwa)
      if (widget.canDownload) {
        try {
          final cached = await OfflineBookService.instance.getBook(widget.bookId);
          if (cached != null) {
            bytes     = cached['bytes'] as Uint8List;
            ct        = (cached['content_type'] as String? ?? 'text/plain').toLowerCase();
            fromCache = true;
          }
        } catch (_) {}
      }
    }

    if (bytes == null || ct == null) {
      if (mounted) {
        setState(() {
          _error   = widget.canDownload
              ? S.t(
                  'Huna mtandao na kitabu hakijahifadhiwa. '
                  'Fungua kitabu mara moja ukiwa na mtandao ili kisomeke offline.',
                  'No internet and book not cached. '
                  'Open the book once while online so it becomes available offline.',
                )
              : S.t(
                  'Huna mtandao. Vitabu vya usajili wa kila mwezi vinasomwa '
                  'ukiwa na mtandao pekee — haviwezi kupakuliwa kwa ajili ya offline.',
                  'No internet connection. Books accessed via monthly subscription '
                  'can only be read online — they cannot be downloaded for offline use.',
                );
          _loading = false;
        });
      }
      return;
    }

    if (!mounted) return;
    if (fromCache) {
      // Subtle banner so user knows they're reading offline
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              const Icon(Icons.offline_bolt_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(S.t('Unasoma offline (cache)', 'Reading offline (cached copy)')),
            ]),
            backgroundColor: const Color(0xFF0EA5E9),
            duration: const Duration(seconds: 3),
          ));
        }
      });
    }

    if (ct.contains('pdf')) {
      final layout = mounted
          ? context.read<SettingsProvider>().readerLayout
          : ReaderLayout.scroll;
      await _setupPdfViewer(bytes, layout);
    } else {
      final text = utf8.decode(bytes, allowMalformed: true);
      await _setupTextViewer(text);
    }
  }

  // ── PDF viewer setup ──────────────────────────────────────────────────────

  Future<void> _setupPdfViewer(Uint8List pdfBytes, ReaderLayout layout) async {
    final base64Data = base64Encode(pdfBytes);
    final viewId = 'secure-pdf-${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}';
    final html   = _buildSecurePdfHtml(base64Data, layout == ReaderLayout.paged, _darkMode);
    _pdfLayoutBuilt = layout;
    _pdfDarkBuilt   = _darkMode;
    _pdfBase64      = base64Data;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.width      = '100%';
      iframe.style.height     = '100%';
      iframe.style.border     = 'none';
      iframe.style.background = '#525659';
      iframe.src = _trackedBlobUrl(html);
      _pdfIframe = iframe;
      return iframe;
    });

    if (mounted) {
      setState(() { _fileType = 'pdf'; _viewId = viewId; _loading = false; });
    }
  }

  // ── Text viewer setup ─────────────────────────────────────────────────────

  Future<void> _setupTextViewer(String text) async {
    _rawText = text;
    final viewId = 'secure-txt-${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}';
    final html   = _buildSecureTextHtml(text, _fontSize, _darkMode);
    _textFontBuilt = _fontSize;
    _textDarkBuilt = _darkMode;

    ui_web.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
      iframe.style.width  = '100%';
      iframe.style.height = '100%';
      iframe.style.border = 'none';
      iframe.src = _trackedBlobUrl(html);
      _textIframe = iframe;
      return iframe;
    });

    if (mounted) {
      setState(() { _fileType = 'txt'; _textViewId = viewId; _loading = false; });
    }
  }

  // ── HTML escaping (prevents XSS from book content) ────────────────────────

  String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String get _safeWatermark => _watermark
      .replaceAll("'", ' ')
      .replaceAll('"', ' ')
      .replaceAll('<', '')
      .replaceAll('>', '')
      .replaceAll('\n', ' ');

  // ── Shared security JavaScript (injected into every iframe) ───────────────

  String _securityJs() => '''
// ── BLOCK: right-click context menu ──────────────────────────────────────
document.addEventListener('contextmenu', function(e) {
  e.preventDefault(); return false;
});

// ── BLOCK: text selection (double-click, triple-click, drag select) ───────
document.addEventListener('selectstart', function(e) {
  e.preventDefault(); return false;
});

// ── BLOCK: drag ───────────────────────────────────────────────────────────
document.addEventListener('dragstart', function(e) {
  e.preventDefault(); return false;
});

// ── BLOCK: keyboard shortcuts ─────────────────────────────────────────────
document.addEventListener('keydown', function(e) {
  var k   = e.key ? e.key.toLowerCase() : '';
  var c   = e.ctrlKey || e.metaKey;
  var sh  = e.shiftKey;
  // Ctrl/Cmd + S/P/U/A/C/X/J/F (save, print, source, select, copy, cut, downloads, find)
  if (c && ['s','p','u','a','c','x','j','f','g'].includes(k)) {
    e.preventDefault(); e.stopPropagation(); return false;
  }
  // Ctrl+Shift+I / J / C / K (DevTools)
  if (c && sh && ['i','j','c','k'].includes(k)) {
    e.preventDefault(); e.stopPropagation(); return false;
  }
  // F12 (DevTools), F5 (Reload), PrintScreen
  if (['f12','f5','printscreen','f1','f2','f3','f4','f6','f7','f8','f9','f10','f11'].includes(k)) {
    e.preventDefault(); e.stopPropagation(); return false;
  }
}, true);

// ── BLOCK: print ──────────────────────────────────────────────────────────
window.addEventListener('beforeprint', function(e) {
  e.preventDefault(); return false;
}, true);

// ── BLUR OVERLAY: hide content when window loses focus ────────────────────
function showBlur() {
  var o = document.getElementById('drm-blur');
  if (o) o.style.display = 'flex';
}
function hideBlur() {
  var o = document.getElementById('drm-blur');
  if (o) o.style.display = 'none';
}
document.addEventListener('visibilitychange', function() {
  document.hidden ? showBlur() : hideBlur();
});
window.addEventListener('blur',  showBlur);
window.addEventListener('focus', hideBlur);
''';

  // ── Secure PDF HTML ───────────────────────────────────────────────────────

  String _buildSecurePdfHtml(String base64Data, bool paged, bool dark) {
    final bodyBg     = dark ? '#0d0d0f' : '#525659';
    final pageFilter = dark ? 'filter: brightness(0.78) contrast(1.05);' : '';
    final wm         = _safeWatermark;

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Soma Kitabu</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body {
    background: $bodyBg;
    font-family: Arial, sans-serif;
    overflow-x: hidden;
    user-select: none;
    -webkit-user-select: none;
    cursor: default;
  }
  @media print { body { display:none !important; } }
  #toolbar {
    position:fixed; top:0; left:0; right:0;
    background:#323639; color:white;
    padding:8px 16px;
    display:flex; align-items:center; gap:12px;
    z-index:100; box-shadow:0 2px 4px rgba(0,0,0,0.3);
  }
  #toolbar button {
    background:#4a4e51; color:white; border:none;
    padding:6px 14px; border-radius:4px;
    cursor:pointer; font-size:14px;
  }
  #toolbar button:hover { background:#5a5e61; }
  #toolbar button:disabled { opacity:0.4; cursor:not-allowed; }
  #pageInfo { color:#ccc; font-size:13px; flex:1; text-align:center; }
  #loading {
    position:fixed; top:50%; left:50%;
    transform:translate(-50%,-50%);
    color:white; font-size:16px; text-align:center;
  }
  #pdfContainer {
    margin-top:52px; padding:16px;
    display:flex; flex-direction:column;
    align-items:center; gap:12px;
  }
  .page-canvas {
    box-shadow:0 4px 12px rgba(0,0,0,0.4);
    display:block; max-width:100%;
    $pageFilter
  }
  canvas { pointer-events:none; -webkit-user-drag:none; }
  /* DRM blur overlay */
  #drm-blur {
    display:none; position:fixed;
    top:0; left:0; right:0; bottom:0;
    background:rgba(8,8,16,0.97);
    z-index:9999;
    align-items:center; justify-content:center;
    flex-direction:column; cursor:pointer;
  }
  #drm-blur p { color:#ccc; font-size:15px; margin-top:14px; }
  #drm-blur small { color:#888; font-size:12px; margin-top:6px; }
</style>
</head>
<body>

<div id="drm-blur" onclick="this.style.display='none'">
  <div style="font-size:52px;">🔒</div>
  <p>Maudhui yamefichwa kwa usalama</p>
  <small>Bonyeza hapa kuendelea kusoma</small>
</div>

<div id="toolbar">
  <button id="prevBtn" disabled>&#8592; Iliyopita</button>
  <span id="pageInfo">Inapakia...</span>
  <button id="nextBtn" disabled>Inayofuata &#8594;</button>
</div>

<div id="loading"><div>Inafungua kitabu...</div></div>
<div id="pdfContainer"></div>

<script>
${_securityJs()}

// ── PDF.js viewer ─────────────────────────────────────────────────────────
pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

var pdfDoc    = null;
var pageNum   = 1;
var pageCount = 0;
var PAGED     = $paged;

var base64 = '$base64Data';
var binary = atob(base64);
var bytes  = new Uint8Array(binary.length);
for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

pdfjsLib.getDocument({ data: bytes }).promise.then(function(pdf) {
  pdfDoc    = pdf;
  pageCount = pdf.numPages;
  document.getElementById('loading').style.display = 'none';
  if (PAGED) {
    pageNum = 1;
    showPage(pageNum);
  } else {
    document.getElementById('nextBtn').disabled = (pageCount <= 1);
    document.getElementById('prevBtn').disabled = true;
    updatePageInfo();
    renderAllPages();
  }
}).catch(function(err) {
  document.getElementById('loading').innerHTML =
    '<div style="color:#ff6b6b">Hitilafu ya kufungua PDF:<br>' + err.message + '</div>';
});

// ── Watermark: drawn on every canvas after render ─────────────────────────
function drawWatermark(canvas) {
  var wm = '$wm';
  if (!wm) return;
  var ctx = canvas.getContext('2d');
  ctx.save();
  ctx.globalAlpha = 0.07;
  ctx.fillStyle   = '#333333';
  ctx.font        = 'bold 13px Arial';
  ctx.translate(canvas.width / 2, canvas.height / 2);
  ctx.rotate(-Math.PI / 6);
  var colStep = canvas.width * 0.45;
  var rowStep = 110;
  var cols = Math.ceil(canvas.width  / colStep) + 2;
  var rows = Math.ceil(canvas.height / rowStep) + 2;
  for (var r = -rows; r <= rows; r++) {
    for (var c = -cols; c <= cols; c++) {
      ctx.fillText(wm, c * colStep, r * rowStep);
    }
  }
  ctx.restore();
}

function renderAllPages() {
  var container = document.getElementById('pdfContainer');
  container.innerHTML = '';
  for (var i = 1; i <= pageCount; i++) renderPage(i, container);
}

function renderPage(num, container) {
  pdfDoc.getPage(num).then(function(page) {
    var viewport = page.getViewport({ scale: getScale() });
    var canvas   = document.createElement('canvas');
    canvas.className = 'page-canvas';
    canvas.width  = viewport.width;
    canvas.height = viewport.height;
    canvas.style.width = Math.min(viewport.width, window.innerWidth - 32) + 'px';
    container.appendChild(canvas);
    page.render({
      canvasContext: canvas.getContext('2d'),
      viewport: viewport,
    }).promise.then(function() { drawWatermark(canvas); });
  });
}

function showPage(num) {
  var container = document.getElementById('pdfContainer');
  container.innerHTML = '';
  pdfDoc.getPage(num).then(function(page) {
    var viewport = page.getViewport({ scale: getScale() });
    var canvas   = document.createElement('canvas');
    canvas.className = 'page-canvas';
    canvas.width  = viewport.width;
    canvas.height = viewport.height;
    canvas.style.width = Math.min(viewport.width, window.innerWidth - 32) + 'px';
    container.appendChild(canvas);
    page.render({
      canvasContext: canvas.getContext('2d'),
      viewport: viewport,
    }).promise.then(function() { drawWatermark(canvas); });
  });
  document.getElementById('prevBtn').disabled = (num <= 1);
  document.getElementById('nextBtn').disabled = (num >= pageCount);
  updatePageInfo();
}

function getScale() {
  var maxWidth = window.innerWidth - 64;
  return Math.min(1.5, maxWidth / 595);
}

function updatePageInfo() {
  if (PAGED) {
    document.getElementById('pageInfo').textContent =
      'Ukurasa ' + pageNum + ' / ' + pageCount;
  } else {
    document.getElementById('pageInfo').textContent = pageCount + ' kurasa';
  }
}

document.getElementById('prevBtn').addEventListener('click', function() {
  if (PAGED && pdfDoc && pageNum > 1) { pageNum--; showPage(pageNum); }
});
document.getElementById('nextBtn').addEventListener('click', function() {
  if (PAGED && pdfDoc && pageNum < pageCount) { pageNum++; showPage(pageNum); }
});
document.getElementById('pdfContainer').addEventListener('click', function(e) {
  if (!PAGED || !pdfDoc) return;
  if (e.clientX < window.innerWidth / 2) {
    if (pageNum > 1) { pageNum--; showPage(pageNum); }
  } else {
    if (pageNum < pageCount) { pageNum++; showPage(pageNum); }
  }
});
window.addEventListener('resize', function() {
  if (!pdfDoc) return;
  if (PAGED) showPage(pageNum); else renderAllPages();
});
</script>
</body>
</html>
''';
  }

  // ── Secure Text HTML ──────────────────────────────────────────────────────

  String _buildSecureTextHtml(String text, double fontSize, bool dark) {
    final bg        = dark ? '#1A1A2E' : '#FAFAFA';
    final fg        = dark ? '#E8E8F0' : '#1a1a2a';
    final wm        = _safeWatermark;
    final escaped   = _escapeHtml(text);

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  html, body { height:100%; }
  body {
    background: $bg;
    color: $fg;
    font-family: Georgia, 'Times New Roman', serif;
    font-size: ${fontSize}px;
    line-height: 1.85;
    letter-spacing: 0.3px;
    overflow-x: hidden;
    user-select: none;
    -webkit-user-select: none;
    cursor: default;
  }
  @media print { body { display:none !important; } }
  #content {
    max-width: 760px;
    margin: 0 auto;
    padding: 24px 20px 80px;
    white-space: pre-wrap;
    word-break: break-word;
  }
  /* ── Watermark overlay ── */
  #drm-wm {
    position: fixed;
    top: 0; left: 0; right: 0; bottom: 0;
    pointer-events: none;
    z-index: 9997;
    overflow: hidden;
  }
  .wm-row {
    position: absolute;
    left: -40%;
    width: 180%;
    white-space: nowrap;
    font-size: 13px;
    font-family: Arial, sans-serif;
    font-weight: bold;
    letter-spacing: 6px;
    color: rgba(100,100,100,0.07);
    transform: rotate(-22deg);
    transform-origin: left center;
  }
  /* ── Blur overlay ── */
  #drm-blur {
    display: none;
    position: fixed;
    top:0; left:0; right:0; bottom:0;
    background: ${dark ? 'rgba(10,10,20,0.97)' : 'rgba(240,240,250,0.97)'};
    z-index: 9999;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    cursor: pointer;
  }
  #drm-blur p     { color:$fg; font-size:17px; margin-top:14px; font-weight:bold; }
  #drm-blur small { color:${dark ? '#888' : '#666'}; font-size:12px; margin-top:6px; }
</style>
</head>
<body>

<!-- Blur overlay -->
<div id="drm-blur" onclick="this.style.display='none'">
  <div style="font-size:54px; text-align:center;">🔒</div>
  <p>Maudhui yamefichwa kwa usalama</p>
  <small>Bonyeza hapa kuendelea kusoma</small>
</div>

<!-- Watermark -->
<div id="drm-wm"></div>

<!-- Book content -->
<div id="content">$escaped</div>

<script>
${_securityJs()}

// ── Build tiled watermark rows ─────────────────────────────────────────────
(function() {
  var wm  = '$wm · $wm · $wm';
  var box = document.getElementById('drm-wm');
  var rowH = 90;
  var rows = Math.ceil(window.innerHeight / rowH) + 4;
  for (var i = 0; i < rows; i++) {
    var d = document.createElement('div');
    d.className = 'wm-row';
    d.style.top = (i * rowH - 40) + 'px';
    d.textContent = wm;
    box.appendChild(d);
  }
})();
</script>
</body>
</html>
''';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    if (_loading) return _loadingScreen();
    if (_error != null) return _errorScreen();

    // PDF: rebuild iframe on layout or dark mode change
    if (_fileType == 'pdf') {
      final settings = context.watch<SettingsProvider>();
      if (_pdfIframe != null && _pdfBase64 != null &&
          (_pdfLayoutBuilt != settings.readerLayout || _pdfDarkBuilt != _darkMode)) {
        _pdfLayoutBuilt = settings.readerLayout;
        _pdfDarkBuilt   = _darkMode;
        final newHtml = _buildSecurePdfHtml(
            _pdfBase64!, settings.readerLayout == ReaderLayout.paged, _darkMode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pdfIframe?.src = _trackedBlobUrl(newHtml);
        });
      }
      return _securePdfViewer(settings);
    }

    // Text: rebuild iframe on font size or dark mode change
    if (_fileType == 'txt') {
      if (_textIframe != null && _rawText != null &&
          (_textFontBuilt != _fontSize || _textDarkBuilt != _darkMode)) {
        _textFontBuilt = _fontSize;
        _textDarkBuilt = _darkMode;
        final newHtml = _buildSecureTextHtml(_rawText!, _fontSize, _darkMode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _textIframe?.src = _trackedBlobUrl(newHtml);
        });
      }
      return _secureTextViewer();
    }

    return _loadingScreen();
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  Widget _loadingScreen() => Scaffold(
    appBar: _buildAppBar(S.loading),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(S.openingSecure,
              style: TextStyle(color: AppTheme.textSecondary(context))),
        ],
      ),
    ),
  );

  // ── Error ────────────────────────────────────────────────────────────────

  Widget _errorScreen() => Scaffold(
    appBar: _buildAppBar(S.error),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  color: AppTheme.danger, size: 48),
            ),
            const SizedBox(height: 16),
            Text(S.failedOpen,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary(context))),
            const SizedBox(height: 8),
            Text(_error ?? '', textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary(context), height: 1.5)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                    onPressed: () => Navigator.pop(context), child: Text(S.back)),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(S.retry),
                  onPressed: _loadContent,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  // ── Secure PDF Viewer ─────────────────────────────────────────────────────

  Widget _securePdfViewer(SettingsProvider settings) {
    final isPaged = settings.readerLayout == ReaderLayout.paged;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.readBook),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        actions: [
          _drmBadge(),
          IconButton(
            tooltip: S.readerLayout,
            icon: Icon(isPaged
                ? Icons.menu_book_rounded : Icons.view_agenda_rounded,
                color: Colors.white),
            onPressed: () => _showLayoutPicker(settings),
          ),
          IconButton(
            tooltip: S.darkMode,
            icon: Icon(_darkMode
                ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _darkMode = !_darkMode),
          ),
        ],
      ),
      body: _viewId != null
          ? HtmlElementView(viewType: _viewId!)
          : const Center(child: CircularProgressIndicator()),
    );
  }

  // ── Secure Text Viewer ────────────────────────────────────────────────────

  Widget _secureTextViewer() {
    final isDark = _darkMode;
    final barBg     = isDark ? const Color(0xFF16213E) : Colors.white;
    final mutedColor = isDark ? const Color(0xFF9CA3AF) : AppTheme.textMuted;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      appBar: AppBar(
        title: Text(S.readBook),
        flexibleSpace: isDark ? null : Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        backgroundColor: isDark ? const Color(0xFF16213E) : null,
        actions: [
          _drmBadge(),
          IconButton(
            icon: Icon(isDark
                ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _darkMode = !_darkMode),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _textViewId != null
                ? HtmlElementView(viewType: _textViewId!)
                : const Center(child: CircularProgressIndicator()),
          ),
          // Font size controls
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: barBg,
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8, offset: const Offset(0, -3))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.format_size_rounded, color: mutedColor, size: 16),
                const SizedBox(width: 8),
                Text(S.textSize, style: TextStyle(color: mutedColor, fontSize: 12)),
                const Spacer(),
                _fontBtn(Icons.text_decrease_rounded,
                    () { if (_fontSize > 12) setState(() => _fontSize -= 2); }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('${_fontSize.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.bold,
                          color: AppTheme.primary, fontSize: 16)),
                ),
                _fontBtn(Icons.text_increase_rounded,
                    () { if (_fontSize < 28) setState(() => _fontSize += 2); }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DRM badge ─────────────────────────────────────────────────────────────

  Widget _drmBadge() => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.lock_rounded, color: Colors.white, size: 13),
      const SizedBox(width: 4),
      Text(S.secure, style: const TextStyle(color: Colors.white, fontSize: 11)),
    ]),
  );

  // ── Layout picker ─────────────────────────────────────────────────────────

  void _showLayoutPicker(SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(S.readerLayout,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _layoutOption(
                icon: Icons.view_agenda_rounded,
                title: S.layoutScroll,
                subtitle: S.layoutScrollHint,
                selected: settings.readerLayout == ReaderLayout.scroll,
                onTap: () { settings.setReaderLayout(ReaderLayout.scroll); Navigator.pop(ctx); },
              ),
              const SizedBox(height: 8),
              _layoutOption(
                icon: Icons.menu_book_rounded,
                title: S.layoutPaged,
                subtitle: S.layoutPagedHint,
                selected: settings.readerLayout == ReaderLayout.paged,
                onTap: () { settings.setReaderLayout(ReaderLayout.paged); Navigator.pop(ctx); },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _layoutOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.1)
              : AppTheme.bg(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.borderColor(context),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? AppTheme.primary : AppTheme.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary(context))),
                ],
              ),
            ),
            if (selected) const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _fontBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: AppTheme.primary, size: 18),
    ),
  );

  AppBar _buildAppBar(String title) => AppBar(
    title: Text(title),
    flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
  );
}
