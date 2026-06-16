import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../providers/settings_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final ApiService _api = ApiService();

  bool    _loading     = true;
  String? _error;
  String? _fileType;
  String? _textContent;
  String? _viewId;
  ReaderLayout? _pdfLayoutBuilt;
  bool? _pdfDarkBuilt;
  web.HTMLIFrameElement? _pdfIframe;
  String? _pdfBase64;

  double _fontSize = 16;
  bool   _darkMode = false;

  // ── Page-by-page (Layout 2) ──
  final PageController _pageController = PageController();
  List<String> _pages = [];
  int _currentPage = 0;
  // "Funguo" ya hali iliyotumika kuhesabu kurasa (ili kuepuka kuhesabu mara kwa mara)
  String _pagesKey = '';

  @override
  void initState() {
    super.initState();
    // Anza na mandhari sawa na mfumo mzima (Dark/Light Mode iliyochaguliwa
    // kwenye Mipangilio), msomaji anaweza kubadili tena ndani ya kisomaji.
    _darkMode = context.read<SettingsProvider>().isDark;
    _loadContent();
  }

  Future<void> _loadContent() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.fetchBookBytes(widget.bookId);
      final bytes  = result['bytes'] as Uint8List;
      final ct     = (result['content_type'] as String).toLowerCase();

      if (ct.contains('pdf')) {
        final layout = mounted
            ? context.read<SettingsProvider>().readerLayout
            : ReaderLayout.scroll;
        await _setupPdfViewer(bytes, layout);
      } else {
        if (mounted) {
          setState(() {
            _fileType    = 'txt';
            _textContent = utf8.decode(bytes, allowMalformed: true);
            _loading     = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _setupPdfViewer(Uint8List pdfBytes, ReaderLayout layout) async {
    // Geuza bytes kuwa base64 ili tupeleke kwa JavaScript
    final base64Data = base64Encode(pdfBytes);
    final viewId     = 'secure-pdf-${widget.bookId}-${DateTime.now().millisecondsSinceEpoch}';

    // HTML kamili na PDF.js — inaonyesha PDF kama canvas, si kama file
    // Imezuia: right-click, Ctrl+S, Ctrl+P, Ctrl+U, drag, selection
    final html = _buildSecurePdfHtml(base64Data, layout == ReaderLayout.paged, _darkMode);
    _pdfLayoutBuilt = layout;
    _pdfDarkBuilt = _darkMode;
    _pdfBase64 = base64Data;

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int _) {
        final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement;
        iframe.style.width   = '100%';
        iframe.style.height  = '100%';
        iframe.style.border  = 'none';
        iframe.style.background = '#525659';

        // Weka HTML moja kwa moja kwenye iframe
        final blob    = web.Blob(
          [html.toJS].toJS,
          web.BlobPropertyBag(type: 'text/html'),
        );
        iframe.src = web.URL.createObjectURL(blob);
        _pdfIframe = iframe;
        return iframe;
      },
    );

    if (mounted) {
      setState(() {
        _fileType = 'pdf';
        _viewId   = viewId;
        _loading  = false;
      });
    }
  }

  /// Tengeneza HTML yenye PDF.js inayoonyesha PDF kama canvas
  /// Imezuia download, right-click, na keyboard shortcuts za kudownload
  String _buildSecurePdfHtml(String base64Data, bool paged, bool dark) {
    // Mwanga wa kurasa nyeupe za PDF unaweza kuumiza macho gizani.
    // Tunapunguza mng'ao kwa "filter" ya CSS bila kubadili PDF halisi.
    // Tunapunguza mng'ao bila "invert" — invert huharibu rangi za picha
    // (zinaonekana kama negative). Kupunguza brightness/contrast tu
    // kunazima mwanga mkali wa kurasa nyeupe bila kubadilisha rangi za picha.
    final pageFilter = dark
        ? 'filter: brightness(0.78) contrast(1.05);'
        : '';
    final bodyBg = dark ? '#0d0d0f' : '#525659';
    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Soma Kitabu</title>
<script src="https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    background: $bodyBg;
    font-family: Arial, sans-serif;
    overflow-x: hidden;
    user-select: none;
    -webkit-user-select: none;
  }
  #toolbar {
    position: fixed;
    top: 0; left: 0; right: 0;
    background: #323639;
    color: white;
    padding: 8px 16px;
    display: flex;
    align-items: center;
    gap: 12px;
    z-index: 100;
    box-shadow: 0 2px 4px rgba(0,0,0,0.3);
  }
  #toolbar button {
    background: #4a4e51;
    color: white;
    border: none;
    padding: 6px 14px;
    border-radius: 4px;
    cursor: pointer;
    font-size: 14px;
  }
  #toolbar button:hover { background: #5a5e61; }
  #toolbar button:disabled { opacity: 0.4; cursor: not-allowed; }
  #pageInfo { color: #ccc; font-size: 13px; flex: 1; text-align: center; }
  #loading {
    position: fixed;
    top: 50%; left: 50%;
    transform: translate(-50%, -50%);
    color: white;
    font-size: 16px;
    text-align: center;
  }
  #pdfContainer {
    margin-top: 52px;
    padding: 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
  }
  .page-canvas {
    box-shadow: 0 4px 12px rgba(0,0,0,0.4);
    display: block;
    max-width: 100%;
    $pageFilter
  }
  /* Zuia kuchagua na kuchora picha */
  canvas {
    pointer-events: none;
    -webkit-user-drag: none;
  }
</style>
</head>
<body>

<div id="toolbar">
  <button id="prevBtn" disabled>&#8592; Iliyopita</button>
  <span id="pageInfo">Inapakia...</span>
  <button id="nextBtn" disabled>Inayofuata &#8594;</button>
</div>

<div id="loading">
  <div>Inafungua kitabu...</div>
</div>

<div id="pdfContainer"></div>

<script>
// =============================================
// ZUIA DOWNLOAD NA CHAGUO ZOTE
// =============================================

// Zuia right-click
document.addEventListener('contextmenu', function(e) { e.preventDefault(); return false; });

// Zuia keyboard shortcuts: Ctrl+S, Ctrl+P, Ctrl+U, Ctrl+A, F12
document.addEventListener('keydown', function(e) {
  var blocked = (e.ctrlKey || e.metaKey) &&
    ['s','p','u','a','c','x','j'].includes(e.key.toLowerCase());
  if (blocked || e.key === 'F12' || e.key === 'PrintScreen') {
    e.preventDefault();
    e.stopPropagation();
    return false;
  }
});

// Zuia drag na drop
document.addEventListener('dragstart', function(e) { e.preventDefault(); });

// Zuia print dialog
window.onbeforeprint = function() { return false; };

// =============================================
// PDF.JS VIEWER
// =============================================

pdfjsLib.GlobalWorkerOptions.workerSrc =
  'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';

var pdfDoc    = null;
var pageNum   = 1;
var pageCount = 0;
var rendering = false;
var PAGED     = $paged;

// Decode base64 PDF data
var base64 = '$base64Data';
var binary = atob(base64);
var bytes  = new Uint8Array(binary.length);
for (var i = 0; i < binary.length; i++) {
  bytes[i] = binary.charCodeAt(i);
}

// Fungua PDF kutoka kwa bytes (si URL — haiwezi kupakuliwa)
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

function renderAllPages() {
  var container = document.getElementById('pdfContainer');
  container.innerHTML = '';

  for (var i = 1; i <= pageCount; i++) {
    renderPage(i, container);
  }
}

function renderPage(num, container) {
  pdfDoc.getPage(num).then(function(page) {
    var viewport  = page.getViewport({ scale: getScale() });
    var canvas    = document.createElement('canvas');
    canvas.className = 'page-canvas';
    canvas.width  = viewport.width;
    canvas.height = viewport.height;
    canvas.style.width = Math.min(viewport.width, window.innerWidth - 32) + 'px';

    container.appendChild(canvas);

    page.render({
      canvasContext: canvas.getContext('2d'),
      viewport: viewport
    });
  });
}

// Onyesha ukurasa mmoja tu (Layout: Ukurasa kwa Ukurasa)
function showPage(num) {
  var container = document.getElementById('pdfContainer');
  container.innerHTML = '';
  pdfDoc.getPage(num).then(function(page) {
    var viewport = page.getViewport({ scale: getScale() });
    var canvas    = document.createElement('canvas');
    canvas.className = 'page-canvas';
    canvas.width  = viewport.width;
    canvas.height = viewport.height;
    canvas.style.width = Math.min(viewport.width, window.innerWidth - 32) + 'px';

    container.appendChild(canvas);

    page.render({
      canvasContext: canvas.getContext('2d'),
      viewport: viewport
    });
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
    document.getElementById('pageInfo').textContent =
      pageCount + ' kurasa';
  }
}

// Vitufe vya kusogea kati ya kurasa (Layout: Ukurasa kwa Ukurasa)
document.getElementById('prevBtn').addEventListener('click', function() {
  if (PAGED && pdfDoc && pageNum > 1) {
    pageNum--;
    showPage(pageNum);
  }
});
document.getElementById('nextBtn').addEventListener('click', function() {
  if (PAGED && pdfDoc && pageNum < pageCount) {
    pageNum++;
    showPage(pageNum);
  }
});

// Bonyeza eneo la kushoto/kulia la ukurasa kusogea (kama kitabu halisi)
document.getElementById('pdfContainer').addEventListener('click', function(e) {
  if (!PAGED || !pdfDoc) return;
  var x = e.clientX;
  var half = window.innerWidth / 2;
  if (x < half) {
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Gawanya maandishi katika "kurasa" zinazofaa kwenye eneo lililotolewa
  /// (width x height), kwa kutumia TextPainter kupima urefu wa maandishi.
  void _ensurePages(double width, double height, TextStyle style) {
    final key = '${width.toStringAsFixed(1)}_${height.toStringAsFixed(1)}'
        '_${_fontSize}_${(_textContent ?? '').length}';
    if (key == _pagesKey) return;
    _pagesKey = key;

    final text = _textContent ?? '';
    final pages = <String>[];
    int start = 0;
    final n = text.length;
    const chunkSize = 8000;

    while (start < n) {
      final end = (start + chunkSize < n) ? start + chunkSize : n;
      final chunk = text.substring(start, end);
      final painter = TextPainter(
        text: TextSpan(text: chunk, style: style),
        textDirection: TextDirection.ltr,
        maxLines: null,
      )..layout(maxWidth: width);

      int cut;
      if (painter.height <= height) {
        // Chunk nzima inatoshea - kama ndio mwisho wa maandishi, tumia yote
        cut = chunk.length;
      } else {
        final pos = painter.getPositionForOffset(Offset(width, height));
        cut = pos.offset;
        if (cut <= 0) cut = chunk.length;
      }

      int actualCut = start + cut;
      if (actualCut < n) {
        // Vunja kwenye nafasi tupu ya karibu ili usikate neno katikati
        final breakAt = text.lastIndexOf(RegExp(r'\s'), actualCut);
        if (breakAt > start) actualCut = breakAt + 1;
      }
      if (actualCut <= start) actualCut = end; // epuka mzunguko usio na mwisho

      pages.add(text.substring(start, actualCut));
      start = actualCut;
    }

    if (pages.isEmpty) pages.add('');
    _pages = pages;
    if (_currentPage >= _pages.length) _currentPage = _pages.length - 1;
    if (_currentPage < 0) _currentPage = 0;
  }

  void _goToPage(int page) {
    if (page < 0 || page >= _pages.length) return;
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 280), curve: Curves.easeInOut);
  }

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
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              _layoutOption(
                icon: Icons.view_agenda_rounded,
                title: S.layoutScroll,
                subtitle: S.layoutScrollHint,
                selected: settings.readerLayout == ReaderLayout.scroll,
                onTap: () {
                  settings.setReaderLayout(ReaderLayout.scroll);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
              _layoutOption(
                icon: Icons.menu_book_rounded,
                title: S.layoutPaged,
                subtitle: S.layoutPagedHint,
                selected: settings.readerLayout == ReaderLayout.paged,
                onTap: () {
                  settings.setReaderLayout(ReaderLayout.paged);
                  Navigator.pop(ctx);
                },
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
            Icon(icon,
                color: selected
                    ? AppTheme.primary
                    : AppTheme.textSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected
                          ? AppTheme.primary
                          : AppTheme.textPrimary(context))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary(context))),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>(); // rebuild on lang change
    if (_loading) return _loadingScreen();
    if (_error != null) return _errorScreen();
    if (_fileType == 'pdf') {
      final settings = context.watch<SettingsProvider>();
      // Kama mtumiaji amebadili mtindo wa kusoma, mwambie iframe ibadilishe
      // mtindo bila kupakia upya PDF nzima (haraka na salama zaidi)
      if (_pdfIframe != null && _pdfBase64 != null &&
          (_pdfLayoutBuilt != settings.readerLayout ||
              _pdfDarkBuilt != _darkMode)) {
        _pdfLayoutBuilt = settings.readerLayout;
        _pdfDarkBuilt = _darkMode;
        final isPaged = settings.readerLayout == ReaderLayout.paged;
        final newHtml = _buildSecurePdfHtml(_pdfBase64!, isPaged, _darkMode);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final iframe = _pdfIframe;
          if (iframe == null) return;
          // Pakia upya iframe na HTML mpya yenye mtindo uliochaguliwa.
          // Njia ya uhakika zaidi kuliko postMessage/callMethod kwa sababu
          // haitegemei kupata contentWindow ya iframe.
          final blob = web.Blob(
            [newHtml.toJS].toJS,
            web.BlobPropertyBag(type: 'text/html'),
          );
          iframe.src = web.URL.createObjectURL(blob);
        });
      }
      return _securePdfViewer(settings);
    }
    return _secureTextViewer();
  }

  // ── Loading ──
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

  // ── Error ──
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
                style: TextStyle(fontSize: 18,
                    fontWeight: FontWeight.bold, color: AppTheme.textPrimary(context))),
            const SizedBox(height: 8),
            Text(_error ?? '', textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary(context), height: 1.5)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(S.back),
                ),
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

  // ── Secure PDF Viewer (canvas — haiwezi kupakuliwa) ──
  Widget _securePdfViewer(SettingsProvider settings) {
    final isPaged = settings.readerLayout == ReaderLayout.paged;
    return Scaffold(
      appBar: AppBar(
        title: Text(S.readBook),
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        // HAKUNA kitufe cha download au share
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(S.secure, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
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

  // ── Secure Text Viewer ──
  Widget _secureTextViewer() {
    final settings   = context.watch<SettingsProvider>();
    final bg         = _darkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final textColor  = _darkMode ? const Color(0xFFE8E8F0) : AppTheme.textDark;
    final mutedColor = _darkMode ? const Color(0xFF9CA3AF) : AppTheme.textMuted;
    final isPaged    = settings.readerLayout == ReaderLayout.paged;
    final textStyle  = TextStyle(fontSize: _fontSize,
        height: 1.8, color: textColor, letterSpacing: 0.2);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(S.readBook),
        flexibleSpace: _darkMode ? null : Container(
            decoration: const BoxDecoration(gradient: AppTheme.headerGradient)),
        backgroundColor: _darkMode ? const Color(0xFF16213E) : null,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, color: Colors.white, size: 13),
                const SizedBox(width: 4),
                Text(S.secure, style: const TextStyle(color: Colors.white, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            tooltip: S.readerLayout,
            icon: Icon(isPaged
                ? Icons.menu_book_rounded : Icons.view_agenda_rounded,
                color: Colors.white),
            onPressed: () => _showLayoutPicker(settings),
          ),
          IconButton(
            icon: Icon(_darkMode
                ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _darkMode = !_darkMode),
          ),
        ],
      ),
      body: isPaged
          ? _pagedBody(textStyle, mutedColor)
          : _scrollBody(textStyle, mutedColor),
    );
  }

  // ── Layout 1: Kushuka Chini (Endelevu) ──
  Widget _scrollBody(TextStyle textStyle, Color mutedColor) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Text(_textContent ?? '', style: textStyle),
          ),
        ),
        _bottomControls(mutedColor),
      ],
    );
  }

  // ── Layout 2: Ukurasa kwa Ukurasa ──
  Widget _pagedBody(TextStyle textStyle, Color mutedColor) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const pagePadding = 22.0;
              final pageWidth  = constraints.maxWidth - pagePadding * 2;
              final pageHeight = constraints.maxHeight - pagePadding * 2;
              _ensurePages(pageWidth, pageHeight, textStyle);

              return Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.all(pagePadding),
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(_pages[i], style: textStyle),
                      ),
                    ),
                  ),
                  // Eneo la kushoto - ukurasa uliopita
                  Positioned(
                    left: 0, top: 0, bottom: 0, width: 56,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _goToPage(_currentPage - 1),
                    ),
                  ),
                  // Eneo la kulia - ukurasa unaofuata
                  Positioned(
                    right: 0, top: 0, bottom: 0, width: 56,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _goToPage(_currentPage + 1),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        _pagerBar(mutedColor),
        _bottomControls(mutedColor),
      ],
    );
  }

  Widget _pagerBar(Color mutedColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF16213E) : Colors.white,
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: S.prevPage,
            icon: Icon(Icons.chevron_left_rounded, color: mutedColor),
            onPressed: _currentPage > 0
                ? () => _goToPage(_currentPage - 1) : null,
          ),
          Expanded(
            child: Text(
              _pages.isEmpty
                  ? ''
                  : '${S.pageOf} ${_currentPage + 1} / ${_pages.length}',
              textAlign: TextAlign.center,
              style: TextStyle(color: mutedColor, fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: S.nextPage,
            icon: Icon(Icons.chevron_right_rounded, color: mutedColor),
            onPressed: _currentPage < _pages.length - 1
                ? () => _goToPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  // Vidhibiti vya ukubwa wa maandishi (chini ya skrini)
  Widget _bottomControls(Color mutedColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF16213E) : Colors.white,
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 8, offset: const Offset(0, -3))],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(Icons.format_size_rounded,
              color: mutedColor, size: 16),
          const SizedBox(width: 8),
          Text(S.textSize,
              style: TextStyle(color: mutedColor, fontSize: 12)),
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
    );
  }

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
