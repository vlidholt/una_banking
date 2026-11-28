import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// The Una Banking mark — a "B" made of two "u"s on their side, on a tile
/// in the brand's coral-to-plum gradient — and the wordmark beside it.
///
/// The same painter draws the web app's icons (see
/// `test/app_icons_test.dart`).
class BankLogo extends StatelessWidget {
  const BankLogo({this.onPressed, this.showWordmark = true, super.key});

  final VoidCallback? onPressed;
  final bool showWordmark;

  // A brand asset: off the theme's scales on purpose.
  static const _gap = 10.0;

  static double _tile(ThemeData theme) =>
      theme.formFactor == FormFactor.mobile ? 30 : 32;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tile = _tile(theme);
    final style = theme.textTheme.large.copyWith(
      fontSize: 19,
      height: 1,
      fontWeight: FontWeight.w700,
      letterSpacing: -.035 * 19,
      color: scheme.foreground,
    );
    final logo = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: tile,
          child: const CustomPaint(painter: BankMarkPainter()),
        ),
        if (showWordmark) ...[
          const SizedBox(width: _gap),
          ConstrainedBox(
            // The wordmark's own width in the brand face, with room to
            // spare: a wider fallback face clips rather than pushing the
            // bar's actions off the edge.
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'una'),
                  TextSpan(
                    text: 'banking',
                    style: style.copyWith(
                      color: scheme.tint,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
              style: style,
            ),
          ),
        ],
      ],
    );
    if (onPressed == null) {
      return Semantics(
        label: 'Una Banking',
        child: ExcludeSemantics(child: logo),
      );
    }
    return Pressable(
      onPressed: onPressed,
      semanticLabel: 'Una Banking home',
      builder: (context, states) => FocusRing(
        visible: states.contains(WidgetState.focused),
        borderRadius: BorderRadius.circular(tile * .3),
        child: ExcludeSemantics(child: logo),
      ),
    );
  }
}

/// Paints the mark into its whole box. [radius] is the tile's corner as a
/// share of its side: 0 for a square that a platform masks itself.
class BankMarkPainter extends CustomPainter {
  const BankMarkPainter({this.radius = .3, this.inset = 0});

  final double radius;

  /// How far in from the edges the art sits, as a share of the side, on top
  /// of its own margin: maskable icons keep their art in the middle.
  final double inset;

  static const coral = Color(0xFFFF8A5B);
  static const ember = Color(0xFFE8453C);
  static const plum = Color(0xFF8E2A5E);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final box = Offset.zero & Size.square(side);
    final tile = RSuperellipse.fromRectAndRadius(
      box,
      Radius.circular(side * radius),
    );
    canvas.drawRSuperellipse(
      tile,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [coral, ember, plum],
          stops: [0, .55, 1],
        ).createShader(box),
    );
    // A soft light from the top left, as on a lacquered tile.
    canvas
      ..save()
      ..clipRSuperellipse(tile)
      ..drawCircle(
        Offset(side * .18, side * .1),
        side * .7,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  const Color(0xFFFFFFFF).withValues(alpha: .22),
                  const Color(0xFFFFFFFF).withValues(alpha: 0),
                ],
              ).createShader(
                Rect.fromCircle(
                  center: Offset(side * .18, side * .1),
                  radius: side * .7,
                ),
              ),
      )
      ..restore();

    // On a 24-unit grid: a "B" whose bowls are two "u"s laid on their side,
    // opening to the left and stacked, against a softer stem. The two "u"s
    // are one stroked path, so their shared middle bar is one shape. Every
    // edge is on a multiple of .75, a whole pixel in the 32-pixel favicon.
    final art = side * (1 - inset * 2);
    final unit = art / 24;
    canvas
      ..save()
      ..translate(side * inset, side * inset)
      ..scale(unit);
    const white = Color(0xFFFFFFFF);
    const stroke = 3.0;
    const stem = Rect.fromLTRB(6, 4.5, 6 + stroke, 19.5);
    Path u(double top, double bottom, double right) {
      final r = (bottom - top) / 2;
      return Path()
        ..moveTo(stem.right, top)
        ..lineTo(right - r, top)
        ..arcToPoint(Offset(right - r, bottom), radius: Radius.circular(r))
        ..lineTo(stem.right, bottom);
    }

    // Centre lines: the outer edges reach 17.25 and 18 to the right, the
    // lower bowl a little fuller, as a B's is.
    final bowls = u(6, 12, 15.75)..addPath(u(12, 18, 16.5), Offset.zero);
    canvas
      ..drawRect(stem, Paint()..color = white.withValues(alpha: .62))
      ..drawPath(
        bowls,
        Paint()
          ..color = white
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(BankMarkPainter oldDelegate) =>
      radius != oldDelegate.radius || inset != oldDelegate.inset;
}
