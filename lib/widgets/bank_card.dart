import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/logo.dart';

/// A card as it looks in your hand: its design, chip, number and the
/// network's mark. Frozen, it frosts over and loses its colour.
///
/// [revealed] shows the whole number, the expiry and the CVV; otherwise
/// only the last four digits.
class BankCardView extends StatelessWidget {
  const BankCardView(
    this.card, {
    this.revealed = false,
    this.compact = false,
    super.key,
  });

  final BankCard card;
  final bool revealed;

  /// A small card in a list: the design and the last four digits only.
  final bool compact;

  /// A bank card's proportions (ISO/IEC 7810 ID-1).
  static const aspectRatio = 85.6 / 53.98;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final radius = BorderRadius.circular(width * (compact ? .08 : .055));
          return SpringBuilder(
            value: card.frozen ? 1 : 0,
            builder: (context, frost, child) => DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(borderRadius: radius),
                shadows: compact
                    ? const []
                    : [
                        BoxShadow(
                          color: const Color(0xFF000000).withValues(alpha: .22),
                          blurRadius: width * .08,
                          offset: Offset(0, width * .035),
                        ),
                      ],
              ),
              child: ClipRSuperellipse(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        _desaturate(frost.clamp(0, 1) * .85),
                      ),
                      child: child,
                    ),
                    if (frost > .01)
                      _Frost(amount: frost.clamp(0, 1), width: width),
                  ],
                ),
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _DesignPainter(card.design)),
                _Face(
                  card: card,
                  width: width,
                  revealed: revealed,
                  compact: compact,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// A colour matrix that takes [amount] of the colour out.
  static List<double> _desaturate(double amount) {
    final s = 1 - amount;
    const r = .2126, g = .7152, b = .0722;
    return [
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0, //
      0, 0, 0, 1, 0,
    ];
  }
}

/// What a design draws in: light ink on the dark designs, dark ink on sand
/// and prism.
bool _darkInk(CardDesign design) =>
    design == CardDesign.sand || design == CardDesign.prism;

class _Face extends StatelessWidget {
  const _Face({
    required this.card,
    required this.width,
    required this.revealed,
    required this.compact,
  });

  final BankCard card;
  final double width;
  final bool revealed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = _darkInk(card.design)
        ? const Color(0xFF1F1A1C)
        : const Color(0xFFFFFFFF);
    final soft = ink.withValues(alpha: .72);
    final unit = width / 100;
    final label = theme.textTheme.small.copyWith(
      fontSize: unit * 3.6,
      height: 1.2,
      color: soft,
      fontWeight: FontWeight.w500,
      letterSpacing: unit * .15,
    );
    final number = theme.textTheme.large.copyWith(
      fontSize: unit * (compact ? 9 : 5.6),
      height: 1,
      color: ink,
      fontWeight: FontWeight.w600,
      letterSpacing: unit * .35,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    if (compact) {
      return Padding(
        padding: EdgeInsets.all(unit * 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Mark(size: unit * 14),
            const Spacer(),
            Text(card.last4, style: number),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(unit * 6, unit * 5.5, unit * 6, unit * 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Mark(size: unit * 7.5),
              SizedBox(width: unit * 2),
              Text(
                'una',
                style: number.copyWith(
                  fontSize: unit * 5.4,
                  letterSpacing: -unit * .15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                switch (card.kind) {
                  CardKind.physical =>
                    card.design == CardDesign.midnight ? 'METAL' : 'DEBIT',
                  CardKind.virtual => 'VIRTUAL',
                  CardKind.disposable => 'SINGLE-USE',
                },
                style: label.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: unit * .4,
                ),
              ),
            ],
          ),
          SizedBox(height: unit * 7),
          Row(
            children: [
              if (card.kind == CardKind.physical)
                SizedBox(
                  width: unit * 11,
                  height: unit * 8.4,
                  child: const CustomPaint(painter: _ChipPainter()),
                )
              else
                PhosphorIcon(
                  card.kind == CardKind.virtual
                      ? PhosphorIconsRegular.globeSimple
                      : PhosphorIconsRegular.lightning,
                  size: unit * 7,
                  color: soft,
                ),
              SizedBox(width: unit * 3),
              if (card.kind != CardKind.disposable)
                Transform.rotate(
                  angle: math.pi / 2,
                  child: PhosphorIcon(
                    PhosphorIconsRegular.wifiHigh,
                    size: unit * 6.5,
                    color: soft,
                  ),
                ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              revealed ? card.number : '••••  ••••  ••••  ${card.last4}',
              style: number,
            ),
          ),
          SizedBox(height: unit * 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      People.me.name.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: label.copyWith(color: ink),
                    ),
                    SizedBox(height: unit * .8),
                    Text(
                      revealed
                          ? 'EXP ${card.expiry}   CVV ${card.cvv}'
                          : 'EXP ${card.expiry}',
                      style: label.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              _NetworkMark(width: unit * 15, color: ink),
            ],
          ),
        ],
      ),
    );
  }
}

/// The una mark without its tile, in white: the issuer's logo on a card.
class _Mark extends StatelessWidget {
  const _Mark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: const CustomPaint(painter: BankMarkPainter()),
  );
}

/// "orbit", the app's own (fictional) card network: two rings, one solid,
/// one open, over the name.
class _NetworkMark extends StatelessWidget {
  const _NetworkMark({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: width * .7,
            height: width * .42,
            child: CustomPaint(painter: _OrbitPainter(color)),
          ),
          SizedBox(height: width * .04),
          Text(
            'orbit',
            style: theme.textTheme.small.copyWith(
              fontSize: width * .2,
              height: 1,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
              letterSpacing: width * .01,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.height / 2;
    final stroke = size.height * .16;
    canvas
      ..drawCircle(
        Offset(r, r),
        r - stroke / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      )
      ..drawCircle(
        Offset(size.width - r, r),
        r - stroke / 2,
        Paint()..color = color.withValues(alpha: .55),
      );
  }

  @override
  bool shouldRepaint(_OrbitPainter oldDelegate) => color != oldDelegate.color;
}

/// A contact chip in gold.
class _ChipPainter extends CustomPainter {
  const _ChipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(size.height * .2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF5DFA0), Color(0xFFD4AE5C), Color(0xFFF2D58A)],
        ).createShader(rect),
    );
    final line = Paint()
      ..color = const Color(0xFF8C6A2B).withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * .05;
    final w = size.width, h = size.height;
    canvas
      ..drawLine(Offset(0, h * .35), Offset(w * .32, h * .35), line)
      ..drawLine(Offset(0, h * .65), Offset(w * .32, h * .65), line)
      ..drawLine(Offset(w * .68, h * .35), Offset(w, h * .35), line)
      ..drawLine(Offset(w * .68, h * .65), Offset(w, h * .65), line)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(w * .32, h * .2, w * .68, h * .8),
          Radius.circular(h * .12),
        ),
        line,
      );
  }

  @override
  bool shouldRepaint(_ChipPainter oldDelegate) => false;
}

/// The design's background.
class _DesignPainter extends CustomPainter {
  const _DesignPainter(this.design);

  final CardDesign design;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    void blob(Offset center, double radius, Color color) => canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    final w = size.width, h = size.height;
    switch (design) {
      case CardDesign.coral:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF9466), Color(0xFFF2643D), Color(0xFFB8325A)],
              stops: [0, .5, 1],
            ).createShader(rect),
        );
        blob(Offset(w * .95, h * .05), w * .55, const Color(0x55FFD7A8));
        blob(Offset(w * .1, h * 1.05), w * .6, const Color(0x447A1F4D));
        _waves(canvas, size, const Color(0x1FFFFFFF));
      case CardDesign.midnight:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF34303A), Color(0xFF17151B), Color(0xFF26222B)],
              stops: [0, .6, 1],
            ).createShader(rect),
        );
        // Brushed metal: fine lines, and one band of light across.
        final line = Paint()
          ..color = const Color(0x0DFFFFFF)
          ..strokeWidth = 1;
        for (var y = 0.0; y < h; y += 3) {
          canvas.drawLine(Offset(0, y), Offset(w, y + h * .08), line);
        }
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: const Alignment(-1, -.4),
              end: const Alignment(1, .4),
              colors: [
                const Color(0x00FFFFFF),
                const Color(0x1FFFFFFF),
                const Color(0x00FFFFFF),
              ],
              stops: const [.3, .5, .7],
            ).createShader(rect),
        );
      case CardDesign.aurora:
        canvas.drawRect(rect, Paint()..color = const Color(0xFF0E1A2B));
        blob(Offset(w * .15, h * .2), w * .6, const Color(0xCC12B886));
        blob(Offset(w * .85, h * .35), w * .55, const Color(0xCC7048E8));
        blob(Offset(w * .55, h * 1.1), w * .6, const Color(0xAAF06595));
        blob(Offset(w * .4, h * .5), w * .35, const Color(0x6622B8CF));
      case CardDesign.prism:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const SweepGradient(
              center: Alignment(-.3, -.6),
              colors: [
                Color(0xFFFFD8E4),
                Color(0xFFD0EBFF),
                Color(0xFFD3F9D8),
                Color(0xFFFFF3BF),
                Color(0xFFE5DBFF),
                Color(0xFFFFD8E4),
              ],
            ).createShader(rect),
        );
        blob(Offset(w * .8, h * .8), w * .5, const Color(0x88FFFFFF));
        _waves(canvas, size, const Color(0x22FFFFFF));
      case CardDesign.sand:
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFF1E4D3), Color(0xFFD9C2A5)],
            ).createShader(rect),
        );
        blob(Offset(w * .9, h * .1), w * .5, const Color(0x66FFFFFF));
        _waves(canvas, size, const Color(0x14000000));
    }
  }

  /// Fine contour lines across the card, like a topographic map.
  static void _waves(Canvas canvas, Size size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .004;
    for (var i = 0; i < 9; i++) {
      final y0 = size.height * (.25 + i * .09);
      final path = Path()..moveTo(-10, y0);
      for (var x = 0.0; x <= size.width + 10; x += size.width / 40) {
        path.lineTo(
          x,
          y0 +
              math.sin(x / size.width * 5 + i * .7) * size.height * .05 +
              math.sin(x / size.width * 11 + i) * size.height * .015,
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_DesignPainter oldDelegate) =>
      design != oldDelegate.design;
}

/// The frost over a frozen card: a white veil and a snowflake.
class _Frost extends StatelessWidget {
  const _Frost({required this.amount, required this.width});

  final double amount;
  final double width;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFE7F5FF).withValues(alpha: .55 * amount),
              const Color(0xFFFFFFFF).withValues(alpha: .25 * amount),
              const Color(0xFFD0EBFF).withValues(alpha: .5 * amount),
            ],
          ),
        ),
        child: Center(
          child: Transform.scale(
            scale: .6 + .4 * amount,
            child: Opacity(
              opacity: amount,
              child: PhosphorIcon(
                PhosphorIconsBold.snowflake,
                size: width * .16,
                color: const Color(0xFFFFFFFF),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
