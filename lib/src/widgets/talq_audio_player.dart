import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/talq_theme.dart';

/// A clean, modern, WhatsApp-style audio player bubble.
///
/// Renders a circular play/pause button, an animated progress track
/// with a draggable thumb and an mm:ss timer. The widget is fully
/// self-contained: it owns its own [AudioPlayer] and disposes it
/// cleanly when removed.
class TalqAudioPlayer extends StatefulWidget {
  final String url;
  final TalqTheme theme;
  final bool isMine;

  const TalqAudioPlayer({
    super.key,
    required this.url,
    required this.theme,
    required this.isMine,
  });

  @override
  State<TalqAudioPlayer> createState() => _TalqAudioPlayerState();
}

class _TalqAudioPlayerState extends State<TalqAudioPlayer> {
  late final AudioPlayer _player;
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _hasError = false;

  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<void>? _completeSub;
  StreamSubscription<PlayerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.setReleaseMode(ReleaseMode.stop);

    _durationSub = _player.onDurationChanged.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d);
    });
    _positionSub = _player.onPositionChanged.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _state = s);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _state = PlayerState.stopped;
        _position = Duration.zero;
      });
    });

    // Prime the player so we can show the duration before playback.
    _player.setSourceUrl(widget.url).catchError((_) {
      if (!mounted) return;
      setState(() => _hasError = true);
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_hasError) {
      // try to recover once
      setState(() => _hasError = false);
      try {
        await _player.setSourceUrl(widget.url);
      } catch (_) {
        if (mounted) setState(() => _hasError = true);
        return;
      }
    }

    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final fg = widget.isMine ? theme.userTextColor : theme.agentTextColor;
    final accent = widget.isMine ? theme.userTextColor : theme.primaryColor;
    final track = fg.withValues(alpha: 0.18);

    final total = _duration.inMilliseconds == 0
        ? 1.0
        : _duration.inMilliseconds.toDouble();
    final value = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    final isPlaying = _state == PlayerState.playing;
    final remaining = _duration > _position ? _duration - _position : _duration;

    return SizedBox(
      width: 240,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlayButton(
            isPlaying: isPlaying,
            isError: _hasError,
            color: accent,
            onTap: _toggle,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    activeTrackColor: accent,
                    inactiveTrackColor: track,
                    thumbColor: accent,
                    overlayColor: accent.withValues(alpha: 0.15),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 14,
                    ),
                  ),
                  child: Slider(
                    min: 0,
                    max: total,
                    value: value > total ? total : value,
                    onChanged: _hasError
                        ? null
                        : (v) {
                            _player.seek(Duration(milliseconds: v.toInt()));
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _hasError
                            ? 'Unavailable'
                            : (isPlaying
                                  ? _format(_position)
                                  : _format(_duration)),
                        style: theme.bodyStyle.copyWith(
                          fontSize: 11,
                          color: fg.withValues(alpha: 0.75),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (!_hasError && isPlaying)
                        Text(
                          '-${_format(remaining)}',
                          style: theme.bodyStyle.copyWith(
                            fontSize: 11,
                            color: fg.withValues(alpha: 0.6),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool isError;
  final Color color;
  final VoidCallback onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.isError,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isError
                    ? Icons.refresh_rounded
                    : (isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                key: ValueKey(isError ? 'err' : (isPlaying ? 'pause' : 'play')),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
