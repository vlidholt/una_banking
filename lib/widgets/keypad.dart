import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/money.dart';

/// The text of an amount being typed: digits, at most one point, at most
/// the currency's decimals after it.
class AmountInput extends ChangeNotifier {
  String _text = '';
  String get text => _text;

  double get value => double.tryParse(_text) ?? 0;

  set text(String text) {
    _text = text;
    notifyListeners();
  }

  void press(String key, Currency currency) {
    var next = _text;
    if (key == '⌫') {
      if (next.isNotEmpty) next = next.substring(0, next.length - 1);
    } else if (key == '.') {
      if (currency.decimals == 0 || next.contains('.')) return;
      next = next.isEmpty ? '0.' : '$next.';
    } else {
      final dot = next.indexOf('.');
      if (dot >= 0 && next.length - dot > currency.decimals) return;
      if (dot < 0 && next.replaceAll('.', '').length >= 7) return;
      next = next == '0' ? key : '$next$key';
    }
    if (next == _text) return;
    _text = next;
    notifyListeners();
  }
}

/// A large amount in [currency] as it is typed, with the keys under it on a
/// phone (and the keyboard's digits everywhere).
class AmountEntry extends StatefulWidget {
  const AmountEntry({
    required this.input,
    required this.currency,
    this.caption,
    this.error,
    this.showKeypad = true,
    super.key,
  });

  final AmountInput input;
  final Currency currency;

  /// A line under the amount: the balance, the rate.
  final Widget? caption;

  /// Replaces the caption in the destructive colour: "More than you have".
  final String? error;

  final bool showKeypad;

  @override
  State<AmountEntry> createState() => _AmountEntryState();
}

class _AmountEntryState extends State<AmountEntry> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;
        if (key == LogicalKeyboardKey.backspace) {
          widget.input.press('⌫', widget.currency);
          return KeyEventResult.handled;
        }
        final character = event.character;
        if (character != null && RegExp(r'^[0-9.,]$').hasMatch(character)) {
          widget.input.press(
            character == ',' ? '.' : character,
            widget.currency,
          );
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ListenableBuilder(
        listenable: widget.input,
        builder: (context, _) {
          final text = widget.input.text;
          final empty = text.isEmpty;
          final shown = empty ? '0' : text;
          final style = theme.textTheme.h1
              .copyWith(
                fontSize: 48,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                color: empty ? scheme.mutedForeground : scheme.foreground,
              )
              .tabular;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Amount',
                value: money(widget.input.value, widget.currency),
                liveRegion: true,
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.currency.suffix
                          ? '$shown ${widget.currency.symbol}'
                          : '${widget.currency.symbol}$shown',
                      style: style,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
              const Gap.xs(),
              SizedBox(
                height: 20,
                child: widget.error != null
                    ? Text(
                        widget.error!,
                        style: theme.textTheme.caption.copyWith(
                          color: scheme.destructive,
                        ),
                      )
                    : DefaultTextStyle.merge(
                        style: theme.textTheme.caption,
                        child: widget.caption ?? const SizedBox.shrink(),
                      ),
              ),
              if (widget.showKeypad) ...[
                const Gap.md(),
                Keypad(
                  onKey: (key) {
                    Haptics.selection(context);
                    widget.input.press(key, widget.currency);
                  },
                  decimal: widget.currency.decimals > 0,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Twelve keys: the digits, a point and a backspace.
class Keypad extends StatelessWidget {
  const Keypad({required this.onKey, this.decimal = true, super.key});

  final ValueChanged<String> onKey;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', '⌫'],
    ];
    return UnaColumn(
      gap: GapSize.xs,
      children: [
        for (final row in rows)
          UnaRow(
            gap: GapSize.xs,
            children: [
              for (final key in row)
                Expanded(
                  child: key == '.' && !decimal
                      ? const SizedBox(height: 52)
                      : _Key(label: key, onPressed: () => onKey(key)),
                ),
            ],
          ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label == '⌫' ? 'Delete' : label,
      semanticContainer: true,
      builder: (context, states) {
        final down =
            states.contains(WidgetState.pressed) ||
            states.contains(WidgetState.hovered);
        return AnimatedFill(
          color: down
              ? scheme.secondary
              : scheme.secondary.withValues(alpha: 0),
          borderRadius: theme.radii.lg,
          child: SizedBox(
            height: 52,
            child: Center(
              child: label == '⌫'
                  ? PhosphorIcon(
                      PhosphorIconsRegular.backspace,
                      size: 22,
                      color: scheme.foreground,
                    )
                  : Text(
                      label,
                      style: theme.textTheme.h3.copyWith(
                        fontWeight: FontWeight.w500,
                        color: scheme.foreground,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
