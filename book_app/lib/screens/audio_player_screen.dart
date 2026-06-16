import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/language_provider.dart';
import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/safe_image.dart';

class AudioPlayerScreen extends StatefulWidget {
  final int    bookId;
  final String bookTitle;
  final String authorName;
  final String? coverImage;

  const AudioPlayerScreen({
    super.key,
    required this.bookId,
    required this.bookTitle,
    required this.authorName,
    this.coverImage,
  });

  @override
  State<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen>
    with TickerProviderStateMixin {
  final ApiService   _api    = ApiService();
  final AudioPlayer  _player = AudioPlayer();

  bool     _loading   = true;
  String?  _error;
  bool     _isPlaying = false;
  Duration _position  = Duration.zero;
  Duration _duration  = Duration.zero;
  double   _speed     = 1.0;

  late AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    _player.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state == PlayerState.playing);
      if (state == PlayerState.playing) {
        _rotateCtrl.repeat();
      } else {
        _rotateCtrl.stop();
      }
    });

    _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _position  = Duration.zero;
      });
      _rotateCtrl
        ..stop()
        ..reset();
    });

    _loadAudio();
  }

  Future<void> _loadAudio() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _api.fetchAudioBytes(widget.bookId);
      final bytes  = result['bytes'] as Uint8List;
      await _player.setSource(BytesSource(bytes));
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error   = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  Future<void> _skip(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final clamped = target.isNegative
        ? Duration.zero
        : (_duration > Duration.zero && target > _duration ? _duration : target);
    await _player.seek(clamped);
  }

  Future<void> _setSpeed(double speed) async {
    await _player.setPlaybackRate(speed);
    if (mounted) setState(() => _speed = speed);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    context.watch<LanguageProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: _loading
          ? _loadingView()
          : _error != null
              ? _errorView()
              : _playerView(),
    );
  }

  AppBar _appBar() => AppBar(
    backgroundColor: const Color(0xFF1A1A2E),
    foregroundColor: Colors.white,
    elevation: 0,
    title: Text(S.listenBook),
  );

  Widget _loadingView() => Scaffold(
    backgroundColor: const Color(0xFF1A1A2E),
    appBar: _appBar(),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(S.loadingAudio,
              style: const TextStyle(color: Colors.white70)),
        ],
      ),
    ),
  );

  Widget _errorView() => Scaffold(
    backgroundColor: const Color(0xFF1A1A2E),
    appBar: _appBar(),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.headset_off_rounded,
                color: AppTheme.danger, size: 64),
            const SizedBox(height: 16),
            Text(S.failedAudio,
                style: const TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, height: 1.5)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh_rounded),
              label: Text(S.retry),
              onPressed: _loadAudio,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _playerView() {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return CustomScrollView(
      slivers: [
        // ── Header / Album Art ──
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          title: Text(S.listenBook),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.coverImage != null)
                  Opacity(
                    opacity: 0.25,
                    child: safeNetworkImage(widget.coverImage,
                        fit: BoxFit.cover),
                  ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x661A1A2E), Color(0xFF1A1A2E)],
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: RotationTransition(
                      turns: _rotateCtrl,
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.5),
                              blurRadius: 30),
                          ],
                        ),
                        child: ClipOval(
                          child: widget.coverImage != null
                              ? safeNetworkImage(widget.coverImage,
                                  fit: BoxFit.cover)
                              : Container(
                                  decoration: const BoxDecoration(
                                      gradient: AppTheme.primaryGradient),
                                  child: const Icon(Icons.headphones_rounded,
                                      color: Colors.white, size: 60)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Controls ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Author
                Text(widget.bookTitle,
                    style: const TextStyle(color: Colors.white,
                        fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.authorName,
                    style: const TextStyle(color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 24),

                // Progress bar
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                    activeTrackColor: AppTheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: AppTheme.primary,
                    overlayColor: AppTheme.primary.withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (v) async {
                      final target = Duration(
                          milliseconds: (v * _duration.inMilliseconds).round());
                      await _player.seek(target);
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_position),
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    Text(_fmt(_duration),
                        style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 20),

                // Play/Pause + Skip
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Skip back 15s
                    IconButton(
                      icon: const Icon(Icons.replay_10_rounded,
                          color: Colors.white70, size: 36),
                      onPressed: () => _skip(-15),
                      tooltip: S.skipBack,
                    ),
                    const SizedBox(width: 16),
                    // Play / Pause
                    GestureDetector(
                      onTap: _togglePlay,
                      child: Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20, offset: const Offset(0, 6))],
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white, size: 40),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Skip forward 15s
                    IconButton(
                      icon: const Icon(Icons.forward_10_rounded,
                          color: Colors.white70, size: 36),
                      onPressed: () => _skip(15),
                      tooltip: S.skipFwd,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Speed selector
                Text(S.speed,
                    style: const TextStyle(color: Colors.white70,
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Row(
                  children: [0.75, 1.0, 1.25, 1.5, 2.0].map((s) {
                    final active = (_speed - s).abs() < 0.01;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _setSpeed(s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: active
                                ? AppTheme.primary
                                : Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: active
                                  ? AppTheme.primary
                                  : Colors.white24),
                          ),
                          child: Text(
                            '${s}x',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: active ? Colors.white : Colors.white60,
                              fontSize: 12,
                              fontWeight: active
                                  ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Hint
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Colors.white54, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(S.audioHint,
                          style: const TextStyle(color: Colors.white54,
                              fontSize: 12, height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
