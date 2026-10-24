import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'theme_service.dart';

/// "Share my result": renders a square result card straight onto a canvas
/// (no widget on screen needed — a RepaintBoundary capture would need the
/// card to actually be painted somewhere) and hands it to the system share
/// sheet together with a short text + store link.
class ShareService {
  static const _playUrl =
      'https://play.google.com/store/apps/details?id=com.nttqn.number99';

  // No public App Store URL yet — the landing page links to both stores.
  static const _landingUrl = 'https://nttqn.github.io/number99-app/';

  static String get storeUrl =>
      defaultTargetPlatform == TargetPlatform.iOS ? _landingUrl : _playUrl;

  /// [headline] is the big number (score / time / count), [caption] the
  /// word under it, [detail] one extra line (level reached, date, ...).
  static Future<void> shareResult({
    required String modeTitle,
    required String headline,
    required String caption,
    required String detail,
    required String text,
    Rect? origin,
  }) async {
    try {
      final png = await _renderCard(
        theme: ThemeService.current.value,
        modeTitle: modeTitle,
        headline: headline,
        caption: caption,
        detail: detail,
      );
      await SharePlus.instance.share(
        ShareParams(
          text: '$text\n$storeUrl',
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: '99numbers_result.png',
            ),
          ],
          // Required on iPad, where the share sheet is a popover that needs
          // an anchor — without it the share call throws.
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      // Share cancelled / unavailable — nothing to recover.
    }
  }

  static const double _size = 1080;

  static Future<Uint8List> _renderCard({
    required GameTheme theme,
    required String modeTitle,
    required String headline,
    required String caption,
    required String detail,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = _size / 2;

    canvas.drawRect(
      const Rect.fromLTWH(0, 0, _size, _size),
      Paint()..color = theme.menuBg,
    );

    // Same "99" badge as the main menu.
    const badgeCenter = Offset(center, 230);
    canvas.drawCircle(
      badgeCenter.translate(0, 10),
      130,
      Paint()..color = Colors.black.withValues(alpha: 0.15),
    );
    canvas.drawCircle(badgeCenter, 130, Paint()..color = Colors.white);
    canvas.drawCircle(
      badgeCenter,
      124,
      Paint()
        ..color = theme.targetBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14,
    );
    _text(canvas, '99', 120, theme.targetText, badgeCenter.dy, w: 900);

    _text(canvas, '99 NUMBERS', 72, theme.title, 450, w: 900);

    // Mode pill.
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: const Offset(center, 550),
        width: 520,
        height: 80,
      ),
      const Radius.circular(40),
    );
    canvas.drawRRect(pill, Paint()..color = theme.hud);
    _text(canvas, modeTitle, 40, theme.hudLabel, 550, w: 800);

    _text(canvas, headline, 170, theme.targetText, 710, w: 900);
    _text(canvas, caption, 44, theme.title, 830, w: 700);
    _text(canvas, detail, 36, theme.title.withValues(alpha: 0.75), 890);
    _text(canvas, 'Can you beat me?', 44, theme.title, 990, w: 800);

    final image = await recorder.endRecording().toImage(
      _size.toInt(),
      _size.toInt(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Draws a single centered line of text with its vertical center at [cy].
  static void _text(
    Canvas canvas,
    String text,
    double size,
    Color color,
    double cy, {
    int w = 500,
  }) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: TextAlign.center, maxLines: 1),
          )
          ..pushStyle(
            ui.TextStyle(
              color: color,
              fontSize: size,
              fontWeight: FontWeight.values[(w ~/ 100) - 1],
            ),
          )
          ..addText(text);
    final paragraph = builder.build()
      ..layout(const ui.ParagraphConstraints(width: _size));
    canvas.drawParagraph(paragraph, Offset(0, cy - paragraph.height / 2));
  }
}
