import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/screens/notifications_screen.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/flows.dart';

import 'support.dart';

void main() {
  setUpAll(setUpFonts);

  group('the session', () {
    test('sending takes the money and writes a line', () {
      final session = BankSession();
      final before = session.balanceOf(Currency.eur);
      final txn = session.send(People.maya, 25, Currency.eur, note: 'Pizza');
      expect(session.balanceOf(Currency.eur), closeTo(before - 25, 1e-9));
      expect(session.transactions.first, txn);
      expect(txn.note, 'Pizza');
      expect(txn.kind, TxnKind.transfer);
    });

    test('exchanging moves money at today’s rate and keeps the total', () {
      final session = BankSession();
      final total = session.totalInEuros;
      final received = session.exchange(Currency.eur, Currency.usd, 100);
      expect(received, closeTo(100 * rate(Currency.eur, Currency.usd), .01));
      expect(session.totalInEuros, closeTo(total, .02));
      expect(session.transactions.take(2).map((txn) => txn.kind), [
        TxnKind.exchange,
        TxnKind.exchange,
      ]);
    });

    test('a vault takes from the euro account and gives back', () {
      final session = BankSession();
      final vault = session.vault('bike');
      final euros = session.balanceOf(Currency.eur);
      session.addToVault(vault, 360);
      expect(vault.reached, isTrue);
      expect(session.balanceOf(Currency.eur), closeTo(euros - 360, 1e-9));
      session.withdrawFromVault(vault, 100);
      expect(vault.saved, closeTo(2300, 1e-9));
    });

    test('freezing a card and splitting a payment', () {
      final session = BankSession();
      final card = session.card('coral');
      session.setFrozen(card, true);
      expect(card.frozen, isTrue);
      final txn = session.transactions.firstWhere(
        (txn) => txn.kind == TxnKind.card,
      );
      final requests = session.requests.length;
      final share = session.split(txn, [People.maya, People.jonas]);
      expect(session.requests.length, requests + 2);
      expect(share, closeTo(-txn.inEuros / 3, .01));
    });

    test('a request paid lands in the euro account', () {
      final session = BankSession();
      final request = session.requests.first;
      final euros = session.balanceOf(Currency.eur);
      session.settleRequest(request);
      expect(request.paid, isTrue);
      expect(
        session.balanceOf(Currency.eur),
        closeTo(euros + request.amount, 1e-9),
      );
    });

    test('the rate history ends on today’s rate', () {
      final history = rateHistory(Currency.eur, Currency.gbp);
      expect(history, hasLength(90));
      expect(history.last, closeTo(rate(Currency.eur, Currency.gbp), 1e-9));
    });
  });

  group('in the app', () {
    testWidgets('sending money on a phone, from a person to done', (
      tester,
    ) async {
      await pumpApp(tester, size: phoneSize);
      final session = sessionOf(tester);
      final before = session.balanceOf(Currency.eur);
      showSendFlow(appContext(tester));
      await settle(tester, frames: 20);
      await tester.tap(find.text('Jonas Weber'));
      await settle(tester, frames: 16);
      for (final key in ['4', '2']) {
        await tester.tap(find.text(key).last);
        await tester.pump();
      }
      await settle(tester, frames: 4);
      expect(find.text('€42'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await settle(tester, frames: 16);
      await tester.tap(find.text('Send €42.00'));
      await settle(tester, frames: 30);
      expect(find.text('€42.00 sent'), findsOneWidget);
      expect(session.balanceOf(Currency.eur), closeTo(before - 42, 1e-9));
      expect(session.transactions.first.person, People.jonas);
    });

    testWidgets('more than the balance cannot be sent', (tester) async {
      await pumpApp(tester, size: phoneSize);
      showSendFlow(appContext(tester), to: People.mei);
      await settle(tester, frames: 20);
      for (final key in ['9', '9', '9', '9', '9']) {
        await tester.tap(find.text(key).last);
        await tester.pump();
      }
      await settle(tester, frames: 4);
      expect(find.text('More than your EUR balance'), findsOneWidget);
    });

    testWidgets('freezing a card from the cards page', (tester) async {
      await pumpApp(tester, size: phoneSize);
      await goTo(tester, Destination.cards);
      await tester.tap(find.text('Freeze'));
      await settle(tester, frames: 20);
      expect(sessionOf(tester).card('coral').frozen, isTrue);
      expect(find.text('Unfreeze'), findsOneWidget);
      expect(find.text('Card frozen'), findsWidgets);
    });

    testWidgets('hiding balances shows dots everywhere', (tester) async {
      await pumpApp(tester, size: desktopSize);
      expect(find.textContaining('••••'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Hide balances'));
      await settle(tester);
      expect(sessionOf(tester).hideBalances, isTrue);
      expect(find.textContaining('••••'), findsWidgets);
    });

    testWidgets('marking notifications read', (tester) async {
      await pumpApp(tester, size: desktopSize);
      await push(tester, (context) => const NotificationsScreen());
      expect(sessionOf(tester).unread, greaterThan(0));
      await tester.tap(find.text('Mark all read'));
      await settle(tester);
      expect(sessionOf(tester).unread, 0);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('a new PIN is typed into hidden slots, twice', (tester) async {
      await pumpApp(tester, size: phoneSize);
      showChangePinFlow(appContext(tester), sessionOf(tester).cards.first);
      await settle(tester, frames: 20);
      final slots = find.byType(EditableText);
      expect(slots, findsNWidgets(4));
      // An obscured slot sets its character in a transparent colour and
      // draws a dot over it.
      for (final slot in tester.widgetList<EditableText>(slots)) {
        expect(slot.style.color?.a, 0);
      }
      Future<void> type(String pin) async {
        for (var i = 0; i < 4; i++) {
          await tester.enterText(find.byType(EditableText).at(i), pin[i]);
          await tester.pump();
        }
        await settle(tester, frames: 10);
      }

      await type('2580');
      expect(find.text('Type it again'), findsOneWidget);
      await type('2580');
      expect(find.text('PIN changed'), findsOneWidget);
    });

    testWidgets('the exchange panel on a desktop exchanges', (tester) async {
      await pumpApp(tester, size: desktopSize);
      await goTo(tester, Destination.payments);
      final session = sessionOf(tester);
      final dollars = session.balanceOf(Currency.usd);
      await tester.enterText(find.byType(EditableText).first, '100');
      await settle(tester, frames: 4);
      await tester.tap(find.text('Exchange €100.00'));
      await settle(tester, frames: 30);
      expect(find.text('Exchanged'), findsOneWidget);
      expect(session.balanceOf(Currency.usd), greaterThan(dollars + 100));
    });
  });
}
