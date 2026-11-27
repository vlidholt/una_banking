import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/bank_card.dart';
import 'package:una_banking/widgets/keypad.dart';
import 'package:una_banking/widgets/map_preview.dart';
import 'package:una_banking/widgets/pieces.dart';

// The app's flows: sending, requesting, exchanging, adding money, vaults,
// cards and a statement line. Each is a sheet on a phone and a dialog on a
// desktop (`showFlow`), and nothing in them leaves the app.

/// The pause a confirmation takes, so a tap reads as something happening.
const _pause = Duration(milliseconds: 900);

/// A check that pops in, a headline and a line: the end of every flow.
class FlowSuccess extends StatelessWidget {
  const FlowSuccess({
    required this.title,
    this.message,
    this.child,
    this.onDone,
    super.key,
  });

  final String title;
  final String? message;
  final Widget? child;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: UnaColumn(
        gap: GapSize.md,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: PopIn(
              visible: true,
              scale: .3,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.success,
                ),
                child: const PhosphorIcon(
                  PhosphorIconsBold.check,
                  size: 36,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ),
          Semantics(
            liveRegion: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.h3,
            ),
          ),
          if (message != null)
            Text(
              message!,
              textAlign: TextAlign.center,
              style: theme.textTheme.muted,
            ),
          ?child,
          const Gap.xs(),
          Button(
            onPressed: onDone ?? () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// A label and its value on one line of a summary.
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: theme.textTheme.muted)),
          DefaultTextStyle.merge(
            style: theme.textTheme.small
                .copyWith(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.foreground,
                )
                .tabular,
            child: value,
          ),
        ],
      ),
    );
  }
}

/// The accounts as options of a [Select].
List<SelectOption<Currency>> _accountOptions(BankSession session) => [
  for (final currency in session.accounts)
    SelectOption(
      value: currency,
      child: Row(
        children: [
          CurrencyBadge(currency, size: 22),
          const Gap.sm(),
          Text(currency.code),
        ],
      ),
    ),
];

Widget _currencySelect(
  BankSession session,
  Currency value,
  ValueChanged<Currency> onChanged, {
  List<Currency>? only,
}) => Select<Currency>(
  value: value,
  onChanged: (currency) {
    if (currency != null) onChanged(currency);
  },
  options: only == null
      ? _accountOptions(session)
      : [
          for (final option in _accountOptions(session))
            if (only.contains(option.value)) option,
        ],
  selectedOptionBuilder: (context, currency) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CurrencyBadge(currency, size: 20),
      const Gap.sm(),
      Text(currency.code),
    ],
  ),
);

// ------------------------------------------------------------------ send

/// Sends money to a person: who, how much, a look, and done.
Future<void> showSendFlow(BuildContext context, {Person? to}) => showFlow(
  context,
  title: 'Send money',
  builder: (context) => _SendFlow(to: to),
);

enum _SendStep { person, amount, review, done }

class _SendFlow extends StatefulWidget {
  const _SendFlow({this.to});

  final Person? to;

  @override
  State<_SendFlow> createState() => _SendFlowState();
}

class _SendFlowState extends State<_SendFlow> {
  late var _step = widget.to == null ? _SendStep.person : _SendStep.amount;
  late Person? _person = widget.to;
  var _currency = Currency.eur;
  final _amount = AmountInput();
  final _note = TextEditingController();
  var _query = '';
  var _sending = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    await Future<void>.delayed(_pause);
    if (!mounted) return;
    context.bank.send(
      _person!,
      _amount.value,
      _currency,
      note: _note.text,
    );
    Haptics.impact(context, HapticImpact.medium);
    setState(() {
      _sending = false;
      _step = _SendStep.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentSwitch(
      value: _step,
      child: switch (_step) {
        _SendStep.person => _people(context),
        _SendStep.amount => _amountStep(context),
        _SendStep.review => _review(context),
        _SendStep.done => FlowSuccess(
          title: '${money(_amount.value, _currency)} sent',
          message:
              'To ${_person!.name}. It arrived instantly, and there was no fee.',
        ),
      },
    );
  }

  Widget _people(BuildContext context) {
    final matches = People.contacts
        .where(
          (person) =>
              _query.isEmpty ||
              person.name.toLowerCase().contains(_query.toLowerCase()) ||
              person.handle.contains(_query.toLowerCase()),
        )
        .toList();
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchField(
          placeholder: const Text('Name or @handle'),
          onChanged: (value) => setState(() => _query = value),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: matches.isEmpty
              ? const Empty(
                  icon: PhosphorIcon(PhosphorIconsRegular.userCircleDashed),
                  title: Text('No one by that name'),
                  description: Text('Try their @handle or their phone number.'),
                )
              : SingleChildScrollView(
                  child: ListSection(
                    margin: EdgeInsets.zero,
                    children: [
                      for (final person in matches)
                        ListTile(
                          leading: PersonAvatar(person),
                          title: Text(person.name),
                          subtitle: Text(person.handle),
                          showChevron: true,
                          onTap: () => setState(() {
                            _person = person;
                            _step = _SendStep.amount;
                          }),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _amountStep(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    final person = _person!;
    return ListenableBuilder(
      listenable: _amount,
      builder: (context, _) {
        final value = _amount.value;
        final over = value > session.balanceOf(_currency);
        return UnaColumn(
          gap: GapSize.md,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                PersonAvatar(person, size: 36),
                const Gap.sm(),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: theme.textTheme.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.foreground,
                        ),
                      ),
                      Text(person.handle, style: theme.textTheme.caption),
                    ],
                  ),
                ),
                _currencySelect(
                  session,
                  _currency,
                  (currency) => setState(() => _currency = currency),
                ),
              ],
            ),
            AmountEntry(
              input: _amount,
              currency: _currency,
              error: over ? 'More than your ${_currency.code} balance' : null,
              caption: Text(
                'Balance ${money(session.balanceOf(_currency), _currency)}',
              ),
            ),
            TextField(
              controller: _note,
              placeholder: const Text('Add a note (optional)'),
              maxLength: 60,
            ),
            Button(
              onPressed: value > 0 && !over
                  ? () => setState(() => _step = _SendStep.review)
                  : null,
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  Widget _review(BuildContext context) {
    final theme = Theme.of(context);
    final person = _person!;
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: PersonAvatar(person, size: 64)),
        Column(
          children: [
            Text(
              money(_amount.value, _currency),
              style: theme.textTheme.h2.tabular,
            ),
            Text('to ${person.name}', style: theme.textTheme.muted),
          ],
        ),
        Card(
          child: Column(
            children: [
              _SummaryRow('From', Text('${_currency.code} account')),
              const _SummaryRow('Fee', Text('Free')),
              const _SummaryRow('Arrives', Text('Instantly')),
              if (_note.text.trim().isNotEmpty)
                _SummaryRow('Note', Text('“${_note.text.trim()}”')),
            ],
          ),
        ),
        UnaRow(
          gap: GapSize.sm,
          children: [
            Expanded(
              child: Button.outline(
                onPressed: _sending
                    ? null
                    : () => setState(() => _step = _SendStep.amount),
                child: const ButtonLabel('Back'),
              ),
            ),
            Expanded(
              flex: 2,
              child: Button(
                loading: _sending,
                onPressed: _send,
                leading: const PhosphorIcon(PhosphorIconsBold.paperPlaneTilt),
                child: ButtonLabel('Send ${money(_amount.value, _currency)}'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- request

/// Asks a person for money.
Future<void> showRequestFlow(BuildContext context, {Person? from}) => showFlow(
  context,
  title: 'Request money',
  builder: (context) => _RequestFlow(from: from),
);

class _RequestFlow extends StatefulWidget {
  const _RequestFlow({this.from});

  final Person? from;

  @override
  State<_RequestFlow> createState() => _RequestFlowState();
}

class _RequestFlowState extends State<_RequestFlow> {
  late Person _person = widget.from ?? People.maya;
  final _amount = AmountInput();
  final _note = TextEditingController();
  var _done = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return FlowSuccess(
        title: 'Request sent',
        message:
            '${_person.firstName} will be asked for ${money(_amount.value, Currency.eur)}. '
            'You will hear when they pay.',
      );
    }
    return ListenableBuilder(
      listenable: _amount,
      builder: (context, _) => UnaColumn(
        gap: GapSize.md,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: People.contacts.length,
              separatorBuilder: (context, index) => const Gap.sm(),
              itemBuilder: (context, index) {
                final person = People.contacts[index];
                return _PersonChoice(
                  person: person,
                  selected: person == _person,
                  onPressed: () => setState(() => _person = person),
                );
              },
            ),
          ),
          AmountEntry(
            input: _amount,
            currency: Currency.eur,
            caption: Text('From ${_person.name}'),
          ),
          TextField(
            controller: _note,
            placeholder: const Text('What is it for?'),
            maxLength: 60,
          ),
          Button(
            onPressed: _amount.value > 0
                ? () {
                    context.bank.request(
                      _person,
                      _amount.value,
                      note: _note.text,
                    );
                    setState(() => _done = true);
                  }
                : null,
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }
}

/// A portrait with a first name under it, ringed while chosen.
class _PersonChoice extends StatelessWidget {
  const _PersonChoice({
    required this.person,
    required this.selected,
    required this.onPressed,
  });

  final Person person;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Pressable(
      onPressed: onPressed,
      selected: selected,
      semanticLabel: person.name,
      builder: (context, states) => SizedBox(
        width: 60,
        child: Column(
          children: [
            AnimatedContainer(
              duration: Motion.of(context).fast,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.tint : const Color(0x00000000),
                  width: 2,
                ),
              ),
              child: PersonAvatar(person, size: 44),
            ),
            const Gap.xs(),
            Text(
              person.firstName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.caption.copyWith(
                color: selected ? scheme.foreground : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- exchange

/// Exchanges between two accounts at today's rate, over its chart.
Future<void> showExchangeFlow(
  BuildContext context, {
  Currency from = Currency.eur,
  Currency to = Currency.usd,
}) => showFlow(
  context,
  title: 'Exchange',
  maxWidth: 520,
  builder: (context) => ExchangePanel(from: from, to: to),
);

/// Two accounts, an amount, the rate and its chart: the exchange flow's
/// content, also a card on the Payments page of a desktop.
class ExchangePanel extends StatefulWidget {
  const ExchangePanel({
    this.from = Currency.eur,
    this.to = Currency.usd,
    this.inFlow = true,
    super.key,
  });

  final Currency from;
  final Currency to;

  /// Whether the panel is a flow of its own, which closes when done.
  final bool inFlow;

  @override
  State<ExchangePanel> createState() => _ExchangePanelState();
}

enum _Span {
  week('1W', 7),
  month('1M', 30),
  quarter('3M', 90);

  const _Span(this.label, this.days);

  final String label;
  final int days;
}

class _ExchangePanelState extends State<ExchangePanel> {
  late var _from = widget.from;
  late var _to = widget.to;
  final _amount = TextEditingController();
  var _span = _Span.month;
  var _turns = 0.0;
  var _working = false;
  double? _received;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double get _value => double.tryParse(_amount.text) ?? 0;

  void _swap() {
    setState(() {
      final from = _from;
      _from = _to;
      _to = from;
      _turns += .5;
    });
    Haptics.selection(context);
  }

  Future<void> _exchange() async {
    setState(() => _working = true);
    await Future<void>.delayed(_pause);
    if (!mounted) return;
    final received = context.bank.exchange(_from, _to, _value);
    Haptics.impact(context, HapticImpact.medium);
    setState(() {
      _working = false;
      _received = received;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    if (_received case final received?) {
      return FlowSuccess(
        title: 'Exchanged',
        message:
            '${money(_value, _from)} became ${money(received, _to)} at '
            '1 ${_from.code} = ${rate(_from, _to).toStringAsFixed(4)} ${_to.code}.',
        onDone: widget.inFlow
            ? null
            : () => setState(() {
                _received = null;
                _amount.clear();
              }),
      );
    }
    final value = _value;
    final over = value > session.balanceOf(_from);
    final history = rateHistory(_from, _to, days: _span.days);
    final change = (history.last - history.first) / history.first * 100;
    final labels = [
      for (var i = 0; i < history.length; i++)
        DateFormat.MMMd().format(
          today.subtract(Duration(days: history.length - 1 - i)),
        ),
    ];
    Widget side({
      required String label,
      required Currency currency,
      required ValueChanged<Currency> onChanged,
      required Widget amount,
      required String caption,
    }) => Card(
      style: const CardTheme(padding: EdgeInsets.all(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: theme.textTheme.caption),
              const Spacer(),
              Text(caption, style: theme.textTheme.caption.tabular),
            ],
          ),
          const Gap.sm(),
          Row(
            children: [
              _currencySelect(
                session,
                currency,
                onChanged,
                only: [
                  for (final c in session.accounts)
                    if (c != (label == 'From' ? _to : _from)) c,
                ],
              ),
              const Gap.md(),
              Expanded(child: amount),
            ],
          ),
        ],
      ),
    );
    final big = theme.textTheme.h3
        .copyWith(fontWeight: FontWeight.w600)
        .tabular;
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Column(
              children: [
                side(
                  label: 'From',
                  currency: _from,
                  onChanged: (currency) => setState(() => _from = currency),
                  caption: 'Balance ${money(session.balanceOf(_from), _from)}',
                  amount: TextField(
                    controller: _amount,
                    placeholder: Text(
                      '0${_from.decimals > 0 ? '.00' : ''}',
                      style: big,
                    ),
                    style: big,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(
                          _from.decimals > 0
                              ? r'^\d{0,7}\.?\d{0,2}'
                              : r'^\d{0,9}',
                        ),
                      ),
                    ],
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const Gap.xs(),
                side(
                  label: 'To',
                  currency: _to,
                  onChanged: (currency) => setState(() => _to = currency),
                  caption: 'Balance ${money(session.balanceOf(_to), _to)}',
                  amount: Text(
                    money(value * rate(_from, _to), _to),
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: big.copyWith(
                      color: value == 0 ? scheme.mutedForeground : null,
                    ),
                  ),
                ),
              ],
            ),
            SpringBuilder(
              value: _turns,
              builder: (context, turns, child) => Transform.rotate(
                angle: turns * 6.283185307179586,
                child: child,
              ),
              child: IconButton.outline(
                icon: const PhosphorIcon(PhosphorIconsBold.arrowsDownUp),
                semanticLabel: 'Swap currencies',
                onPressed: _swap,
                style: ButtonTheme(
                  backgroundColor: scheme.card,
                  decoration: UnaDecoration(
                    border: UnaBorder.all(
                      borderRadius: theme.radii.full,
                      color: scheme.border,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            PhosphorIcon(
              PhosphorIconsRegular.trendUp,
              size: 16,
              color: scheme.mutedForeground,
            ),
            const Gap.xs(),
            Expanded(
              child: Text(
                '1 ${_from.code} = ${rate(_from, _to).toStringAsFixed(_to == Currency.jpy ? 2 : 4)} ${_to.code}',
                style: theme.textTheme.small
                    .copyWith(
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                    )
                    .tabular,
              ),
            ),
            Badge(
              variant: change >= 0
                  ? BadgeVariant.secondary
                  : BadgeVariant.outline,
              child: Text(
                '${change >= 0 ? '+' : '−'}${change.abs().toStringAsFixed(2)}%',
                style: const TextStyle(fontFeatures: tabularFigures),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 150,
          child: LineChart(
            labels: labels,
            series: [
              ChartSeries(
                label: '${_from.code}/${_to.code}',
                values: history,
                color: scheme.tint,
              ),
            ],
            area: true,
            // The rate moves by a percent or two: an axis from zero would
            // flatten it into a line.
            minValue: history.reduce(math.min) * .998,
            maxValue: history.reduce(math.max) * 1.002,
            showGrid: false,
            showYAxis: false,
            showXAxis: false,
            valueFormatter: (value) =>
                value.toStringAsFixed(_to == Currency.jpy ? 2 : 4),
            semanticLabel: '${_from.code} to ${_to.code} over ${_span.label}',
          ),
        ),
        Center(
          child: SegmentedControl<_Span>(
            value: _span,
            size: ControlSize.sm,
            onChanged: (span) => setState(() => _span = span),
            segments: [
              for (final span in _Span.values)
                Segment(value: span, label: Text(span.label)),
            ],
          ),
        ),
        Button(
          loading: _working,
          onPressed: value > 0 && !over ? _exchange : null,
          child: Text(
            over
                ? 'More than your ${_from.code} balance'
                : value > 0
                ? 'Exchange ${money(value, _from)}'
                : 'Enter an amount',
          ),
        ),
        Text(
          'No fee up to €1,000 a month on weekdays. Rates are mid-market.',
          textAlign: TextAlign.center,
          style: theme.textTheme.caption,
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- add money

/// Adds money to an account from the linked bank.
Future<void> showAddMoneyFlow(
  BuildContext context, {
  Currency currency = Currency.eur,
}) => showFlow(
  context,
  title: 'Add money',
  builder: (context) => _AddMoneyFlow(currency: currency),
);

class _AddMoneyFlow extends StatefulWidget {
  const _AddMoneyFlow({required this.currency});

  final Currency currency;

  @override
  State<_AddMoneyFlow> createState() => _AddMoneyFlowState();
}

class _AddMoneyFlowState extends State<_AddMoneyFlow> {
  late var _currency = widget.currency;
  final _amount = AmountInput();
  var _working = false;
  var _done = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    setState(() => _working = true);
    await Future<void>.delayed(_pause);
    if (!mounted) return;
    context.bank.addMoney(_currency, _amount.value);
    Haptics.impact(context, HapticImpact.medium);
    setState(() {
      _working = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    if (_done) {
      return FlowSuccess(
        title: '${money(_amount.value, _currency)} added',
        message:
            'Your ${_currency.code} balance is now '
            '${money(session.balanceOf(_currency), _currency)}.',
      );
    }
    return ListenableBuilder(
      listenable: _amount,
      builder: (context, _) => UnaColumn(
        gap: GapSize.md,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'To your ${_currency.label.toLowerCase()} account',
                  style: theme.textTheme.muted,
                ),
              ),
              _currencySelect(
                session,
                _currency,
                (currency) => setState(() => _currency = currency),
              ),
            ],
          ),
          AmountEntry(
            input: _amount,
            currency: _currency,
            caption: Text(
              'Balance ${money(session.balanceOf(_currency), _currency)}',
            ),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final preset in [50, 100, 250, 500])
                Chip(
                  label: Text(money(preset.toDouble(), _currency, decimals: 0)),
                  onPressed: () => _amount.text = '$preset',
                ),
            ],
          ),
          ListSection(
            margin: EdgeInsets.zero,
            children: [
              ListTile(
                leading: const IconTile(
                  icon: PhosphorIcon(PhosphorIconsRegular.bank),
                ),
                title: const Text('Northbank •• 2210'),
                subtitle: const Text('Linked account · Instant'),
                trailing: Badge.secondary(child: const Text('Free')),
              ),
            ],
          ),
          Button(
            loading: _working,
            onPressed: _amount.value > 0 ? _add : null,
            child: Text(
              _amount.value > 0
                  ? 'Add ${money(_amount.value, _currency)}'
                  : 'Enter an amount',
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- vault

/// Moves money into a vault, or out of it.
Future<void> showVaultMoneyFlow(
  BuildContext context,
  Vault vault, {
  bool withdraw = false,
}) => showFlow(
  context,
  title: withdraw ? 'Take out of ${vault.name}' : 'Add to ${vault.name}',
  builder: (context) => _VaultMoneyFlow(vault: vault, withdraw: withdraw),
);

class _VaultMoneyFlow extends StatefulWidget {
  const _VaultMoneyFlow({required this.vault, required this.withdraw});

  final Vault vault;
  final bool withdraw;

  @override
  State<_VaultMoneyFlow> createState() => _VaultMoneyFlowState();
}

class _VaultMoneyFlowState extends State<_VaultMoneyFlow> {
  final _amount = AmountInput();
  var _done = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final vault = widget.vault;
    if (_done) {
      return FlowSuccess(
        title: widget.withdraw
            ? '${money(_amount.value, Currency.eur)} taken out'
            : '${money(_amount.value, Currency.eur)} saved',
        message: vault.reached
            ? '${vault.name} has reached its goal. Well done!'
            : '${vault.name} is ${(vault.progress * 100).round()}% of the way there.',
        child: Center(
          child: ProgressRing(
            value: vault.progress,
            size: 64,
            child: Text(
              '${(vault.progress * 100).round()}%',
              style: Theme.of(context).textTheme.small.tabular,
            ),
          ),
        ),
      );
    }
    final available = widget.withdraw
        ? vault.saved
        : session.balanceOf(Currency.eur);
    return ListenableBuilder(
      listenable: _amount,
      builder: (context, _) {
        final over = _amount.value > available + 1e-9;
        return UnaColumn(
          gap: GapSize.md,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AmountEntry(
              input: _amount,
              currency: Currency.eur,
              error: over
                  ? widget.withdraw
                        ? 'More than the vault holds'
                        : 'More than your EUR balance'
                  : null,
              caption: Text(
                widget.withdraw
                    ? 'In the vault ${money(vault.saved, Currency.eur)}'
                    : 'From EUR · Balance ${money(available, Currency.eur)}',
              ),
            ),
            Button(
              onPressed: _amount.value > 0 && !over
                  ? () {
                      if (widget.withdraw) {
                        session.withdrawFromVault(vault, _amount.value);
                      } else {
                        session.addToVault(vault, _amount.value);
                      }
                      Haptics.impact(context, HapticImpact.medium);
                      setState(() => _done = true);
                    }
                  : null,
              child: Text(widget.withdraw ? 'Take out' : 'Add to vault'),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ card

/// Orders a card: what kind, which design, its name.
Future<void> showOrderCardFlow(BuildContext context) => showFlow(
  context,
  title: 'New card',
  maxWidth: 520,
  builder: (context) => const _OrderCardFlow(),
);

class _OrderCardFlow extends StatefulWidget {
  const _OrderCardFlow();

  @override
  State<_OrderCardFlow> createState() => _OrderCardFlowState();
}

class _OrderCardFlowState extends State<_OrderCardFlow> {
  var _kind = CardKind.virtual;
  var _design = CardDesign.aurora;
  final _name = TextEditingController(text: 'Subscriptions');
  BankCard? _ordered;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  BankCard get _preview => BankCard(
    id: 'preview',
    name: _name.text,
    kind: _kind,
    design: _design,
    number: '4000 0000 0000 0000',
    expiry:
        '${today.month.toString().padLeft(2, '0')}/${(today.year + 4) % 100}',
    cvv: '000',
    limit: 0,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_ordered case final card?) {
      return FlowSuccess(
        title: card.kind == CardKind.physical
            ? 'Your card is on its way'
            : 'Your card is ready',
        message: card.kind == CardKind.physical
            ? 'It will arrive in 3–5 working days. Its virtual twin works today.'
            : 'Use it online right away; it is in your wallet too.',
        onDone: () {
          selectedCardProvider.of(context).value = card.id;
          Navigator.of(context).pop();
          context.leaveTo(Destination.cards);
        },
        child: Center(
          child: SizedBox(width: 240, child: BankCardView(card)),
        ),
      );
    }
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: BankCardView(_preview),
          ),
        ),
        SegmentedControl<CardKind>(
          value: _kind,
          expand: true,
          onChanged: (kind) => setState(() {
            _kind = kind;
            _design = switch (kind) {
              CardKind.physical => CardDesign.coral,
              CardKind.virtual => CardDesign.aurora,
              CardKind.disposable => CardDesign.prism,
            };
          }),
          segments: [
            for (final kind in CardKind.values)
              Segment(value: kind, label: Text(kind.label)),
          ],
        ),
        Text(
          switch (_kind) {
            CardKind.physical => 'A card in your wallet, contactless and for cash. €4.99 delivery.',
            CardKind.virtual =>
              'A card for shopping online, ready the moment you make it. Free.',
            CardKind.disposable => 'A new number after every payment, for shops you do not know. Free.',
          },
          style: theme.textTheme.muted,
        ),
        Text(
          'Design',
          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
        ),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: CardDesign.values.length,
            separatorBuilder: (context, index) => const Gap.sm(),
            itemBuilder: (context, index) {
              final design = CardDesign.values[index];
              final selected = design == _design;
              return Pressable(
                onPressed: () => setState(() => _design = design),
                selected: selected,
                semanticLabel: '${design.label} design',
                builder: (context, states) => Container(
                  width: 96,
                  padding: const EdgeInsets.all(2),
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected
                            ? theme.colorScheme.tint
                            : const Color(0x00000000),
                        width: 2,
                      ),
                    ),
                  ),
                  child: BankCardView(
                    BankCard(
                      id: design.name,
                      name: '',
                      kind: _kind,
                      design: design,
                      number:
                          '0000 0000 0000 ${design.label.length}${design.index}10',
                      expiry: '',
                      cvv: '',
                      limit: 0,
                    ),
                    compact: true,
                  ),
                ),
              );
            },
          ),
        ),
        TextField(
          controller: _name,
          placeholder: const Text('Card name'),
          maxLength: 24,
          onChanged: (_) => setState(() {}),
        ),
        Button(
          onPressed: _name.text.trim().isEmpty
              ? null
              : () {
                  final card = context.bank.orderCard(
                    _kind,
                    _design,
                    _name.text.trim(),
                  );
                  Haptics.impact(context, HapticImpact.medium);
                  setState(() => _ordered = card);
                },
          child: Text(
            _kind == CardKind.physical ? 'Order card' : 'Create card',
          ),
        ),
      ],
    );
  }
}

/// Sets a new PIN: four digits, twice.
Future<void> showChangePinFlow(BuildContext context, BankCard card) => showFlow(
  context,
  title: 'Change PIN',
  description: '${card.name} ${card.masked}',
  builder: (context) => const _PinFlow(),
);

class _PinFlow extends StatefulWidget {
  const _PinFlow();

  @override
  State<_PinFlow> createState() => _PinFlowState();
}

class _PinFlowState extends State<_PinFlow> {
  String? _first;
  var _mismatch = false;
  var _done = false;
  var _attempt = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_done) {
      return const FlowSuccess(
        title: 'PIN changed',
        message: 'Use it from your next payment. The old one no longer works.',
      );
    }
    final confirming = _first != null;
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          confirming ? 'Type it again' : 'Choose four digits',
          textAlign: TextAlign.center,
          style: theme.textTheme.large,
        ),
        Center(
          child: OtpField(
            key: ValueKey(_attempt),
            maxLength: 4,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onCompleted: (value) {
              if (!confirming) {
                setState(() {
                  _first = value;
                  _attempt++;
                  _mismatch = false;
                });
              } else if (value == _first) {
                Haptics.impact(context, HapticImpact.medium);
                setState(() => _done = true);
              } else {
                setState(() {
                  _first = null;
                  _attempt++;
                  _mismatch = true;
                });
              }
            },
            children: const [
              OtpFieldGroup(
                children: [
                  OtpFieldSlot(),
                  OtpFieldSlot(),
                  OtpFieldSlot(),
                  OtpFieldSlot(),
                ],
              ),
            ],
          ),
        ),
        Text(
          _mismatch
              ? 'Those did not match. Start again.'
              : 'Avoid 1234, your birthday, and the same digit four times.',
          textAlign: TextAlign.center,
          style: theme.textTheme.caption.copyWith(
            color: _mismatch ? theme.colorScheme.destructive : null,
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- transaction

/// A statement line in full: where, when, how, and what to do about it.
Future<void> showTxnDetail(BuildContext context, Txn txn) {
  final theme = Theme.of(context);
  if (theme.formFactor == FormFactor.mobile) {
    return showSheet<void>(
      context: context,
      builder: (context) => Sheet(
        detents: const [SheetDetent.content, SheetDetent.large],
        child: _TxnDetail(txnId: txn.id),
      ),
    );
  }
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      showCloseButton: true,
      style: const DialogTheme(constraints: BoxConstraints(maxWidth: 480)),
      child: _TxnDetail(txnId: txn.id),
    ),
  );
}

class _TxnDetail extends StatelessWidget {
  const _TxnDetail({required this.txnId});

  final String txnId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final txn = session.txn(txnId);
        if (txn == null) return const SizedBox.shrink();
        final card = session.maybeCard(txn.cardId);
        return UnaColumn(
          gap: GapSize.md,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                TxnAvatar(txn, size: 64),
                const Gap.sm(),
                Text(
                  txn.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.large.copyWith(
                    color: scheme.foreground,
                  ),
                ),
                const Gap.xs(),
                AmountText(
                  txn.amount,
                  txn.currency,
                  sign: true,
                  colorIncoming: true,
                  strike: txn.status == TxnStatus.declined,
                  style: theme.textTheme.h2.copyWith(color: scheme.foreground),
                ),
                if (txn.currency != Currency.eur && txn.kind == TxnKind.card)
                  Text(
                    '≈ ${money(txn.inEuros, Currency.eur)} at ${rate(txn.currency, Currency.eur).toStringAsFixed(4)}',
                    style: theme.textTheme.caption.tabular,
                  ),
                const Gap.xs(),
                Text(
                  DateFormat('EEEE d MMMM, HH:mm').format(txn.date),
                  style: theme.textTheme.muted,
                ),
                if (txn.status != TxnStatus.completed) ...[
                  const Gap.sm(),
                  Badge(
                    variant: txn.status == TxnStatus.declined
                        ? BadgeVariant.destructive
                        : BadgeVariant.secondary,
                    child: Text(
                      txn.status == TxnStatus.declined
                          ? 'Declined · card frozen at the time'
                          : txn.status.label,
                    ),
                  ),
                ],
              ],
            ),
            if (txn.kind == TxnKind.card && txn.merchant != null)
              MapPreview(
                seed: txn.merchant!.name.hashCode,
                label: txn.merchant!.place,
              ),
            if (txn.note != null)
              Card(
                style: const CardTheme(padding: EdgeInsets.all(14)),
                child: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIconsRegular.chatCircleText,
                      size: 18,
                      color: scheme.mutedForeground,
                    ),
                    const Gap.sm(),
                    Expanded(child: Text('“${txn.note}”')),
                  ],
                ),
              ),
            ListSection(
              margin: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: IconTile(icon: PhosphorIcon(txn.category.icon)),
                  title: const Text('Category'),
                  trailing: Select<TxnCategory>(
                    value: txn.category,
                    onChanged: (category) {
                      if (category != null) {
                        session.setCategory(txn, category);
                      }
                    },
                    options: [
                      for (final category in TxnCategory.values)
                        SelectOption(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                    selectedOptionBuilder: (context, category) =>
                        Text(category.label),
                  ),
                ),
                if (card != null)
                  ListTile(
                    leading: SizedBox(
                      width: 40,
                      child: BankCardView(card, compact: true),
                    ),
                    title: Text(card.name),
                    subtitle: Text(card.masked),
                  ),
                ListTile(
                  leading: const IconTile(
                    icon: PhosphorIcon(PhosphorIconsRegular.hash),
                  ),
                  title: const Text('Reference'),
                  value: Text(
                    'UNA${txn.id.toUpperCase().padLeft(6, '0')}',
                    style: theme.textTheme.small.tabular,
                  ),
                ),
              ],
            ),
            if (txn.amount < 0 && txn.kind == TxnKind.card)
              UnaRow(
                gap: GapSize.sm,
                children: [
                  Expanded(
                    child: Button.secondary(
                      leading: const PhosphorIcon(
                        PhosphorIconsRegular.usersThree,
                      ),
                      onPressed: () => showSplitFlow(context, txn),
                      child: const ButtonLabel('Split bill'),
                    ),
                  ),
                  Expanded(
                    child: Button.outline(
                      leading: const PhosphorIcon(PhosphorIconsRegular.receipt),
                      onPressed: () => showDemoToast(
                        context,
                        'Receipt added',
                        description: 'A photo of it is kept with the payment.',
                      ),
                      child: const ButtonLabel('Add receipt'),
                    ),
                  ),
                ],
              ),
            Button.ghost(
              leading: const PhosphorIcon(PhosphorIconsRegular.question),
              onPressed: () => showDemoToast(
                context,
                'We are on it',
                description: 'A specialist will look at this payment and reply in the app.',
              ),
              child: const ButtonLabel('Something wrong with this payment?'),
            ),
          ],
        );
      },
    );
  }
}

/// Splits a payment evenly with friends: each is asked for a share.
Future<void> showSplitFlow(BuildContext context, Txn txn) => showFlow(
  context,
  title: 'Split ${txn.title}',
  description: money(txn.amount.abs(), txn.currency),
  builder: (context) => _SplitFlow(txn: txn),
);

class _SplitFlow extends StatefulWidget {
  const _SplitFlow({required this.txn});

  final Txn txn;

  @override
  State<_SplitFlow> createState() => _SplitFlowState();
}

class _SplitFlowState extends State<_SplitFlow> {
  final _chosen = <Person>{People.maya};
  double? _share;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = -widget.txn.inEuros;
    if (_share case final share?) {
      return FlowSuccess(
        title:
            'Split with ${_chosen.length} ${_chosen.length == 1 ? 'friend' : 'friends'}',
        message:
            'Each is asked for ${money(share, Currency.eur)}. Payments land in your EUR account.',
        child: Center(
          child: AvatarGroup(
            size: 36,
            children: [for (final person in _chosen) Image.asset(person.photo)],
          ),
        ),
      );
    }
    final share = total / (_chosen.length + 1);
    return UnaColumn(
      gap: GapSize.md,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SingleChildScrollView(
            child: ListSection(
              margin: EdgeInsets.zero,
              children: [
                for (final person in People.contacts.take(6))
                  CheckboxListTile(
                    secondary: PersonAvatar(person, size: 36),
                    title: Text(person.name),
                    value: _chosen.contains(person),
                    onChanged: (value) => setState(() {
                      (value ?? false)
                          ? _chosen.add(person)
                          : _chosen.remove(person);
                    }),
                  ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                'You and ${_chosen.length} ${_chosen.length == 1 ? 'other' : 'others'}',
                style: theme.textTheme.muted,
              ),
            ),
            Text(
              '${money(share, Currency.eur)} each',
              style: theme.textTheme.large.tabular,
            ),
          ],
        ),
        Button(
          onPressed: _chosen.isEmpty
              ? null
              : () => setState(
                  () => _share = context.bank.split(
                    widget.txn,
                    _chosen.toList(),
                  ),
                ),
          child: const Text('Send requests'),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- accounts

/// Opens an account in another currency.
Future<void> showOpenAccountFlow(BuildContext context) => showFlow(
  context,
  title: 'Open an account',
  description: 'Hold, spend and receive in another currency.',
  builder: (context) {
    final session = context.bank;
    final missing = [
      for (final currency in Currency.values)
        if (!session.balances.containsKey(currency)) currency,
    ];
    return ListSection(
      margin: EdgeInsets.zero,
      children: [
        for (final currency in missing)
          ListTile(
            leading: CurrencyBadge(currency),
            title: Text(currency.label),
            subtitle: Text(currency.code),
            showChevron: true,
            onTap: () {
              session.openAccount(currency);
              Navigator.of(context).pop();
              showBankToast(
                context,
                '${currency.code} account opened',
                description: 'Add money or exchange into it from Home.',
                variant: ToastVariant.success,
              );
            },
          ),
        if (missing.isEmpty)
          const ListTile(title: Text('You hold every currency we offer')),
      ],
    );
  },
);

/// The rest of the quick actions under a balance.
Future<void> showMoreActions(BuildContext context) async {
  final choice = await showActionSheet<String>(
    context: context,
    title: const Text('More'),
    actions: const [
      ActionSheetAction(
        label: Text('Request money'),
        icon: PhosphorIcon(PhosphorIconsRegular.handCoins),
        value: 'request',
      ),
      ActionSheetAction(
        label: Text('Open an account'),
        icon: PhosphorIcon(PhosphorIconsRegular.plusCircle),
        value: 'account',
      ),
      ActionSheetAction(
        label: Text('New card'),
        icon: PhosphorIcon(PhosphorIconsRegular.creditCard),
        value: 'card',
      ),
      ActionSheetAction(
        label: Text('Statements'),
        icon: PhosphorIcon(PhosphorIconsRegular.fileText),
        value: 'statement',
      ),
    ],
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'request':
      unawaited(showRequestFlow(context));
    case 'account':
      unawaited(showOpenAccountFlow(context));
    case 'card':
      unawaited(showOrderCardFlow(context));
    case 'statement':
      showDemoToast(
        context,
        'Statement downloaded',
        description: 'Last month’s statement, as a PDF.',
      );
  }
}
