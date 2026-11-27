import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// A little map of where a payment was made: streets, a river and a park
/// drawn from [seed], a pin in the middle and the address under it. A
/// picture, not a real map — nothing is looked up.
class MapPreview extends StatelessWidget {
  const MapPreview({required this.seed, required this.label, super.key});

  final int seed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Semantics(
      label: 'Map: $label',
      child: ClipRSuperellipse(
        borderRadius: theme.radii.xl,
        child: SizedBox(
          height: 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _MapPainter(
                  seed: seed,
                  land: dark
                      ? const Color(0xFF26232A)
                      : const Color(0xFFF1EEE9),
                  street: dark
                      ? const Color(0xFF3A3640)
                      : const Color(0xFFFFFFFF),
                  water: dark
                      ? const Color(0xFF1E3446)
                      : const Color(0xFFBFDDF2),
                  park: dark
                      ? const Color(0xFF213427)
                      : const Color(0xFFCFE8C9),
                ),
              ),
              Center(
                child: Transform.translate(
                  offset: const Offset(0, -10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                          border: Border.all(
                            color: const Color(0xFFFFFFFF),
                            width: 3,
                          ),
                        ),
                        child: PhosphorIcon(
                          PhosphorIconsFill.storefront,
                          size: 14,
                          color: scheme.primaryForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 10,
                bottom: 10,
                end: 10,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Glass(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    borderRadius: theme.radii.full,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.caption.copyWith(
                        color: scheme.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({
    required this.seed,
    required this.land,
    required this.street,
    required this.water,
    required this.park,
  });

  final int seed;
  final Color land;
  final Color street;
  final Color water;
  final Color park;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = land);
    // A park, somewhere off the middle.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          w * (.05 + random.nextDouble() * .25),
          h * (.05 + random.nextDouble() * .3),
          w * .22,
          h * .38,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = park,
    );
    // A river across the corner.
    final river = Path()..moveTo(w * .62, -10);
    river.cubicTo(w * .7, h * .3, w * .95, h * .45, w + 10, h * .7);
    canvas.drawPath(
      river,
      Paint()
        ..color = water
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * .16,
    );
    // Streets: a loose grid, a little turned, and one boulevard.
    final minor = Paint()
      ..color = street
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas
      ..save()
      ..translate(w / 2, h / 2)
      ..rotate(-.18 + random.nextDouble() * .1)
      ..translate(-w / 2, -h / 2);
    for (var x = -w * .2; x < w * 1.2; x += 34 + random.nextDouble() * 22) {
      canvas.drawLine(Offset(x, -h), Offset(x + 12, h * 2), minor);
    }
    for (var y = -h * .2; y < h * 1.2; y += 26 + random.nextDouble() * 16) {
      canvas.drawLine(Offset(-w, y), Offset(w * 2, y - 8), minor);
    }
    canvas
      ..drawLine(
        Offset(-w, h * .58),
        Offset(w * 2, h * .3),
        Paint()
          ..color = street
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      seed != oldDelegate.seed ||
      land != oldDelegate.land ||
      street != oldDelegate.street;
}
