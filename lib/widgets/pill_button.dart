import 'package:flutter/material.dart';

/// A chunky, embossed-looking rounded button matching the original game's
/// cartoony HUD button style (flat top color + darker bottom "shadow" edge).
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
    this.badge,
  });

  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final IconData? icon;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final baseColor = disabled ? Colors.grey.shade400 : color;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: baseColor,
          borderRadius: BorderRadius.circular(14),
          elevation: disabled ? 0 : 4,
          shadowColor: baseColor.withValues(alpha: 0.6),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  bottom: BorderSide(color: Colors.black.withValues(alpha: 0.25), width: 3),
                ),
              ),
              // FittedBox guarantees the icon+label never overflows the
              // button on a narrow screen — an unscaled Row whose content
              // is just slightly wider than the button (e.g. "RESTART",
              // the longest label) clips on the right instead of shrinking,
              // which defeats the Container's centering and reads as
              // "text not centered".
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, color: Colors.white, size: 20),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
