import 'package:flutter/material.dart';

/// A single scale factor applied across fixed-size UI (fonts, icons,
/// spacing, button widths) so the game looks intentional on a tablet
/// instead of floating at phone size in the middle of a huge canvas.
///
/// Based on the screen's shorter side (stable across portrait/landscape)
/// relative to a ~390pt phone baseline (iPhone 14/15 width), capped at 1.6x
/// so an iPad doesn't get comically oversized text/buttons — the grid
/// itself already fills available space via `LayoutBuilder` in
/// game_screen.dart regardless of this scale.
double uiScale(BuildContext context) {
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  return (shortestSide / 390.0).clamp(1.0, 1.6);
}
