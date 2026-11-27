import 'package:flutter/widgets.dart';
import 'package:una/una.dart';

/// The currencies an account can hold, with what it takes to write them.
enum Currency {
  eur('EUR', 'Euro', '€', Color(0xFF3B5BDB)),
  usd('USD', 'US dollar', r'$', Color(0xFF2F9E44)),
  gbp('GBP', 'British pound', '£', Color(0xFF7048E8)),
  sek('SEK', 'Swedish krona', 'kr', Color(0xFFE8A317), suffix: true),
  jpy('JPY', 'Japanese yen', '¥', Color(0xFFE03131), decimals: 0),
  chf('CHF', 'Swiss franc', 'CHF', Color(0xFFD9480F), suffix: true);

  const Currency(
    this.code,
    this.label,
    this.symbol,
    this.color, {
    this.suffix = false,
    this.decimals = 2,
  });

  final String code;
  final String label;
  final String symbol;

  /// The colour of the currency's disc, an identity colour like a flag's.
  final Color color;

  /// Whether the symbol is written after the number (`12,450 kr`).
  final bool suffix;
  final int decimals;

  /// What one unit is worth in euros, today.
  double get inEuros => euroRates[this]!;
}

/// Mid-market rates: one unit of each currency in euros.
const euroRates = {
  Currency.eur: 1.0,
  Currency.usd: 0.9184,
  Currency.gbp: 1.1712,
  Currency.sek: 0.0871,
  Currency.jpy: 0.00612,
  Currency.chf: 1.0634,
};

/// How many [to] one [from] buys.
double rate(Currency from, Currency to) => from.inEuros / to.inEuros;

final _grouped = <int, NumberFormat>{};

NumberFormat _format(int decimals) => _grouped[decimals] ??= NumberFormat(
  decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}',
  'en_US',
);

/// [amount] written in [currency]: `€4,812.40`, `12,450.00 kr`, `−€12.50`.
///
/// [sign] writes a plus before money that came in; [decimals] overrides
/// the currency's own (0 for a headline figure).
String money(
  double amount,
  Currency currency, {
  bool sign = false,
  int? decimals,
}) {
  final digits = _format(decimals ?? currency.decimals).format(amount.abs());
  final body = currency.suffix
      ? '$digits ${currency.symbol}'
      : '${currency.symbol}$digits';
  if (amount < 0) return '−$body';
  if (sign && amount > 0) return '+$body';
  return body;
}

/// Splits [amount] into its whole part and its cents, for a headline that
/// sets the cents smaller: (`€4,812`, `.40`).
(String, String) moneyParts(double amount, Currency currency) {
  final full = money(amount, currency);
  if (currency.decimals == 0) return (full, '');
  final dot = full.lastIndexOf('.');
  if (currency.suffix) {
    // `12,450.00 kr`: the cents keep the symbol with them.
    return (full.substring(0, dot), full.substring(dot));
  }
  return (full.substring(0, dot), full.substring(dot));
}

/// Figures that line up in a column: every amount in the app is set in
/// these.
const tabularFigures = [FontFeature.tabularFigures()];

extension TabularStyle on TextStyle {
  /// This style with tabular figures.
  TextStyle get tabular => copyWith(fontFeatures: tabularFigures);
}

/// A disc in the currency's colour with its code or symbol: the app's flag.
class CurrencyBadge extends StatelessWidget {
  const CurrencyBadge(this.currency, {this.size = 36, super.key});

  final Currency currency;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final symbol = currency.symbol.length > 2
        ? currency.code.substring(0, 1)
        : currency.symbol;
    return Semantics(
      label: currency.label,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(currency.color, const Color(0xFFFFFFFF), .18)!,
                currency.color,
              ],
            ),
          ),
          child: Text(
            symbol,
            style: theme.textTheme.small.copyWith(
              fontSize: size * .42,
              height: 1,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}
