import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/flows.dart';
import 'package:una_banking/widgets/pieces.dart';

/// The whole statement, day by day, to search and filter by category, card
/// and size.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  var _query = '';
  final _categories = <TxnCategory>{};
  String? _cardId;
  var _large = false;

  bool _matches(Txn txn) {
    final query = _query.trim().toLowerCase();
    if (query.isNotEmpty &&
        !txn.title.toLowerCase().contains(query) &&
        !(txn.note?.toLowerCase().contains(query) ?? false) &&
        !txn.category.label.toLowerCase().contains(query)) {
      return false;
    }
    if (_categories.isNotEmpty && !_categories.contains(txn.category)) {
      return false;
    }
    if (_cardId != null && txn.cardId != _cardId) return false;
    if (_large && txn.inEuros.abs() < 50) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const PhosphorIcon(PhosphorIconsRegular.downloadSimple),
            semanticLabel: 'Download statement',
            onPressed: () => showDemoToast(
              context,
              'Statement downloaded',
              description: 'Every line below, as a CSV.',
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final lines = session.transactions.where(_matches).toList();
          final days = <DateTime, List<Txn>>{};
          for (final txn in lines) {
            days
                .putIfAbsent(
                  DateTime(txn.date.year, txn.date.month, txn.date.day),
                  () => [],
                )
                .add(txn);
          }
          final filters = UnaColumn(
            gap: GapSize.sm,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchField(
                placeholder: const Text('Search payments, people, notes'),
                onChanged: (value) => setState(() => _query = value),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                child: Row(
                  children: [
                    Select<String>(
                      value: _cardId,
                      allowDeselection: true,
                      placeholder: const Text('All cards'),
                      size: ControlSize.sm,
                      onChanged: (id) => setState(() => _cardId = id),
                      options: [
                        for (final card in session.cards)
                          SelectOption(
                            value: card.id,
                            child: Text('${card.name} ${card.masked}'),
                          ),
                      ],
                      selectedOptionBuilder: (context, id) =>
                          Text(session.maybeCard(id)?.name ?? 'All cards'),
                    ),
                    const Gap.sm(),
                    Chip(
                      label: const Text('Over €50'),
                      selected: _large,
                      onSelected: (value) => setState(() => _large = value),
                    ),
                    const Gap.sm(),
                    ChipGroup<TxnCategory>.multiple(
                      wrap: false,
                      semanticLabel: 'Categories',
                      values: _categories,
                      onValuesChanged: (values) => setState(
                        () => _categories
                          ..clear()
                          ..addAll(values),
                      ),
                      items: [
                        for (final category in TxnCategory.values)
                          ChipGroupItem(
                            value: category,
                            leading: PhosphorIcon(category.icon),
                            label: Text(category.label),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
          final total = lines
              .where(
                (txn) => txn.amount < 0 && txn.status != TxnStatus.declined,
              )
              .fold<double>(0, (sum, txn) => sum - txn.inEuros);
          return PageContainer(
            scrollable: true,
            maxWidth: 760,
            child: UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filters,
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${lines.length} ${lines.length == 1 ? 'payment' : 'payments'}',
                        style: theme.textTheme.muted,
                      ),
                    ),
                    Text('Out ', style: theme.textTheme.muted),
                    AmountText(
                      total,
                      Currency.eur,
                      style: theme.textTheme.small.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
                if (lines.isEmpty)
                  Empty(
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.magnifyingGlass,
                    ),
                    title: const Text('Nothing matches'),
                    description: const Text(
                      'Try fewer filters or another word.',
                    ),
                    actions: [
                      Button.outline(
                        onPressed: () => setState(() {
                          _categories.clear();
                          _cardId = null;
                          _large = false;
                        }),
                        child: const Text('Clear filters'),
                      ),
                    ],
                  ),
                for (final MapEntry(key: day, value: txns) in days.entries)
                  ListSection(
                    margin: EdgeInsets.zero,
                    header: Text(dayHeading(day)),
                    headerTrailing: AmountText(
                      txns
                          .where(
                            (txn) =>
                                txn.amount < 0 &&
                                txn.status != TxnStatus.declined,
                          )
                          .fold<double>(0, (sum, txn) => sum + txn.inEuros),
                      Currency.eur,
                      style: theme.textTheme.caption,
                    ),
                    children: [
                      for (final txn in txns)
                        TxnTile(txn, onTap: () => showTxnDetail(context, txn)),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
