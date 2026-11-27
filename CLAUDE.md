# Working notes for `una_banking`

**Una Banking** is a fictional money app built entirely from
[`una`](https://github.com/vlidholt/una) widgets: one of the example apps
that show the package in a real product. It deploys to
<https://vlidholt.github.io/una_banking/> on every push to `main`.

`una`'s own `CLAUDE.md` is the reference for the package — theme
architecture, motion, glass, overlays, Flutter gotchas, test habits — and
Una Social and Una Cowork (`vlidholt/una_social`, `vlidholt/una_cowork`)
are the sibling apps whose setup this one copies.

## Depending on una

- `pubspec.yaml` takes `una` from git (`main`); `pubspec.lock` pins the
  commit. Move it with `flutter pub upgrade una` and commit the lock.
- A **gitignored** `pubspec_overrides.yaml` points it at a local checkout.
  With it in place the lock records a path: never commit that lock.
- Only the public barrel (`package:una/una.dart`); no Material.

## The app

- `main.dart` builds the themes once per (brightness, Liquid Glass) pair:
  the default style on `ColorScheme.fromSeed(brandSeed, neutral:
  brandNeutral)` (a coral and warm graphite), text in Inter through a
  static `GoogleFonts` tear-off. Dark is the default theme mode. On the
  web it disables the browser's own context menu.
- `money.dart`: `Currency` (code, symbol, identity colour, decimals),
  the euro rates, `money()` (every amount is written by it) and
  `.tabular` for figures that line up. `CurrencyBadge` is the app's flag.
- `data.dart` is all the seed content (people, merchants and their logo
  colours, cards, vaults, budgets, subscriptions, the rate history). Dates
  are counted from `today`. The category enum is `TxnCategory`: Flutter's
  foundation library already exports a `Category`.
- `session.dart`: `BankSession`, a `ChangeNotifier` with balances, the
  statement (immutable `Txn`s), cards (`BankCard`, mutable), vaults,
  requests, scheduled payments and notifications, and every move
  (`send`, `exchange`, `addMoney`, `addToVault`, `setFrozen`, `split`…).
  **`SessionScope`** (an `InheritedNotifier`, put in by `App`'s builder,
  above the navigator) is what `context.bank` reads: a widget that reads
  the session in `build` rebuilds when it changes. A `ListenableBuilder`
  around a page is not enough on its own: the page's `const` sections are
  skipped by its rebuild.
- `shell.dart` is a `NavigationScaffold`: the top bar from 1024 wide,
  otherwise the phone's app bar and the floating bottom bar. Profile is a
  destination hidden from the desktop's top bar (the account menu reaches
  it). `?tab=` picks the first destination on the web.
- `widgets/flows.dart`: every flow (send, request, exchange, add money,
  vault money, new card, PIN, a transaction, split, open an account,
  More) goes through `showFlow` — a sheet on a phone, a dialog on a
  desktop — and ends on `FlowSuccess`. `ExchangePanel` is also a card on
  the desktop's Payments page.
- `widgets/bank_card.dart` draws a card: five designs painted in code, a
  chip, the network mark ("orbit", fictional), and a frost that springs in
  when the card is frozen (desaturation through a colour matrix and a
  veil).
- `widgets/keypad.dart`: `AmountInput` and `AmountEntry`, the big amount
  and the keypad, which also takes the keyboard's digits.

## Rules the screens follow

- Copy theme text styles, never a bare `TextStyle(fontWeight:)` for a
  whole text. Amounts go through `AmountText`/`BalanceText` (tabular, and
  dots while balances are hidden).
- **A `Button` lays its label out at its natural width.** A label in a
  button that is given less room (an `Expanded` in a row) is a
  `ButtonLabel`, which ellipsises.
- **A `SignalBuilder` must read its signals in its own builder**, not in a
  builder nested inside it, or it asserts that it found none.
- Nothing is a dead end: a control with nowhere to go answers with a toast
  (`showDemoToast`).

## Tests

- `test/screens_test.dart` builds every destination, the cards page for
  every card, the pushed pages and every flow at a phone's, a tablet's and
  a desktop's size, light and dark; an overflow fails it. Tests set text
  in the test font, which is wider than the real one.
- `test/interactions_test.dart` covers the session's moves and, in the
  app: sending from a person to done, an amount over the balance, freezing
  a card, hiding balances, notifications, and the desktop's exchange.
- `pumpAndSettle` is not used; pump fixed frames with `settle`.

## Screenshots

`docs/desktop.png` is headless Chrome at 1200 × 750 on a local build
(`--headless=new --virtual-time-budget=90000
--run-all-compositor-stages-before-draw`); headless Chrome will not lay
out narrower than about 500, so `docs/phone.jpg` is the phone layout at
500 × 1000 (`?tab=cards`), scaled down.
