import 'package:flutter/material.dart';

import '../core/app_theme.dart';

/// The Safer Uni shield, drawn in code so it stays sharp at any size and
/// matches the launcher icon. With [onDark] it draws just the shield (for
/// navy headers); otherwise a navy rounded tile behind it.
class SaferUniLogo extends StatelessWidget {
  const SaferUniLogo({super.key, this.size = 44, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(withTile: !onDark)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.withTile});

  final bool withTile;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    if (withTile) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
        Paint()..color = AppTheme.primary,
      );
    }

    // Shield
    final w = s * (withTile ? 0.56 : 0.78);
    final h = w * 1.14;
    final cx = s / 2, cy = s / 2;
    final left = cx - w / 2, right = cx + w / 2;
    final top = cy - h / 2, bottom = cy + h / 2;
    final r = w * 0.12;
    final shield = Path()
      ..moveTo(left + r, top)
      ..lineTo(right - r, top)
      ..quadraticBezierTo(right, top, right, top + r)
      ..quadraticBezierTo(right, cy + h * 0.18, cx, bottom)
      ..quadraticBezierTo(left, cy + h * 0.18, left, top + r)
      ..quadraticBezierTo(left, top, left + r, top)
      ..close();
    canvas.drawPath(shield, Paint()..color = Colors.white);

    // Exclamation mark
    final k = w / 560;
    final orange = Paint()..color = AppTheme.accent;
    final barW = 70 * k, barH = 230 * k;
    final barTop = cy - 180 * k;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - barW / 2, barTop, barW, barH),
        Radius.circular(barW / 2),
      ),
      orange,
    );
    final dot = 80 * k;
    canvas.drawCircle(
      Offset(cx, barTop + barH + 45 * k + dot / 2),
      dot / 2,
      orange,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.withTile != withTile;
}
