import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Analytics: where the money went this month or last, how months
/// compare, budgets and subscriptions.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  /// 0 for this month, 1 for the last.
  var _monthsBack = 0;

  DateTime get _month => DateTime(today.year, today.month - _monthsBack);

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final picker = SegmentedControl<int>(
      value: _monthsBack,
      onChanged: (value) => setState(() => _monthsBack = value),
      segments: [
        const Segment(value: 0, label: Text('This month')),
        Segment(
          value: 1,
          label: Text(
            DateFormat.MMMM().format(DateTime(today.year, today.month - 1)),
          ),
        ),
      ],
    );
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final month = _month;
        return PageContainer(
          scrollable: true,
          maxWidth: 1200,
          child: FormFactorBuilder(
            mobile: (context) => UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                picker,
                _Summary(month: month),
                _ByCategory(month: month),
                const _Monthly(),
                _Budgets(month: month),
                const _Subscriptions(),
              ],
            ),
            desktop: (context) => UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Analytics',
                  subtitle: 'Where your money went, and where it is going',
                  actions: [picker],
                ),
                _Summary(month: month),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final gap = Theme.of(context).layoutTheme.gap(GapSize.lg);
                    final left = UnaColumn(
                      gap: GapSize.lg,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ByCategory(month: month),
                        const _Subscriptions(),
                      ],
                    );
                    final right = UnaColumn(
                      gap: GapSize.lg,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _Monthly(),
                        _Budgets(month: month),
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
                        Expanded(child: left),
                        SizedBox(width: gap),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Spent, came in, saved and a day's average: four figures.
class _Summary extends StatelessWidget {
  const _Summary({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    final spent = session.spentIn(month);
    final current = month.month == today.month && month.year == today.year;
    final days = current
        ? today.day
        : DateTime(month.year, month.month + 1, 0).day;
    double sum(bool Function(Txn txn) test) => session.transactions
        .where(
          (txn) =>
              txn.date.year == month.year &&
              txn.date.month == month.month &&
              test(txn),
        )
        .fold<double>(0, (sum, txn) => sum + txn.inEuros);
    final income = sum(
      (txn) =>
          txn.amount > 0 &&
          (txn.kind == TxnKind.income || txn.kind == TxnKind.transfer),
    );
    final saved = -sum((txn) => txn.kind == TxnKind.vault);
    Widget tile(IconData icon, String label, double value) => StatTile(
      icon: PhosphorIcon(icon),
      value: AmountText(
        value,
        Currency.eur,
        decimals: 0,
        style: theme.textTheme.h3.copyWith(color: theme.colorScheme.foreground),
      ),
      label: Text(label),
    );
    final tiles = [
      tile(PhosphorIconsRegular.arrowUpRight, 'Spent', spent),
      tile(PhosphorIconsRegular.arrowDownLeft, 'Came in', income),
      tile(PhosphorIconsRegular.piggyBank, 'Saved', saved),
      tile(PhosphorIconsRegular.calendarDots, 'Daily average', spent / days),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final perRow = constraints.maxWidth > 760 ? 4 : 2;
        final gap = theme.layoutTheme.gap(GapSize.md);
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// The month's spending as a donut, and a row per category.
class _ByCategory extends StatelessWidget {
  const _ByCategory({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    final entries = session.spendingByCategory(month);
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.$2);
    final hidden = session.hideBalances;
    return Card(
      title: const Text('Spending by category'),
      description: Text(DateFormat.yMMMM().format(month)),
      child: entries.isEmpty
          ? const Empty(
              icon: PhosphorIcon(PhosphorIconsRegular.chartPieSlice),
              title: Text('Nothing spent yet'),
              description: Text('Card payments land here as you make them.'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: SizedBox.square(
                    dimension: 220,
                    child: DonutChart(
                      segments: [
                        for (final (category, value) in entries)
                          ChartSegment(
                            label: category.label,
                            value: value,
                            color: category.color,
                          ),
                      ],
                      valueFormatter: (value) =>
                          hidden ? '€••••' : money(value, Currency.eur),
                      semanticLabel: 'Spending by category',
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Spent', style: theme.textTheme.caption),
                          AmountText(
                            total,
                            Currency.eur,
                            decimals: 0,
                            style: theme.textTheme.h3.copyWith(
                              color: scheme.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap.lg(),
                for (final (category, value) in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        IconTile(
                          size: 34,
                          icon: PhosphorIcon(category.icon),
                          foregroundColor: category.color,
                          backgroundColor: category.color.withValues(
                            alpha: .14,
                          ),
                        ),
                        const Gap.md(),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category.label,
                                      style: theme.textTheme.small.copyWith(
                                        color: scheme.foreground,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  AmountText(
                                    value,
                                    Currency.eur,
                                    style: theme.textTheme.small.copyWith(
                                      color: scheme.foreground,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const Gap.xs(),
                              Row(
                                children: [
                                  Expanded(
                                    child: ProgressBar(
                                      value: value / total,
                                      color: category.color,
                                      height: 4,
                                    ),
                                  ),
                                  const Gap.sm(),
                                  SizedBox(
                                    width: 36,
                                    child: Text(
                                      '${(value / total * 100).round()}%',
                                      textAlign: TextAlign.end,
                                      style: theme.textTheme.caption.tabular,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Six months side by side.
class _Monthly extends StatelessWidget {
  const _Monthly();

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final values = session.monthlySpending;
    final labels = [
      for (var i = values.length - 1; i >= 0; i--)
        DateFormat.MMM().format(DateTime(today.year, today.month - i)),
    ];
    final average =
        values.take(values.length - 1).reduce((a, b) => a + b) /
        (values.length - 1);
    final hidden = session.hideBalances;
    return Card(
      title: const Text('Month by month'),
      description: Text(
        hidden
            ? 'Your average month'
            : 'You spend ${money(average, Currency.eur, decimals: 0)} in an average month',
      ),
      child: SizedBox(
        height: 220,
        child: BarChart(
          labels: labels,
          series: [ChartSeries(label: 'Spent', values: values)],
          valueFormatter: (value) =>
              hidden ? '€••••' : money(value, Currency.eur, decimals: 0),
          tickFormatter: (value) => hidden
              ? ''
              : '€${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k',
          semanticLabel: 'Spending by month',
        ),
      ),
    );
  }
}

/// A budget per category: how much of it the month has used.
class _Budgets extends StatelessWidget {
  const _Budgets({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Budgets'),
      headerTrailing: Button.link(
        onPressed: () => showDemoToast(
          context,
          'Budgets are set for the month',
          description: 'They start again on the 1st.',
        ),
        child: const Text('Edit'),
      ),
      children: [
        for (final MapEntry(key: category, value: budget) in budgets.entries)
          () {
            final spent = session.spentIn(month, category: category);
            final share = spent / budget;
            final over = spent > budget;
            return ListTile(
              leading: IconTile(
                icon: PhosphorIcon(category.icon),
                foregroundColor: category.color,
                backgroundColor: category.color.withValues(alpha: .14),
              ),
              title: Text(category.label),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ProgressBar(
                  value: share.clamp(0, 1).toDouble(),
                  height: 6,
                  color: over
                      ? scheme.destructive
                      : share > .8
                      ? scheme.warning
                      : category.color,
                  semanticLabel: '${category.label} budget',
                ),
              ),
              trailing: SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AmountText(
                      spent,
                      Currency.eur,
                      decimals: 0,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: over ? scheme.destructive : scheme.foreground,
                      ),
                    ),
                    Text(
                      over
                          ? '${money(spent - budget, Currency.eur, decimals: 0)} over'
                          : 'of ${money(budget, Currency.eur, decimals: 0)}',
                      style: theme.textTheme.caption.tabular,
                    ),
                  ],
                ),
              ),
            );
          }(),
      ],
    );
  }
}

/// What charges every month, and when next.
class _Subscriptions extends StatelessWidget {
  const _Subscriptions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = subscriptions.fold<double>(0, (sum, s) => sum + s.amount);
    final sorted = [...subscriptions]
      ..sort((a, b) => a.nextCharge.compareTo(b.nextCharge));
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Subscriptions'),
      headerTrailing: Text(
        '${money(total, Currency.eur)} a month',
        style: theme.textTheme.caption.tabular,
      ),
      children: [
        for (final subscription in sorted)
          ListTile(
            leading: MerchantLogo(subscription.merchant),
            title: Text(subscription.merchant.name),
            subtitle: Text(
              'Next on ${DateFormat.MMMd().format(subscription.nextCharge)} · card ${context.bank.card(subscription.cardId).masked}',
            ),
            trailing: AmountText(
              subscription.amount,
              Currency.eur,
              style: theme.textTheme.small.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.foreground,
              ),
            ),
            onTap: () => showDemoToast(
              context,
              subscription.merchant.name,
              description:
                  'Cancel it with ${subscription.merchant.name} itself, or freeze the card to stop the charge.',
            ),
          ),
      ],
    );
  }
}
