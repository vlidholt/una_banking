import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una/una.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/screens/notifications_screen.dart';
import 'package:una_banking/screens/transactions_screen.dart';
import 'package:una_banking/screens/vault_screen.dart';
import 'package:una_banking/widgets/flows.dart';

import 'support.dart';

/// Every destination, every page and every flow builds at a phone's, a
/// tablet's and a desktop's size, light and dark, with nothing
/// overflowing: an overflow is reported as an error, which fails the test.
void main() {
  setUpAll(setUpFonts);

  for (final (name, size) in [
    ('phone', phoneSize),
    ('tablet', tabletSize),
    ('desktop', desktopSize),
  ]) {
    for (final brightness in Brightness.values) {
      group('$name, ${brightness.name}', () {
        testWidgets('picks the right form factor', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          expect(
            formFactorOf(tester),
            size == phoneSize ? FormFactor.mobile : FormFactor.desktop,
          );
        });

        for (final destination in Destination.values) {
          testWidgets('${destination.name} builds', (tester) async {
            await pumpApp(tester, size: size, brightness: brightness);
            await goTo(tester, destination);
          });
        }

        testWidgets('the cards page builds for every card', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          await goTo(tester, Destination.cards);
          for (final card in sessionOf(tester).cards) {
            selectedCardProvider.of(appContext(tester)).value = card.id;
            await settle(tester);
          }
        });

        testWidgets('transactions build', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          await push(tester, (context) => const TransactionsScreen());
          expect(find.text('Today'), findsOneWidget);
        });

        testWidgets('notifications build', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          await push(tester, (context) => const NotificationsScreen());
          expect(find.text('Mark all read'), findsOneWidget);
        });

        testWidgets('a vault builds', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          await push(tester, (context) => const VaultScreen(vaultId: 'kyoto'));
          expect(find.text('Round-ups'), findsOneWidget);
        });

        final flows = <String, Future<void> Function(BuildContext)>{
          'send': showSendFlow,
          'request': showRequestFlow,
          'exchange': showExchangeFlow,
          'add money': showAddMoneyFlow,
          'new card': showOrderCardFlow,
          'open account': showOpenAccountFlow,
        };
        for (final MapEntry(key: label, value: open) in flows.entries) {
          testWidgets('the $label flow builds', (tester) async {
            await pumpApp(tester, size: size, brightness: brightness);
            open(appContext(tester));
            await settle(tester, frames: 20);
          });
        }

        testWidgets('a transaction builds', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          final session = sessionOf(tester);
          showTxnDetail(appContext(tester), session.transactions[1]);
          await settle(tester, frames: 20);
          expect(find.text('Category'), findsOneWidget);
        });

        testWidgets('a PIN change and a vault top-up build', (tester) async {
          await pumpApp(tester, size: size, brightness: brightness);
          final session = sessionOf(tester);
          showChangePinFlow(appContext(tester), session.cards.first);
          await settle(tester, frames: 20);
          expect(find.text('Choose four digits'), findsOneWidget);
          Navigator.of(appContext(tester)).pop();
          await settle(tester, frames: 20);
          showVaultMoneyFlow(appContext(tester), session.vaults.first);
          await settle(tester, frames: 20);
        });
      });
    }
  }
}
