import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/book_provider.dart';
import '../theme/app_theme.dart';

class ReaderScreen extends StatefulWidget {
  final int bookId;
  const ReaderScreen({super.key, required this.bookId});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late Future<String> _contentFuture;
  double _fontSize    = 16;
  bool   _darkMode    = false;
  bool   _showToolbar = true;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _contentFuture =
        context.read<BookProvider>().fetchBookContent(widget.bookId);
    _scroll.addListener(() {
      if (_scroll.position.userScrollDirection.name == 'forward' &&
          !_showToolbar) {
        setState(() => _showToolbar = true);
      } else if (_scroll.position.userScrollDirection.name == 'reverse' &&
          _showToolbar) {
        setState(() => _showToolbar = false);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg   = _darkMode ? const Color(0xFF1A1A2E) : Colors.white;
    final text = _darkMode ? const Color(0xFFE8E8F0) : AppTheme.textDark;

    return Scaffold(
      backgroundColor: bg,
      body: FutureBuilder<String>(
        future: _contentFuture,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 16),
                  Text('Inapakia kitabu...', style: TextStyle(color: AppTheme.textMuted)),
                ],
              )),
            );
          }
          if (snap.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Hitilafu')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 56),
                    const SizedBox(height: 16),
                    Text('${snap.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.textMuted)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Rudi Nyuma'),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              // ── Content ──
              SingleChildScrollView(
                controller: _scroll,
                padding: EdgeInsets.fromLTRB(
                    20, _showToolbar ? 100 : 20, 20, 100),
                child: SelectableText(
                  snap.data ?? '',
                  style: TextStyle(
                    fontSize: _fontSize,
                    height: 1.8,
                    color: text,
                    letterSpacing: 0.2,
                  ),
                ),
              ),

              // ── Top toolbar ──
              AnimatedSlide(
                duration: const Duration(milliseconds: 200),
                offset: _showToolbar ? Offset.zero : const Offset(0, -1),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showToolbar ? 1 : 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: _darkMode
                          ? const LinearGradient(
                              colors: [Color(0xFF16213E), Color(0xFF1A1A2E)])
                          : AppTheme.headerGradient,
                    ),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Expanded(
                            child: Text('Soma Kitabu',
                              style: TextStyle(color: Colors.white,
                                  fontWeight: FontWeight.w600, fontSize: 16),
                              overflow: TextOverflow.ellipsis),
                          ),
                          IconButton(
                            icon: Icon(
                              _darkMode
                                  ? Icons.light_mode_rounded
                                  : Icons.dark_mode_rounded,
                              color: Colors.white),
                            onPressed: () => setState(() => _darkMode = !_darkMode),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Bottom font controls ──
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 200),
                  offset: _showToolbar ? Offset.zero : const Offset(0, 1),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showToolbar ? 1 : 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: _darkMode
                            ? const Color(0xFF16213E)
                            : Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12, offset: const Offset(0, -4))
                        ],
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.format_size_rounded,
                              color: AppTheme.textMuted, size: 16),
                          const SizedBox(width: 8),
                          const Text('Ukubwa wa Maandishi',
                            style: TextStyle(color: AppTheme.textMuted,
                                fontSize: 12)),
                          const Spacer(),
                          _fontBtn(Icons.text_decrease_rounded, () {
                            if (_fontSize > 12) {
                              setState(() => _fontSize -= 2);
                            }
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('${_fontSize.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary, fontSize: 16)),
                          ),
                          _fontBtn(Icons.text_increase_rounded, () {
                            if (_fontSize < 28) {
                              setState(() => _fontSize += 2);
                            }
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _fontBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
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
  }
}
