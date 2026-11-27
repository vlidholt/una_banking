import 'dart:math' as math;

import 'package:disco/disco.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart' show PhosphorIconsRegular;
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';

/// How money moved.
enum TxnKind { card, transfer, exchange, topUp, vault, income, direct }

enum TxnStatus {
  completed('Completed'),
  pending('Pending'),
  declined('Declined');

  const TxnStatus(this.label);

  final String label;
}

/// One line of the statement. Immutable: a change replaces it.
@immutable
class Txn {
  const Txn({
    required this.id,
    required this.date,
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.kind,
    this.merchant,
    this.person,
    this.vaultId,
    this.cardId,
    this.status = TxnStatus.completed,
    this.note,
    this.counterAmount,
    this.counterCurrency,
  });

  final String id;
  final DateTime date;
  final String title;

  /// Negative for money out.
  final double amount;
  final Currency currency;
  final TxnCategory category;
  final TxnKind kind;
  final Merchant? merchant;
  final Person? person;
  final String? vaultId;
  final String? cardId;
  final TxnStatus status;
  final String? note;

  /// For an exchange: what the other side of it was.
  final double? counterAmount;
  final Currency? counterCurrency;

  bool get isIncoming => amount > 0;

  /// The amount in euros, for totals across currencies.
  double get inEuros => amount * currency.inEuros;

  /// A line under the title: where, or what kind of payment.
  String get detail => switch (kind) {
    TxnKind.card => merchant?.place ?? category.label,
    TxnKind.transfer => isIncoming ? 'Received' : 'Sent',
    TxnKind.exchange =>
      'Exchanged ${money(counterAmount!.abs(), counterCurrency!)}',
    TxnKind.topUp => 'Added from Northbank •• 2210',
    TxnKind.vault => isIncoming ? 'From vault' : 'To vault',
    TxnKind.income => 'Salary',
    TxnKind.direct => 'Direct debit',
  };

  Txn copyWith({TxnCategory? category, String? note}) => Txn(
    id: id,
    date: date,
    title: title,
    amount: amount,
    currency: currency,
    category: category ?? this.category,
    kind: kind,
    merchant: merchant,
    person: person,
    vaultId: vaultId,
    cardId: cardId,
    status: status,
    note: note ?? this.note,
    counterAmount: counterAmount,
    counterCurrency: counterCurrency,
  );
}

/// A card and everything you can change about it.
class BankCard {
  BankCard.fromSeed(CardSeed seed)
    : id = seed.id,
      name = seed.name,
      kind = seed.kind,
      design = seed.design,
      number = seed.number,
      expiry = seed.expiry,
      cvv = seed.cvv,
      limit = seed.limit,
      spent = seed.spent,
      contactless = seed.contactless,
      online = seed.online,
      atm = seed.atm,
      abroad = seed.abroad;

  BankCard({
    required this.id,
    required this.name,
    required this.kind,
    required this.design,
    required this.number,
    required this.expiry,
    required this.cvv,
    required this.limit,
  }) : spent = 0,
       contactless = kind == CardKind.physical,
       online = true,
       atm = kind == CardKind.physical,
       abroad = true;

  final String id;
  String name;
  final CardKind kind;
  final CardDesign design;
  String number;
  final String expiry;
  final String cvv;

  /// The monthly spending limit, in euros.
  double limit;

  /// What the card spent this month, in euros.
  double spent;
  bool frozen = false;
  bool contactless;
  bool online;
  bool atm;
  bool abroad;

  /// Whether the card is still being made and posted.
  bool arriving = false;

  String get last4 => number.substring(number.length - 4);
  String get masked => '•••• ${number.substring(number.length - 4)}';
}

/// A savings goal and what is in it.
class Vault {
  Vault.fromSeed(VaultSeed seed)
    : id = seed.id,
      name = seed.name,
      photo = seed.photo,
      icon = seed.icon,
      target = seed.target,
      saved = seed.saved,
      roundUps = seed.roundUps;

  final String id;
  final String name;
  final String photo;
  final IconData icon;
  final double target;
  double saved;
  bool roundUps;

  double get progress => (saved / target).clamp(0, 1).toDouble();
  bool get reached => saved >= target;
}

/// Money you asked someone for.
class PaymentRequest {
  PaymentRequest(this.person, this.amount, this.note, this.date);

  final Person person;
  final double amount;
  final String note;
  final DateTime date;
  bool paid = false;
}

/// A payment that repeats.
class ScheduledPayment {
  ScheduledPayment(this.title, this.amount, this.every, this.next, this.icon);

  final String title;
  final double amount;
  final String every;
  final DateTime next;
  final IconData icon;
  bool paused = false;
}

/// A notification.
class Notice {
  Notice(this.title, this.body, this.date, this.icon, {this.read = false});

  final String title;
  final String body;
  final DateTime date;
  final IconData icon;
  bool read;
}

/// Everything the user changes that more than one screen shows: balances,
/// the statement, cards, vaults, requests and notifications.
///
/// Nothing ever leaves the app: every action is a mockup that moves
/// numbers in memory.
class BankSession extends ChangeNotifier {
  BankSession() {
    balances.addAll(Seeds.accounts);
    cards.addAll(Seeds.cards.map(BankCard.fromSeed));
    vaults.addAll(vaultSeeds.map(Vault.fromSeed));
    transactions.addAll(_seedTransactions());
    requests.addAll([
      PaymentRequest(People.samir, 24, 'Concert tickets', daysAgo(2)),
      PaymentRequest(People.mei, 18.50, 'Ramen on Friday', daysAgo(5)),
    ]);
    scheduled.addAll([
      ScheduledPayment(
        'Rent · Harbor Homes',
        1250,
        'Monthly',
        DateTime(today.year, today.month + 1, 1),
        PhosphorIconsRegular.house,
      ),
      ScheduledPayment(
        'Rainy day vault',
        25,
        'Weekly',
        today.add(Duration(days: 7 - today.weekday % 7)),
        PhosphorIconsRegular.umbrella,
      ),
      ScheduledPayment(
        'Pocket money · Noah',
        40,
        'Monthly',
        DateTime(today.year, today.month + 1, 15),
        PhosphorIconsRegular.gift,
      ),
    ]);
    notices.addAll([
      Notice(
        'Card payment',
        'You paid €4.80 at Fika & Co.',
        daysAgo(0, hour: 8, minute: 42),
        PhosphorIconsRegular.creditCard,
      ),
      Notice(
        'Maya sent you €32.00',
        '“Your half of the market haul 🥕”',
        daysAgo(1, hour: 19, minute: 5),
        PhosphorIconsRegular.arrowDownLeft,
      ),
      Notice(
        'Kyoto in spring is 62% there',
        'Round-ups added €3.74 this week.',
        daysAgo(2, hour: 9),
        PhosphorIconsRegular.piggyBank,
        read: true,
      ),
      Notice(
        'New device signed in',
        'MacBook Pro · Paris, France. Not you? Freeze your cards.',
        daysAgo(4, hour: 21, minute: 12),
        PhosphorIconsRegular.shieldWarning,
        read: true,
      ),
      Notice(
        'Your statement is ready',
        'Last month’s statement can be downloaded.',
        daysAgo(9, hour: 7),
        PhosphorIconsRegular.fileText,
        read: true,
      ),
    ]);
  }

  final balances = <Currency, double>{};
  final cards = <BankCard>[];
  final vaults = <Vault>[];

  /// The statement, newest first.
  final transactions = <Txn>[];
  final requests = <PaymentRequest>[];
  final scheduled = <ScheduledPayment>[];
  final notices = <Notice>[];

  /// Whether amounts are shown as dots, for a glance in public.
  bool hideBalances = false;

  var _next = 0;
  String _id() => 'n${_next++}';

  // ---------------------------------------------------------------- reading

  /// The accounts in the order the app lists them.
  List<Currency> get accounts => [
    for (final currency in Currency.values)
      if (balances.containsKey(currency)) currency,
  ];

  double balanceOf(Currency currency) => balances[currency] ?? 0;

  /// Everything you hold, in euros: accounts and vaults.
  double get totalInEuros =>
      balances.entries.fold<double>(
        0,
        (sum, entry) => sum + entry.value * entry.key.inEuros,
      ) +
      savedInVaults;

  double get savedInVaults =>
      vaults.fold<double>(0, (sum, vault) => sum + vault.saved);

  int get unread => notices.where((notice) => !notice.read).length;

  BankCard card(String id) => cards.firstWhere((card) => card.id == id);

  BankCard? maybeCard(String? id) =>
      id == null ? null : cards.where((card) => card.id == id).firstOrNull;

  Vault vault(String id) => vaults.firstWhere((vault) => vault.id == id);

  Txn? txn(String id) => transactions.where((txn) => txn.id == id).firstOrNull;

  /// Money spent (as a positive number, in euros) in the calendar month of
  /// [month], in [category] or every spending category.
  double spentIn(DateTime month, {TxnCategory? category}) => transactions
      .where(
        (txn) =>
            txn.amount < 0 &&
            txn.status != TxnStatus.declined &&
            txn.date.year == month.year &&
            txn.date.month == month.month &&
            TxnCategory.spending.contains(txn.category) &&
            (category == null || txn.category == category),
      )
      .fold<double>(0, (sum, txn) => sum - txn.inEuros);

  /// Spending this month by category, largest first, without the empty
  /// ones.
  List<(TxnCategory, double)> spendingByCategory(DateTime month) {
    final entries = [
      for (final category in TxnCategory.spending)
        (category, spentIn(month, category: category)),
    ].where((entry) => entry.$2 > 0).toList();
    entries.sort((a, b) => b.$2.compareTo(a.$2));
    return entries;
  }

  /// The last six months' spending, oldest first, this month last.
  List<double> get monthlySpending => [
    ...pastMonthsSpent,
    spentIn(today),
  ];

  /// Money in this month, in euros.
  double get incomeThisMonth => transactions
      .where(
        (txn) =>
            txn.amount > 0 &&
            txn.kind != TxnKind.exchange &&
            txn.kind != TxnKind.vault &&
            txn.date.year == today.year &&
            txn.date.month == today.month,
      )
      .fold<double>(0, (sum, txn) => sum + txn.inEuros);

  // ---------------------------------------------------------------- moving

  bool canAfford(Currency currency, double amount) =>
      amount > 0 && amount <= balanceOf(currency) + 1e-9;

  /// Sends [amount] to [person]; returns the new line of the statement.
  Txn send(Person person, double amount, Currency currency, {String? note}) {
    assert(canAfford(currency, amount));
    balances[currency] = balanceOf(currency) - amount;
    final txn = Txn(
      id: _id(),
      date: DateTime.now(),
      title: person.name,
      amount: -amount,
      currency: currency,
      category: TxnCategory.transfers,
      kind: TxnKind.transfer,
      person: person,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );
    transactions.insert(0, txn);
    notices.insert(
      0,
      Notice(
        'You sent ${money(amount, currency)}',
        'To ${person.name}${txn.note == null ? '' : ' · “${txn.note}”'}',
        DateTime.now(),
        PhosphorIconsRegular.paperPlaneTilt,
        read: true,
      ),
    );
    notifyListeners();
    return txn;
  }

  /// Asks [person] for [amount] euros.
  PaymentRequest request(Person person, double amount, {String? note}) {
    final request = PaymentRequest(
      person,
      amount,
      note == null || note.trim().isEmpty ? 'Payment request' : note.trim(),
      DateTime.now(),
    );
    requests.insert(0, request);
    notifyListeners();
    return request;
  }

  void cancelRequest(PaymentRequest request) {
    requests.remove(request);
    notifyListeners();
  }

  /// Pretends [request] was paid, for the demo: the money comes in.
  void settleRequest(PaymentRequest request) {
    request.paid = true;
    balances[Currency.eur] = balanceOf(Currency.eur) + request.amount;
    transactions.insert(
      0,
      Txn(
        id: _id(),
        date: DateTime.now(),
        title: request.person.name,
        amount: request.amount,
        currency: Currency.eur,
        category: TxnCategory.transfers,
        kind: TxnKind.transfer,
        person: request.person,
        note: request.note,
      ),
    );
    notifyListeners();
  }

  /// Exchanges [amount] of [from] into [to] at today's rate; returns what
  /// arrived.
  double exchange(Currency from, Currency to, double amount) {
    assert(canAfford(from, amount) && from != to);
    final received = _round(amount * rate(from, to), to);
    balances[from] = balanceOf(from) - amount;
    balances[to] = balanceOf(to) + received;
    final now = DateTime.now();
    transactions
      ..insert(
        0,
        Txn(
          id: _id(),
          date: now,
          title: '${from.code} → ${to.code}',
          amount: -amount,
          currency: from,
          category: TxnCategory.transfers,
          kind: TxnKind.exchange,
          counterAmount: received,
          counterCurrency: to,
        ),
      )
      ..insert(
        0,
        Txn(
          id: _id(),
          date: now,
          title: '${from.code} → ${to.code}',
          amount: received,
          currency: to,
          category: TxnCategory.transfers,
          kind: TxnKind.exchange,
          counterAmount: -amount,
          counterCurrency: from,
        ),
      );
    notifyListeners();
    return received;
  }

  /// Adds [amount] to the [currency] account from the linked bank.
  void addMoney(Currency currency, double amount) {
    balances[currency] = balanceOf(currency) + amount;
    transactions.insert(
      0,
      Txn(
        id: _id(),
        date: DateTime.now(),
        title: 'Top-up',
        amount: amount,
        currency: currency,
        category: TxnCategory.transfers,
        kind: TxnKind.topUp,
      ),
    );
    notifyListeners();
  }

  /// Opens an account in [currency], with nothing in it.
  void openAccount(Currency currency) {
    balances.putIfAbsent(currency, () => 0);
    notifyListeners();
  }

  void setFrozen(BankCard card, bool frozen) {
    card.frozen = frozen;
    notices.insert(
      0,
      Notice(
        frozen ? 'Card frozen' : 'Card unfrozen',
        '${card.name} ${card.masked} ${frozen ? 'will decline every payment until you unfreeze it.' : 'works again.'}',
        DateTime.now(),
        PhosphorIconsRegular.snowflake,
        read: true,
      ),
    );
    notifyListeners();
  }

  void setLimit(BankCard card, double limit) {
    card.limit = limit;
    notifyListeners();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  /// Orders a new card; a physical one is shown as on its way.
  BankCard orderCard(CardKind kind, CardDesign design, String name) {
    final random = math.Random(cards.length * 31 + design.index);
    String group() => (1000 + random.nextInt(9000)).toString();
    final card = BankCard(
      id: 'card${cards.length}',
      name: name,
      kind: kind,
      design: design,
      number: '4${group().substring(1)} ${group()} ${group()} ${group()}',
      expiry:
          '${(today.month).toString().padLeft(2, '0')}/${(today.year + 4) % 100}',
      cvv: '${100 + random.nextInt(900)}',
      limit: kind == CardKind.disposable ? 200 : 1500,
    )..arriving = kind == CardKind.physical;
    cards.add(card);
    notifyListeners();
    return card;
  }

  /// Gives a single-use card a new number, as one does after a payment.
  void regenerate(BankCard card) {
    final random = math.Random(card.number.hashCode);
    String group() => (1000 + random.nextInt(9000)).toString();
    card.number = '4${group().substring(1)} ${group()} ${group()} ${group()}';
    notifyListeners();
  }

  /// Moves [amount] euros from the euro account into [vault].
  void addToVault(Vault vault, double amount) {
    assert(canAfford(Currency.eur, amount));
    balances[Currency.eur] = balanceOf(Currency.eur) - amount;
    vault.saved += amount;
    transactions.insert(
      0,
      Txn(
        id: _id(),
        date: DateTime.now(),
        title: vault.name,
        amount: -amount,
        currency: Currency.eur,
        category: TxnCategory.transfers,
        kind: TxnKind.vault,
        vaultId: vault.id,
      ),
    );
    notifyListeners();
  }

  /// Moves [amount] euros out of [vault] into the euro account.
  void withdrawFromVault(Vault vault, double amount) {
    final taken = math.min(amount, vault.saved);
    vault.saved -= taken;
    balances[Currency.eur] = balanceOf(Currency.eur) + taken;
    transactions.insert(
      0,
      Txn(
        id: _id(),
        date: DateTime.now(),
        title: vault.name,
        amount: taken,
        currency: Currency.eur,
        category: TxnCategory.transfers,
        kind: TxnKind.vault,
        vaultId: vault.id,
      ),
    );
    notifyListeners();
  }

  void setCategory(Txn txn, TxnCategory category) {
    final index = transactions.indexWhere((t) => t.id == txn.id);
    if (index < 0) return;
    transactions[index] = transactions[index].copyWith(category: category);
    notifyListeners();
  }

  /// Splits [txn] evenly with [people]: each is asked for their share.
  double split(Txn txn, List<Person> people) {
    final share = _round(-txn.inEuros / (people.length + 1), Currency.eur);
    for (final person in people) {
      requests.insert(
        0,
        PaymentRequest(person, share, 'Split: ${txn.title}', DateTime.now()),
      );
    }
    notifyListeners();
    return share;
  }

  void markAllRead() {
    for (final notice in notices) {
      notice.read = true;
    }
    notifyListeners();
  }

  void toggleHideBalances() {
    hideBalances = !hideBalances;
    notifyListeners();
  }

  static double _round(double value, Currency currency) {
    final factor = math.pow(10, currency.decimals);
    return (value * factor).roundToDouble() / factor;
  }
}

/// The statement the app opens with: about seven weeks of a life in Paris.
List<Txn> _seedTransactions() {
  var n = 0;
  Txn card(
    int days,
    int hour,
    int minute,
    Merchant merchant,
    double amount, {
    String card = 'coral',
    Currency currency = Currency.eur,
    TxnStatus status = TxnStatus.completed,
  }) => Txn(
    id: 's${n++}',
    date: daysAgo(days, hour: hour, minute: minute),
    title: merchant.name,
    amount: -amount,
    currency: currency,
    category: merchant.category,
    kind: TxnKind.card,
    merchant: merchant,
    cardId: card,
    status: status,
  );
  Txn person(
    int days,
    int hour,
    Person who,
    double amount, {
    String? note,
  }) => Txn(
    id: 's${n++}',
    date: daysAgo(days, hour: hour),
    title: who.name,
    amount: amount,
    currency: Currency.eur,
    category: TxnCategory.transfers,
    kind: TxnKind.transfer,
    person: who,
    note: note,
  );
  final salaryDay = () {
    // The 25th of this month, or of the last one if that is still ahead.
    final thisMonth = DateTime(today.year, today.month, 25);
    final payday = thisMonth.isAfter(today)
        ? DateTime(today.year, today.month - 1, 25)
        : thisMonth;
    return today.difference(payday).inDays;
  }();
  final list = [
    card(0, 8, 42, Merchants.fika, 4.80),
    card(0, 8, 10, Merchants.metro, 2.15),
    person(1, 19, People.maya, 32, note: 'Your half of the market haul 🥕'),
    card(1, 13, 5, Merchants.sakura, 16.40),
    card(1, 9, 30, Merchants.greenleaf, 38.62),
    card(2, 20, 15, Merchants.bistro, 64.00, card: 'midnight'),
    card(2, 8, 45, Merchants.fika, 5.20),
    card(3, 18, 2, Merchants.atlas, 27.90),
    card(
      3,
      11,
      0,
      Merchants.nordwind,
      248.00,
      card: 'aurora',
      currency: Currency.usd,
    ),
    card(4, 17, 40, Merchants.pharmacy, 11.35),
    person(4, 21, People.jonas, -45, note: 'Climbing gym pass'),
    card(5, 12, 20, Merchants.greenleaf, 54.18),
    card(5, 8, 12, Merchants.metro, 2.15),
    card(6, 23, 10, Merchants.taxi, 18.70, card: 'midnight'),
    card(6, 20, 0, Merchants.bistro, 42.50, card: 'midnight'),
    card(7, 10, 0, Merchants.kiosk, 6.40, status: TxnStatus.declined),
    card(7, 9, 55, Merchants.fika, 4.80),
    card(8, 16, 30, Merchants.velo, 89.00),
    card(9, 12, 40, Merchants.sakura, 14.90),
    card(9, 9, 0, Merchants.greenleaf, 61.04),
    card(10, 19, 0, Merchants.tune, 10.99, card: 'aurora'),
    person(11, 18, People.ines, 120, note: 'Thanks for the flights!'),
    card(11, 8, 20, Merchants.metro, 2.15),
    card(12, 14, 5, Merchants.atlas, 19.50, currency: Currency.gbp),
    card(13, 9, 15, Merchants.fika, 9.60),
    card(13, 12, 30, Merchants.greenleaf, 42.77),
    card(14, 20, 45, Merchants.sakura, 31.80, card: 'midnight'),
    card(15, 10, 0, Merchants.cloudnest, 2.99, card: 'aurora'),
    card(16, 11, 10, Merchants.pharmacy, 7.95),
    card(17, 18, 30, Merchants.bistro, 58.00, card: 'midnight'),
    card(18, 9, 0, Merchants.greenleaf, 47.31),
    card(19, 21, 0, Merchants.dailyPaper, 8.00),
    person(20, 12, People.samir, -24, note: 'Concert tickets'),
    card(21, 15, 20, Merchants.velo, 34.00),
    card(22, 8, 50, Merchants.fika, 4.80),
    card(23, 13, 0, Merchants.greenleaf, 39.12),
    card(24, 19, 30, Merchants.lumen, 12.99, card: 'aurora'),
    card(26, 22, 5, Merchants.taxi, 23.10, card: 'midnight'),
    card(27, 12, 0, Merchants.sakura, 15.40),
    card(28, 9, 10, Merchants.greenleaf, 58.66),
    card(29, 10, 0, Merchants.pulse, 39.00),
    card(31, 18, 0, Merchants.atlas, 42.00),
    card(33, 9, 0, Merchants.greenleaf, 44.08),
    card(35, 20, 0, Merchants.bistro, 71.50, card: 'midnight'),
    card(38, 11, 30, Merchants.nordwind, 186.00, card: 'aurora'),
    card(40, 9, 5, Merchants.greenleaf, 36.90),
    card(43, 13, 15, Merchants.kiosk, 12.20),
    card(45, 19, 45, Merchants.sakura, 22.60),
  ];
  list.addAll([
    Txn(
      id: 's${n++}',
      date: daysAgo(salaryDay, hour: 6),
      title: Merchants.employer.name,
      amount: 3450,
      currency: Currency.eur,
      category: TxnCategory.income,
      kind: TxnKind.income,
      merchant: Merchants.employer,
    ),
    Txn(
      id: 's${n++}',
      // Rent goes on the 1st.
      date: daysAgo(today.day - 1, hour: 7),
      title: Merchants.harbor.name,
      amount: -1250,
      currency: Currency.eur,
      category: TxnCategory.housing,
      kind: TxnKind.direct,
      merchant: Merchants.harbor,
    ),
    Txn(
      id: 's${n++}',
      date: daysAgo(salaryDay + 2, hour: 10),
      title: Merchants.sparks.name,
      amount: -64.20,
      currency: Currency.eur,
      category: TxnCategory.bills,
      kind: TxnKind.direct,
      merchant: Merchants.sparks,
    ),
    Txn(
      id: 's${n++}',
      date: daysAgo(salaryDay, hour: 9, minute: 30),
      title: 'Kyoto in spring',
      amount: -150,
      currency: Currency.eur,
      category: TxnCategory.transfers,
      kind: TxnKind.vault,
      vaultId: 'kyoto',
    ),
  ]);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

final sessionProvider = Provider<BankSession>(
  (_) => BankSession(),
  dispose: (session) => session.dispose(),
);

/// Puts the session in the tree as an inherited notifier, so every widget
/// that reads `context.bank` rebuilds when it changes — a `const` section
/// of a page included, which a builder above it would skip.
class SessionScope extends InheritedNotifier<BankSession> {
  const SessionScope({
    required BankSession super.notifier,
    required super.child,
    super.key,
  });
}

extension BankSessionContext on BuildContext {
  /// The session above this context; a widget that reads it in `build`
  /// rebuilds when it changes.
  BankSession get bank =>
      dependOnInheritedWidgetOfExactType<SessionScope>()?.notifier ??
      sessionProvider.of(this);
}
