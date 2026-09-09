import 'package:flutter/material.dart';

import '../utils/responsive.dart';

/// Big bold banner text ("LEVEL 3", ...) that pops into the center of the
/// screen, holds, then shrinks away — 2 seconds total. Same choreography as
/// dino-egg-shooter's AnnouncementText (a Flame component there; this is
/// the plain-Flutter equivalent, since this app has no Flame game loop).
class LevelAnnouncement extends StatefulWidget {
  const LevelAnnouncement({
    super.key,
    required this.text,
    required this.onComplete,
  });

  final String text;
  final VoidCallback onComplete;

  @override
  State<LevelAnnouncement> createState() => _LevelAnnouncementState();
}

class _LevelAnnouncementState extends State<LevelAnnouncement>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.15,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 300,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.15,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 200,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 1000),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 500,
      ),
    ]).animate(_controller);
    _controller.forward().whenComplete(widget.onComplete);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: this is a decorative overlay, not a blocker — the round
    // timer keeps running underneath and the player can keep tapping.
    final scale = uiScale(context);
    return IgnorePointer(
      child: Center(
        child: ScaleTransition(
          scale: _scale,
          child: Text(
            widget.text,
            style: TextStyle(
              color: Colors.white,
              fontSize: 44 * scale,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              shadows: const [
                Shadow(
                  color: Colors.black87,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
