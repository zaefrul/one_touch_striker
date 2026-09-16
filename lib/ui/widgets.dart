import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(text, textAlign: TextAlign.center,
      style: StrikerText.eyebrow.copyWith(color: color));
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding, this.color, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: color ?? StrikerColors.raised,
      borderRadius: BorderRadius.circular(StrikerSpace.radius),
      border: Border.all(color: borderColor ?? StrikerColors.outline),
    ),
    child: Padding(
      padding: padding ?? const EdgeInsets.all(StrikerSpace.edge),
      child: child,
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.buttonKey});
  final String label;
  final VoidCallback? onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      key: buttonKey,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(label, textAlign: TextAlign.center),
      ),
    ),
  );
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: icon == null
        ? OutlinedButton(onPressed: onPressed, child: Text(label, textAlign: TextAlign.center))
        : OutlinedButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18),
            label: Text(label, textAlign: TextAlign.center)),
  );
}

class QuietButton extends StatelessWidget {
  const QuietButton({super.key, required this.label, required this.onPressed, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => icon == null
      ? TextButton(onPressed: onPressed, child: Text(label))
      : TextButton.icon(onPressed: onPressed, icon: Icon(icon, size: 18), label: Text(label));
}

class StatChip extends StatelessWidget {
  const StatChip(this.label, this.value, {super.key, this.primary = false, this.urgent = false});
  final String label, value;
  final bool primary, urgent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: StrikerText.statLabel),
      Text(value, style: StrikerText.statValue.copyWith(
        fontSize: primary ? 36 : 28,
        color: urgent ? StrikerColors.coral : primary ? StrikerColors.gold : StrikerColors.text,
      )),
    ],
  );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 14),
    child: Eyebrow(text),
  );
}

class ModeTile extends StatelessWidget {
  const ModeTile({super.key, required this.title, required this.subtitle,
      required this.onTap, this.glyph, this.progress});
  final String title, subtitle;
  final VoidCallback? onTap;
  final Widget? glyph;
  final double? progress;

  @override
  Widget build(BuildContext context) => Material(
    color: StrikerColors.raised,
    borderRadius: BorderRadius.circular(StrikerSpace.radius),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(StrikerSpace.radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(StrikerSpace.radius),
          border: Border.all(color: StrikerColors.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            if (glyph != null) ...[
              SizedBox(width: 40, height: 40, child: Center(child: glyph)),
              const SizedBox(width: 12),
            ],
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: StrikerText.button.copyWith(color: StrikerColors.text, letterSpacing: .6)),
              const SizedBox(height: 4),
              Text(subtitle, style: StrikerText.caption),
              if (progress != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0.0, 1.0),
                    minHeight: 4,
                    color: StrikerColors.gold,
                    backgroundColor: StrikerColors.outline,
                  ),
                ),
              ],
            ])),
            const Icon(Icons.chevron_right_rounded, color: StrikerColors.muted),
          ]),
        ),
      ),
    ),
  );
}

class StarRow extends StatelessWidget {
  const StarRow(this.stars, {super.key, this.size = 19});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$stars of 3 stars',
    child: ExcludeSemantics(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i < stars ? StrikerColors.gold : StrikerColors.faint),
      ]),
    ),
  );
}

/// Kept so existing call sites and semantics stay familiar.
class StageStars extends StarRow {
  const StageStars(super.stars, {super.key, super.size});
}

class BallGlyph extends StatelessWidget {
  const BallGlyph({super.key, this.size = 22, this.dimmed = false, this.color});
  final double size;
  final bool dimmed;
  final Color? color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _BallPainter(color ?? (dimmed ? StrikerColors.faint : StrikerColors.gold)),
  );
}

class _BallPainter extends CustomPainter {
  const _BallPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(r, r);
    canvas.drawCircle(c, r * .92, Paint()..color = color);
    canvas.drawCircle(c, r * .92, Paint()
      ..color = StrikerColors.onGold.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .12);
    final patch = Path();
    for (var i = 0; i < 5; i++) {
      final a = i * math.pi * 2 / 5 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * r * .38;
      if (i == 0) {
        patch.moveTo(p.dx, p.dy);
      } else {
        patch.lineTo(p.dx, p.dy);
      }
    }
    patch.close();
    canvas.drawPath(patch, Paint()..color = StrikerColors.onGold.withValues(alpha: .55));
  }

  @override
  bool shouldRepaint(covariant _BallPainter oldDelegate) => oldDelegate.color != color;
}

class KeeperAvatar extends StatelessWidget {
  const KeeperAvatar({super.key, required this.kit, this.size = 56});
  final Color kit;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size * 1.15),
    painter: _KeeperPainter(kit),
  );
}

class _KeeperPainter extends CustomPainter {
  const _KeeperPainter(this.kit);
  final Color kit;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final s = size.width / 56;
    canvas.drawOval(Rect.fromCenter(center: Offset(cx + 1 * s, 48 * s), width: 28 * s, height: 8 * s),
        Paint()..color = const Color(0x44000000));
    canvas.drawLine(Offset(cx - 18 * s, 32 * s), Offset(cx + 18 * s, 32 * s),
        Paint()..color = kit..strokeWidth = 7 * s..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx - 18 * s, 32 * s), 3.4 * s, Paint()..color = StrikerColors.ball);
    canvas.drawCircle(Offset(cx + 18 * s, 32 * s), 3.4 * s, Paint()..color = StrikerColors.ball);
    canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 34 * s), width: 22 * s, height: 18 * s),
        Radius.circular(6 * s)), Paint()..color = kit);
    canvas.drawCircle(Offset(cx, 18 * s), 7 * s, Paint()..color = StrikerColors.skin);
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, 17.5 * s), radius: 7 * s),
        math.pi, math.pi, false,
        Paint()..color = StrikerColors.hair..strokeWidth = 3.5 * s..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _KeeperPainter oldDelegate) => oldDelegate.kit != kit;
}

class RewardSwatch extends StatelessWidget {
  const RewardSwatch({super.key, required this.kind, required this.primary, required this.secondary});
  final RewardSwatchKind kind;
  final Color primary, secondary;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(44, 44),
    painter: _RewardSwatchPainter(kind, primary, secondary),
  );
}

enum RewardSwatchKind { ball, net, pitch }

class _RewardSwatchPainter extends CustomPainter {
  const _RewardSwatchPainter(this.kind, this.primary, this.secondary);
  final RewardSwatchKind kind;
  final Color primary, secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), Paint()..color = primary);
    switch (kind) {
      case RewardSwatchKind.ball:
        final c = Offset(size.width / 2, size.height / 2);
        canvas.drawCircle(c, 13, Paint()..color = primary);
        canvas.drawCircle(c, 13, Paint()..color = secondary.withValues(alpha: .35)..style = PaintingStyle.stroke..strokeWidth = 2);
        final patch = Path();
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5 - math.pi / 2;
          final p = c + Offset(math.cos(a), math.sin(a)) * 6;
          if (i == 0) { patch.moveTo(p.dx, p.dy); } else { patch.lineTo(p.dx, p.dy); }
        }
        canvas.drawPath(patch..close(), Paint()..color = secondary);
      case RewardSwatchKind.net:
        final grid = Paint()..color = secondary..strokeWidth = 1.2;
        for (var x = 8.0; x < size.width; x += 7) {
          canvas.drawLine(Offset(x, 6), Offset(x, size.height - 6), grid);
        }
        for (var y = 8.0; y < size.height; y += 7) {
          canvas.drawLine(Offset(6, y), Offset(size.width - 6, y), grid);
        }
      case RewardSwatchKind.pitch:
        canvas.drawRect(Rect.fromLTWH(0, size.height * .45, size.width, size.height * .22),
            Paint()..color = secondary);
        canvas.drawRect(Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
            Paint()..color = StrikerColors.pitchLine.withValues(alpha: .45)..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _RewardSwatchPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.primary != primary || oldDelegate.secondary != secondary;
}

class OverlayScrim extends StatelessWidget {
  const OverlayScrim({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [StrikerColors.scrimTop, StrikerColors.scrimBottom],
      ),
    ),
    child: child,
  );
}
