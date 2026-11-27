import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/money.dart';

/// All of the app's seed content: people, merchants, accounts, cards,
/// transactions, vaults, budgets and subscriptions. Dates are counted back
/// from [today], so the account always reads as this month's.
///
/// Every person and company is fictional.

/// The day the app thinks it is.
final DateTime today = () {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}();

DateTime daysAgo(int days, {int hour = 12, int minute = 0}) => today
    .subtract(Duration(days: days))
    .add(
      Duration(hours: hour, minutes: minute),
    );

/// A person you can pay.
class Person {
  const Person(this.id, this.name, this.handle, this.photo);

  final String id;
  final String name;
  final String handle;
  final String photo;

  String get firstName => name.split(' ').first;
  String get initials =>
      name.split(' ').map((part) => part.substring(0, 1)).take(2).join();
}

abstract final class People {
  static const me = Person(
    'me',
    'Alex Moreau',
    '@alexmoreau',
    'assets/images/avatar_me.jpg',
  );
  static const maya = Person(
    'maya',
    'Maya Lindqvist',
    '@mayal',
    'assets/images/avatar_maya.jpg',
  );
  static const jonas = Person(
    'jonas',
    'Jonas Weber',
    '@jonasw',
    'assets/images/avatar_jonas.jpg',
  );
  static const ines = Person(
    'ines',
    'Inès Laurent',
    '@ines.l',
    'assets/images/avatar_ines.jpg',
  );
  static const samir = Person(
    'samir',
    'Samir Haddad',
    '@samirh',
    'assets/images/avatar_samir.jpg',
  );
  static const mei = Person(
    'mei',
    'Mei Tanaka',
    '@meitanaka',
    'assets/images/avatar_mei.jpg',
  );
  static const oliver = Person(
    'oliver',
    'Oliver Mensah',
    '@olimensah',
    'assets/images/avatar_oliver.jpg',
  );
  static const ruth = Person(
    'ruth',
    'Ruth Alvarez',
    '@ruthalv',
    'assets/images/avatar_ruth.jpg',
  );
  static const hana = Person(
    'hana',
    'Hana Kobayashi',
    '@hanak',
    'assets/images/avatar_hana.jpg',
  );
  static const noah = Person(
    'noah',
    'Noah Fischer',
    '@noahf',
    'assets/images/avatar_noah.jpg',
  );
  static const zara = Person(
    'zara',
    'Zara Okafor',
    '@zaraok',
    'assets/images/avatar_zara.jpg',
  );

  /// The people you pay, most recent first.
  static const contacts = [
    maya,
    jonas,
    ines,
    samir,
    mei,
    oliver,
    ruth,
    hana,
    noah,
    zara,
  ];
}

/// What a payment was for.
enum TxnCategory {
  groceries('Groceries', PhosphorIconsRegular.shoppingCart, Color(0xFF2F9E44)),
  eatingOut('Eating out', PhosphorIconsRegular.forkKnife, Color(0xFFF76707)),
  transport('Transport', PhosphorIconsRegular.train, Color(0xFF1C7ED6)),
  travel('Travel', PhosphorIconsRegular.airplaneTilt, Color(0xFF0CA678)),
  shopping('Shopping', PhosphorIconsRegular.bag, Color(0xFFD6336C)),
  entertainment(
    'Entertainment',
    PhosphorIconsRegular.filmSlate,
    Color(0xFF7048E8),
  ),
  housing('Home', PhosphorIconsRegular.house, Color(0xFF5C7CFA)),
  bills('Bills', PhosphorIconsRegular.receipt, Color(0xFFF59F00)),
  health('Health', PhosphorIconsRegular.heartbeat, Color(0xFFE03131)),
  transfers(
    'Transfers',
    PhosphorIconsRegular.arrowsLeftRight,
    Color(0xFF495057),
  ),
  income('Income', PhosphorIconsRegular.arrowDownLeft, Color(0xFF2B8A3E));

  const TxnCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;

  /// The category's identity colour, in charts and on its icon tile.
  final Color color;

  /// The categories that count as spending.
  static const spending = [
    groceries,
    eatingOut,
    transport,
    travel,
    shopping,
    entertainment,
    housing,
    bills,
    health,
  ];

  /// What insights leave out of "most of it on": the rent dwarfs the rest
  /// and tells you nothing new.
  static const fixed = [housing, bills];
}

/// A business you pay, with the mark the app draws for it.
class Merchant {
  const Merchant(
    this.name,
    this.category,
    this.icon,
    this.colors, {
    this.place = '',
  });

  final String name;
  final TxnCategory category;
  final IconData icon;

  /// The two stops of the merchant's logo tile.
  final (Color, Color) colors;

  /// Where you paid them, as a statement says it.
  final String place;
}

abstract final class Merchants {
  static const fika = Merchant(
    'Fika & Co',
    TxnCategory.eatingOut,
    PhosphorIconsFill.coffee,
    (Color(0xFFB08968), Color(0xFF7F5539)),
    place: 'Rue Oberkampf 41, Paris',
  );
  static const greenleaf = Merchant(
    'Greenleaf Market',
    TxnCategory.groceries,
    PhosphorIconsFill.leaf,
    (Color(0xFF51CF66), Color(0xFF2B8A3E)),
    place: 'Boulevard Voltaire 112, Paris',
  );
  static const metro = Merchant(
    'Metro Transit',
    TxnCategory.transport,
    PhosphorIconsFill.train,
    (Color(0xFF4DABF7), Color(0xFF1864AB)),
    place: 'Paris',
  );
  static const nordwind = Merchant(
    'Nordwind Air',
    TxnCategory.travel,
    PhosphorIconsFill.airplaneTilt,
    (Color(0xFF63E6BE), Color(0xFF087F5B)),
    place: 'Online',
  );
  static const lumen = Merchant(
    'Lumen Streaming',
    TxnCategory.entertainment,
    PhosphorIconsFill.playCircle,
    (Color(0xFF9775FA), Color(0xFF5F3DC4)),
    place: 'Online',
  );
  static const pulse = Merchant(
    'Pulse Fitness',
    TxnCategory.health,
    PhosphorIconsFill.barbell,
    (Color(0xFFFF8787), Color(0xFFC92A2A)),
    place: 'Rue de la Roquette 8, Paris',
  );
  static const cloudnest = Merchant(
    'Cloudnest',
    TxnCategory.bills,
    PhosphorIconsFill.cloud,
    (Color(0xFF74C0FC), Color(0xFF1971C2)),
    place: 'Online',
  );
  static const atlas = Merchant(
    'Atlas Books',
    TxnCategory.shopping,
    PhosphorIconsFill.bookOpen,
    (Color(0xFFFFA94D), Color(0xFFD9480F)),
    place: 'Rue Saint-Jacques 3, Paris',
  );
  static const harbor = Merchant(
    'Harbor Homes',
    TxnCategory.housing,
    PhosphorIconsFill.house,
    (Color(0xFFADB5BD), Color(0xFF495057)),
    place: 'Rent',
  );
  static const sparks = Merchant(
    'Sparks Energy',
    TxnCategory.bills,
    PhosphorIconsFill.lightning,
    (Color(0xFFFFD43B), Color(0xFFF08C00)),
    place: 'Direct debit',
  );
  static const bistro = Merchant(
    'Bistro Lumière',
    TxnCategory.eatingOut,
    PhosphorIconsFill.wine,
    (Color(0xFFE599F7), Color(0xFF9C36B5)),
    place: 'Rue des Martyrs 27, Paris',
  );
  static const sakura = Merchant(
    'Sakura Ramen',
    TxnCategory.eatingOut,
    PhosphorIconsFill.bowlFood,
    (Color(0xFFFFA8A8), Color(0xFFE03131)),
    place: 'Rue Sainte-Anne 14, Paris',
  );
  static const velo = Merchant(
    'Vélo Atelier',
    TxnCategory.shopping,
    PhosphorIconsFill.bicycle,
    (Color(0xFF3BC9DB), Color(0xFF0B7285)),
    place: 'Canal Saint-Martin, Paris',
  );
  static const tune = Merchant(
    'Tune',
    TxnCategory.entertainment,
    PhosphorIconsFill.musicNotes,
    (Color(0xFF69DB7C), Color(0xFF2B8A3E)),
    place: 'Online',
  );
  static const dailyPaper = Merchant(
    'The Daily Paper',
    TxnCategory.entertainment,
    PhosphorIconsFill.newspaper,
    (Color(0xFF495057), Color(0xFF212529)),
    place: 'Online',
  );
  static const pharmacy = Merchant(
    'Pharmacie du Marais',
    TxnCategory.health,
    PhosphorIconsFill.firstAidKit,
    (Color(0xFF8CE99A), Color(0xFF37B24D)),
    place: 'Rue de Bretagne 51, Paris',
  );
  static const kiosk = Merchant(
    'Kiosk 24',
    TxnCategory.shopping,
    PhosphorIconsFill.storefront,
    (Color(0xFFFFC078), Color(0xFFE8590C)),
    place: 'Gare de l’Est, Paris',
  );
  static const taxi = Merchant(
    'Zipp Rides',
    TxnCategory.transport,
    PhosphorIconsFill.car,
    (Color(0xFF343A40), Color(0xFF000000)),
    place: 'Paris',
  );
  static const employer = Merchant(
    'Halcyon Studio',
    TxnCategory.income,
    PhosphorIconsFill.briefcase,
    (Color(0xFFFF8A65), Color(0xFFD84315)),
    place: 'Salary',
  );
}

/// How a card looks.
enum CardDesign {
  coral('Coral'),
  midnight('Midnight'),
  aurora('Aurora'),
  prism('Prism'),
  sand('Sand');

  const CardDesign(this.label);

  final String label;
}

enum CardKind {
  physical('Physical'),
  virtual('Virtual'),
  disposable('Single-use');

  const CardKind(this.label);

  final String label;
}

/// A card, as the session starts it.
class CardSeed {
  const CardSeed({
    required this.id,
    required this.name,
    required this.kind,
    required this.design,
    required this.number,
    required this.expiry,
    required this.cvv,
    required this.limit,
    required this.spent,
    this.contactless = true,
    this.online = true,
    this.atm = true,
    this.abroad = true,
  });

  final String id;
  final String name;
  final CardKind kind;
  final CardDesign design;
  final String number;
  final String expiry;
  final String cvv;
  final double limit;
  final double spent;
  final bool contactless;
  final bool online;
  final bool atm;
  final bool abroad;
}

abstract final class Seeds {
  static const accounts = {
    Currency.eur: 4812.40,
    Currency.usd: 1240.18,
    Currency.gbp: 386.55,
    Currency.sek: 12450.00,
    Currency.jpy: 58200.0,
  };

  static const cards = [
    CardSeed(
      id: 'coral',
      name: 'Everyday',
      kind: CardKind.physical,
      design: CardDesign.coral,
      number: '4821 7730 1964 4821',
      expiry: '09/29',
      cvv: '318',
      limit: 2500,
      spent: 1184.62,
    ),
    CardSeed(
      id: 'midnight',
      name: 'Metal',
      kind: CardKind.physical,
      design: CardDesign.midnight,
      number: '5310 2286 0491 7703',
      expiry: '02/30',
      cvv: '904',
      limit: 5000,
      spent: 642.10,
    ),
    CardSeed(
      id: 'aurora',
      name: 'Online shopping',
      kind: CardKind.virtual,
      design: CardDesign.aurora,
      number: '4417 9032 6618 3390',
      expiry: '11/27',
      cvv: '527',
      limit: 600,
      spent: 214.97,
      contactless: false,
      atm: false,
    ),
    CardSeed(
      id: 'prism',
      name: 'Single-use',
      kind: CardKind.disposable,
      design: CardDesign.prism,
      number: '4930 1187 2245 6052',
      expiry: '06/27',
      cvv: '146',
      limit: 200,
      spent: 0,
      contactless: false,
      atm: false,
      abroad: false,
    ),
  ];
}

/// A savings goal, as the session starts it.
class VaultSeed {
  const VaultSeed(
    this.id,
    this.name,
    this.photo,
    this.target,
    this.saved, {
    this.roundUps = false,
    this.icon = PhosphorIconsFill.piggyBank,
  });

  final String id;
  final String name;
  final String photo;
  final double target;
  final double saved;
  final bool roundUps;
  final IconData icon;
}

const vaultSeeds = [
  VaultSeed(
    'kyoto',
    'Kyoto in spring',
    'assets/images/vault_kyoto.jpg',
    3000,
    1860,
    roundUps: true,
    icon: PhosphorIconsFill.airplaneTilt,
  ),
  VaultSeed(
    'home',
    'New flat deposit',
    'assets/images/vault_home.jpg',
    12000,
    7450,
    icon: PhosphorIconsFill.house,
  ),
  VaultSeed(
    'bike',
    'Road bike',
    'assets/images/vault_bike.jpg',
    2400,
    2040,
    icon: PhosphorIconsFill.bicycle,
  ),
  VaultSeed(
    'rainy',
    'Rainy day',
    'assets/images/vault_rainy.jpg',
    5000,
    3250,
    icon: PhosphorIconsFill.umbrella,
  ),
];

/// A monthly budget for a category.
const budgets = {
  TxnCategory.groceries: 450.0,
  TxnCategory.eatingOut: 260.0,
  TxnCategory.transport: 120.0,
  TxnCategory.shopping: 300.0,
  TxnCategory.entertainment: 80.0,
};

/// A subscription that charges a card every month.
class Subscription {
  const Subscription(this.merchant, this.amount, this.dayOfMonth, this.cardId);

  final Merchant merchant;
  final double amount;
  final int dayOfMonth;
  final String cardId;

  /// The next date it charges.
  DateTime get nextCharge {
    final thisMonth = DateTime(today.year, today.month, dayOfMonth);
    return thisMonth.isBefore(today)
        ? DateTime(today.year, today.month + 1, dayOfMonth)
        : thisMonth;
  }
}

const subscriptions = [
  Subscription(Merchants.lumen, 12.99, 4, 'aurora'),
  Subscription(Merchants.tune, 10.99, 11, 'aurora'),
  Subscription(Merchants.cloudnest, 2.99, 17, 'aurora'),
  Subscription(Merchants.dailyPaper, 8.00, 21, 'coral'),
  Subscription(Merchants.pulse, 39.00, 1, 'coral'),
];

/// What the last six months cost, oldest first, before this one: the bars
/// of the monthly comparison. This month's figure is the session's.
const pastMonthsSpent = [2140.0, 1985.0, 2420.0, 2210.0, 1890.0];

/// A day's rate from [from] to [to] for the last [days] days, oldest
/// first: the exchange chart's line. Made from a few slow waves, so it
/// looks like a market and ends where [euroRates] does.
List<double> rateHistory(Currency from, Currency to, {int days = 90}) {
  final end = rate(from, to);
  final seed = from.index * 7 + to.index * 3 + 1;
  double wave(double t) =>
      .014 * math.sin(t / 9 + seed) +
      .006 * math.sin(t / 3.3 + seed * 2) +
      .0025 * math.sin(t / 1.4 + seed * 5);
  final drift = .00035 * (seed.isEven ? 1 : -1);
  return [
    for (var i = 0; i < days; i++)
      () {
        final t = (days - 1 - i).toDouble();
        return end * (1 + wave(t) - wave(0) + drift * t);
      }(),
  ];
}
