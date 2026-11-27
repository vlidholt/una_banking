import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/screens/transactions_screen.dart';
import 'package:una_banking/screens/vault_screen.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/bank_card.dart';
import 'package:una_banking/widgets/flows.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Home: what you have, what to do with it, and what just happened.
///
/// A desktop puts the balance and the statement on the left and cards,
/// spending and vaults on the right; a phone stacks them.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => PageContainer(
        scrollable: true,
        maxWidth: 1200,
        child: FormFactorBuilder(
          mobile: (context) => const _PhoneHome(),
          desktop: (context) => const _DesktopHome(),
        ),
      ),
    );
  }
}

String _greeting() {
  final hour = DateTime.now().hour;
  if (hour < 5) return 'Good night';
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class _DesktopHome extends StatelessWidget {
  const _DesktopHome();

  @override
  Widget build(BuildContext context) {
    return UnaColumn(
      gap: GapSize.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: '${_greeting()}, ${People.me.firstName}',
          subtitle: DateFormat('EEEE d MMMM').format(DateTime.now()),
          actions: [
            Button.outline(
              leading: const PhosphorIcon(PhosphorIconsRegular.handCoins),
              onPressed: () => showRequestFlow(context),
              child: const Text('Request'),
            ),
            Button(
              leading: const PhosphorIcon(PhosphorIconsBold.paperPlaneTilt),
              onPressed: () => showSendFlow(context),
              child: const Text('Send money'),
            ),
          ],
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = Theme.of(context).layoutTheme.gap(GapSize.lg);
            final left = UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [BalanceHero(), RecentTransactions(count: 7)],
            );
            final right = UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                _CardsPeek(),
                SpendingInsight(),
                _VaultsList(),
              ],
            );
            if (constraints.maxWidth < 860) {
              return UnaColumn(
                gap: GapSize.lg,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [left, right],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 7, child: left),
                SizedBox(width: gap),
                Expanded(flex: 5, child: right),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PhoneHome extends StatelessWidget {
  const _PhoneHome();

  @override
  Widget build(BuildContext context) {
    return const UnaColumn(
      gap: GapSize.lg,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BalanceHero(),
        SpendingInsight(),
        RecentTransactions(count: 5),
        _VaultStrip(),
        _CardsPeek(),
      ],
    );
  }
}

/// The balance: everything you hold, then each account, swiped through,
/// over the brand's gradient, with the four things you do most under it.
class BalanceHero extends StatefulWidget {
  const BalanceHero({super.key});

  @override
  State<BalanceHero> createState() => _BalanceHeroState();
}

class _BalanceHeroState extends State<BalanceHero> {
  var _page = 0;
  final _controller = CarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    final accounts = session.accounts;
    const white = Color(0xFFFFFFFF);
    final mobile = theme.formFactor == FormFactor.mobile;
    final account = _page == 0 ? null : accounts[_page - 1];
    final pages = [
      _BalancePage(
        label: 'Total · ${accounts.length} accounts and vaults',
        amount: session.totalInEuros,
        currency: Currency.eur,
        leading: const PhosphorIcon(
          PhosphorIconsFill.wallet,
          size: 18,
          color: white,
        ),
      ),
      for (final currency in accounts)
        _BalancePage(
          label: '${currency.label} · ${currency.code}',
          amount: session.balanceOf(currency),
          currency: currency,
          leading: CurrencyBadge(currency, size: 20),
        ),
    ];
    return Semantics(
      container: true,
      label: 'Balances',
      child: ClipRSuperellipse(
        borderRadius: theme.radii.xl2,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: theme.brightness == Brightness.dark
                  ? const [
                      Color(0xFFE2573A),
                      Color(0xFFA63A5B),
                      Color(0xFF4B2346),
                    ]
                  : const [
                      Color(0xFFFF8A5B),
                      Color(0xFFE8453C),
                      Color(0xFF9C2F62),
                    ],
              stops: const [0, .55, 1],
            ),
          ),
          child: CustomPaint(
            painter: const _HeroGlow(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                0,
                mobile ? 18 : 22,
                0,
                mobile ? 18 : 22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Carousel(
                    controller: _controller,
                    height: mobile ? 92 : 104,
                    onPageChanged: (page) => setState(() => _page = page),
                    semanticLabel: 'Accounts',
                    children: pages,
                  ),
                  const Gap.sm(),
                  Center(
                    child: PageIndicator(
                      count: pages.length,
                      index: _page,
                      color: white.withValues(alpha: .4),
                      activeColor: white,
                      onSelected: _controller.animateToPage,
                      semanticLabel: 'Account',
                    ),
                  ),
                  const Gap.lg(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: RoundAction(
                            icon: PhosphorIconsBold.plus,
                            label: 'Add money',
                            onImage: true,
                            onPressed: () => showAddMoneyFlow(
                              context,
                              currency: account ?? Currency.eur,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RoundAction(
                            icon: PhosphorIconsBold.paperPlaneTilt,
                            label: 'Send',
                            onImage: true,
                            onPressed: () => showSendFlow(context),
                          ),
                        ),
                        Expanded(
                          child: RoundAction(
                            icon: PhosphorIconsBold.arrowsClockwise,
                            label: 'Exchange',
                            onImage: true,
                            onPressed: () => showExchangeFlow(
                              context,
                              from: account ?? Currency.eur,
                              to: account == null || account == Currency.eur
                                  ? Currency.usd
                                  : Currency.eur,
                            ),
                          ),
                        ),
                        Expanded(
                          child: RoundAction(
                            icon: PhosphorIconsBold.dotsThree,
                            label: 'More',
                            onImage: true,
                            onPressed: () => showMoreActions(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One page of the balance carousel.
class _BalancePage extends StatelessWidget {
  const _BalancePage({
    required this.label,
    required this.amount,
    required this.currency,
    required this.leading,
  });

  final String label;
  final double amount;
  final Currency currency;
  final Widget leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const white = Color(0xFFFFFFFF);
    final mobile = theme.formFactor == FormFactor.mobile;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              leading,
              const Gap.sm(),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    color: white.withValues(alpha: .85),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const Gap.sm(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: BalanceText(
              amount,
              currency,
              size: mobile ? 38 : 46,
              color: white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two soft lights on the hero, so the gradient reads as a surface.
class _HeroGlow extends CustomPainter {
  const _HeroGlow();

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset center, double radius, Color color) => canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    glow(
      Offset(size.width * .92, size.height * .05),
      size.width * .45,
      const Color(0x40FFD9B8),
    );
    glow(
      Offset(size.width * .05, size.height * 1.1),
      size.width * .5,
      const Color(0x332B0A2E),
    );
  }

  @override
  bool shouldRepaint(_HeroGlow oldDelegate) => false;
}

/// The latest lines of the statement, with the way to all of them.
class RecentTransactions extends StatelessWidget {
  const RecentTransactions({this.count = 5, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final latest = session.transactions.take(count).toList();
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Transactions'),
      headerTrailing: Button.link(
        onPressed: () =>
            context.pushPage<void>((context) => const TransactionsScreen()),
        child: const Text('See all'),
      ),
      children: [
        for (final txn in latest)
          TxnTile(
            txn,
            showDate: true,
            onTap: () => showTxnDetail(context, txn),
          ),
      ],
    );
  }
}

/// This month's spending against last month's, and the biggest category.
class SpendingInsight extends StatelessWidget {
  const SpendingInsight({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    final spent = session.spentIn(today);
    final daily = _cumulativeByDay(session);
    final lastDaily = _lastMonthByDay();
    // Last month by the same day, so the comparison is fair mid-month.
    final last = lastDaily.last;
    final change = last == 0 ? 0.0 : (spent - last) / last * 100;
    final lastMonth = DateFormat.MMMM().format(
      DateTime(today.year, today.month - 1),
    );
    final hidden = session.hideBalances;
    final series = [
      ChartSeries(
        label: DateFormat.MMMM().format(today),
        values: daily,
        color: scheme.tint,
      ),
      ChartSeries(
        label: '$lastMonth, same days',
        values: lastDaily,
        color: scheme.mutedForeground.withValues(alpha: .7),
      ),
    ];
    final top = session
        .spendingByCategory(today)
        .where((entry) => !TxnCategory.fixed.contains(entry.$1))
        .firstOrNull;
    return Card(
      onTap: () => context.goTo(Destination.analytics),
      semanticLabel: 'Spending this month',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Spent this month', style: theme.textTheme.muted),
                    const Gap.xs(),
                    AmountText(
                      spent,
                      Currency.eur,
                      style: theme.textTheme.h2.copyWith(
                        color: scheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              Badge(
                variant: change <= 0
                    ? BadgeVariant.secondary
                    : BadgeVariant.outline,
                child: Text(
                  '${change <= 0 ? '↓' : '↑'} ${change.abs().round()}% vs last month',
                ),
              ),
            ],
          ),
          const Gap.md(),
          SizedBox(
            height: 132,
            child: LineChart(
              labels: [
                for (var day = 1; day <= daily.length; day++)
                  DateFormat.MMMd().format(
                    DateTime(today.year, today.month, day),
                  ),
              ],
              series: series,
              // Rent lands on the 1st, so both lines start high: fitting
              // the range to them keeps the chart from being mostly air.
              minValue: math.min(daily.first, lastDaily.first) * .9,
              maxValue: math.max(daily.last, lastDaily.last) * 1.04,
              showGrid: false,
              showYAxis: false,
              showXAxis: false,
              valueFormatter: (value) =>
                  hidden ? '€••••' : money(value, Currency.eur, decimals: 0),
              semanticLabel: 'Spending through the month against last month',
            ),
          ),
          const Gap.sm(),
          ChartLegend(entries: series, alignment: WrapAlignment.start),
          if (top != null) ...[
            const Gap.md(),
            Row(
              children: [
                IconTile(
                  size: 32,
                  icon: PhosphorIcon(top.$1.icon),
                  foregroundColor: top.$1.color,
                  backgroundColor: top.$1.color.withValues(alpha: .14),
                ),
                const Gap.sm(),
                Expanded(
                  child: Text(
                    'Most of it on ${top.$1.label.toLowerCase()}',
                    style: theme.textTheme.small,
                  ),
                ),
                AmountText(
                  top.$2,
                  Currency.eur,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// What last month had cost by each day of it up to today's: the rent
  /// on the 1st, the rest of [pastMonthsSpent]'s last month spread over
  /// the days with a little of a real month's unevenness.
  static List<double> _lastMonthByDay() {
    final lastDays = DateTime(today.year, today.month, 0).day;
    const rent = 1250.0;
    final rest = pastMonthsSpent.last - rent;
    final days = today.day < 2 ? 2 : today.day;
    return [
      for (var day = 1; day <= days; day++)
        () {
          final t = (day / lastDays).clamp(0, 1).toDouble();
          final wobble = .02 * math.sin(day * 1.7) + .015 * math.sin(day * .6);
          return rent + rest * (t + wobble * t).clamp(0, 1);
        }(),
    ];
  }

  /// What the month has cost so far, day by day.
  static List<double> _cumulativeByDay(BankSession session) {
    final days = List<double>.filled(today.day, 0);
    for (final txn in session.transactions) {
      if (txn.amount >= 0 ||
          txn.status == TxnStatus.declined ||
          txn.date.year != today.year ||
          txn.date.month != today.month ||
          !TxnCategory.spending.contains(txn.category)) {
        continue;
      }
      days[txn.date.day - 1] -= txn.inEuros;
    }
    var sum = 0.0;
    final out = [for (final day in days) sum += day];
    // A line needs two points: on the 1st, the day starts from nothing.
    return out.length < 2 ? [0, ...out] : out;
  }
}

/// Your main card, and how many more there are.
class _CardsPeek extends StatelessWidget {
  const _CardsPeek();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    final cards = session.cards;
    return Card(
      title: const Text('Cards'),
      description: Text(
        '${cards.length} cards · ${cards.where((card) => card.frozen).length} frozen',
      ),
      action: Button.link(
        onPressed: () => context.goTo(Destination.cards),
        child: const Text('Manage'),
      ),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cards.length + 1,
          separatorBuilder: (context, index) => const Gap.sm(),
          itemBuilder: (context, index) {
            if (index == cards.length) {
              return Pressable(
                onPressed: () => showOrderCardFlow(context),
                semanticLabel: 'New card',
                builder: (context, states) => AnimatedFill(
                  color: states.contains(WidgetState.hovered)
                      ? theme.colorScheme.accent
                      : theme.colorScheme.secondary,
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 120,
                    child: Center(
                      child: PhosphorIcon(
                        PhosphorIconsBold.plus,
                        size: 20,
                        color: theme.colorScheme.foreground,
                      ),
                    ),
                  ),
                ),
              );
            }
            final card = cards[index];
            return Pressable(
              onPressed: () {
                selectedCardProvider.of(context).value = card.id;
                context.goTo(Destination.cards);
              },
              semanticLabel: '${card.name} ${card.masked}',
              builder: (context, states) => SizedBox(
                width: 120,
                child: BankCardView(card, compact: true),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Vaults on a desktop: a row per vault with its ring.
class _VaultsList extends StatelessWidget {
  const _VaultsList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Vaults'),
      headerTrailing: AmountText(
        session.savedInVaults,
        Currency.eur,
        style: theme.textTheme.caption,
      ),
      children: [
        for (final vault in session.vaults)
          ListTile(
            leading: ClipRSuperellipse(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                vault.photo,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
              ),
            ),
            title: Text(vault.name),
            subtitle: Text(
              '${money(vault.saved, Currency.eur, decimals: 0)} of ${money(vault.target, Currency.eur, decimals: 0)}',
            ),
            trailing: ProgressRing(
              value: vault.progress,
              size: 34,
              semanticLabel: '${vault.name} progress',
            ),
            onTap: () => openVault(context, vault),
          ),
      ],
    );
  }
}

/// Vaults on a phone: photo cards in a strip that scrolls sideways.
class _VaultStrip extends StatelessWidget {
  const _VaultStrip();

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return UnaColumn(
      gap: GapSize.sm,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          'Vaults',
          action: money(session.savedInVaults, Currency.eur, decimals: 0),
          onAction: () => openVault(context, session.vaults.first),
        ),
        SizedBox(
          height: 196,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: session.vaults.length,
            separatorBuilder: (context, index) => const Gap.md(),
            itemBuilder: (context, index) =>
                SizedBox(width: 220, child: VaultCard(session.vaults[index])),
          ),
        ),
      ],
    );
  }
}

/// A vault as a card: its photo, its name, how far along it is.
class VaultCard extends StatelessWidget {
  const VaultCard(this.vault, {super.key});

  final Vault vault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      onTap: () => openVault(context, vault),
      semanticLabel: vault.name,
      style: const CardTheme(padding: EdgeInsets.zero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRSuperellipse(
            borderRadius: BorderRadius.vertical(
              top: (theme.cardTheme.borderRadius ?? theme.radii.xl)
                  .resolve(Directionality.of(context))
                  .topLeft,
            ),
            child: SizedBox(
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(vault.photo, fit: BoxFit.cover),
                  if (vault.roundUps)
                    PositionedDirectional(
                      top: 8,
                      start: 8,
                      child: Glass(
                        frosted: false,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        borderRadius: theme.radii.full,
                        child: Text(
                          'Round-ups on',
                          style: theme.textTheme.caption.copyWith(
                            color: theme.colorScheme.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vault.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                const Gap.xs(),
                ProgressBar(value: vault.progress),
                const Gap.xs(),
                Text(
                  '${money(vault.saved, Currency.eur, decimals: 0)} of ${money(vault.target, Currency.eur, decimals: 0)}',
                  style: theme.textTheme.caption.tabular,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens [vault]'s page.
void openVault(BuildContext context, Vault vault) =>
    context.pushPage<void>((context) => VaultScreen(vaultId: vault.id));
