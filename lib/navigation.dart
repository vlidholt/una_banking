import 'package:disco/disco.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:una/una.dart';

/// The places the shell can show. The order is the shell's destination
/// order, so an index is a value.
enum Destination {
  home('Home'),
  cards('Cards'),
  payments('Payments'),
  analytics('Analytics'),
  profile('Profile');

  const Destination(this.label);

  final String label;
}

/// The destination the shell shows: on the web `?tab=cards` (or any
/// destination's name) opens on it, so a link can point at a page.
final destinationProvider = Provider(
  (_) => Signal(
    Destination.values
            .where((d) => kIsWeb && d.name == Uri.base.queryParameters['tab'])
            .firstOrNull ??
        Destination.home,
  ),
);

/// The card the Cards page shows, so Home can open it on a given card.
final selectedCardProvider = Provider((_) => Signal('coral'));

extension BankNavigation on BuildContext {
  /// Shows [destination] in the shell.
  void goTo(Destination destination) =>
      destinationProvider.of(this).value = destination;

  /// Closes every page over the shell, then shows [destination].
  void leaveTo(Destination destination) {
    final signal = destinationProvider.of(this);
    Navigator.of(this).popUntil((route) => route.isFirst);
    signal.value = destination;
  }

  /// Pushes a page over the shell's bars.
  Future<T?> pushPage<T>(WidgetBuilder builder) =>
      Navigator.of(this).push(UnaPageRoute<T>(builder: builder));
}
