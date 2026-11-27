import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/bank_card.dart';
import 'package:una_banking/widgets/flows.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Cards: each card as it looks, and everything you can do to it — freeze
/// it, see its number, set its limit and what it may be used for.
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  /// The card whose number is shown in full, if any.
  String? _revealed;

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return SignalBuilder(
      builder: (context, _) {
        final selected = selectedCardProvider.of(context);
        // Read here, in the builder's own body, where the signal is
        // tracked.
        final selectedId = selected.value;
        return ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final card = session.maybeCard(selectedId) ?? session.cards.first;
            final revealed = _revealed == card.id;
            void reveal() =>
                setState(() => _revealed = revealed ? null : card.id);
            return PageContainer(
              scrollable: true,
              maxWidth: 1200,
              child: FormFactorBuilder(
                mobile: (context) => UnaColumn(
                  gap: GapSize.lg,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CardCarousel(
                      cards: session.cards,
                      selected: card,
                      revealed: revealed,
                      onSelected: (card) => selected.value = card.id,
                    ),
                    _CardActions(
                      card: card,
                      revealed: revealed,
                      onReveal: reveal,
                    ),
                    _SpendingLimit(card: card),
                    _CardDetails(
                      card: card,
                      revealed: revealed,
                      onReveal: reveal,
                    ),
                    _Security(card: card),
                    _CardTransactions(card: card),
                    Button.outline(
                      leading: const PhosphorIcon(PhosphorIconsRegular.plus),
                      onPressed: () => showOrderCardFlow(context),
                      child: const Text('New card'),
                    ),
                  ],
                ),
                desktop: (context) => UnaColumn(
                  gap: GapSize.lg,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PageHeader(
                      title: 'Cards',
                      subtitle:
                          '${session.cards.length} cards, one account behind them all',
                      actions: [
                        Button(
                          leading: const PhosphorIcon(PhosphorIconsBold.plus),
                          onPressed: () => showOrderCardFlow(context),
                          child: const Text('New card'),
                        ),
                      ],
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = Theme.of(
                          context,
                        ).layoutTheme.gap(GapSize.xl);
                        final left = UnaColumn(
                          gap: GapSize.lg,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: BankCardView(card, revealed: revealed),
                            ),
                            _CardPicker(
                              cards: session.cards,
                              selected: card,
                              onSelected: (card) => selected.value = card.id,
                            ),
                            _CardActions(
                              card: card,
                              revealed: revealed,
                              onReveal: reveal,
                            ),
                            _SpendingLimit(card: card),
                          ],
                        );
                        final right = UnaColumn(
                          gap: GapSize.lg,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _CardDetails(
                              card: card,
                              revealed: revealed,
                              onReveal: reveal,
                            ),
                            _Security(card: card),
                            _CardTransactions(card: card),
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
                            Expanded(flex: 5, child: left),
                            SizedBox(width: gap),
                            Expanded(flex: 6, child: right),
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
      },
    );
  }
}

/// A phone's cards, swiped through.
class _CardCarousel extends StatefulWidget {
  const _CardCarousel({
    required this.cards,
    required this.selected,
    required this.revealed,
    required this.onSelected,
  });

  final List<BankCard> cards;
  final BankCard selected;
  final bool revealed;
  final ValueChanged<BankCard> onSelected;

  @override
  State<_CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<_CardCarousel> {
  final _controller = CarouselController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final index = widget.cards.indexOf(widget.selected);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * .86;
        return Column(
          children: [
            Carousel(
              controller: _controller,
              initialPage: index,
              viewportFraction: .86,
              spacing: 12,
              height: width / BankCardView.aspectRatio + 24,
              onPageChanged: (page) => widget.onSelected(widget.cards[page]),
              semanticLabel: 'Your cards',
              children: [
                for (final card in widget.cards)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: BankCardView(
                        card,
                        revealed: widget.revealed && card == widget.selected,
                      ),
                    ),
                  ),
              ],
            ),
            const Gap.xs(),
            PageIndicator(
              count: widget.cards.length,
              index: index,
              onSelected: _controller.animateToPage,
              semanticLabel: 'Card',
            ),
          ],
        );
      },
    );
  }
}

/// A desktop's row of small cards to pick from.
class _CardPicker extends StatelessWidget {
  const _CardPicker({
    required this.cards,
    required this.selected,
    required this.onSelected,
  });

  final List<BankCard> cards;
  final BankCard selected;
  final ValueChanged<BankCard> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final card in cards)
          Pressable(
            onPressed: () => onSelected(card),
            selected: card == selected,
            semanticLabel: '${card.name} ${card.masked}',
            builder: (context, states) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: Motion.of(context).fast,
                  width: 96,
                  padding: const EdgeInsets.all(2),
                  decoration: ShapeDecoration(
                    shape: RoundedSuperellipseBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: card == selected
                            ? theme.colorScheme.tint
                            : const Color(0x00000000),
                        width: 2,
                      ),
                    ),
                  ),
                  child: BankCardView(card, compact: true),
                ),
                const Gap.xs(),
                SizedBox(
                  width: 96,
                  child: Text(
                    card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.caption.copyWith(
                      color: card == selected
                          ? theme.colorScheme.foreground
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Freeze, show the number, change the PIN, and the card's own menu.
class _CardActions extends StatelessWidget {
  const _CardActions({
    required this.card,
    required this.revealed,
    required this.onReveal,
  });

  final BankCard card;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return Row(
      children: [
        Expanded(
          child: RoundAction(
            icon: card.frozen
                ? PhosphorIconsBold.sun
                : PhosphorIconsBold.snowflake,
            label: card.frozen ? 'Unfreeze' : 'Freeze',
            onPressed: () {
              Haptics.impact(context, HapticImpact.medium);
              session.setFrozen(card, !card.frozen);
              showBankToast(
                context,
                card.frozen ? 'Card frozen' : 'Card unfrozen',
                description: card.frozen
                    ? 'Payments with ${card.masked} will be declined.'
                    : '${card.masked} works again.',
                actionLabel: 'Undo',
                onAction: () => session.setFrozen(card, !card.frozen),
              );
            },
          ),
        ),
        Expanded(
          child: RoundAction(
            icon: revealed ? PhosphorIconsBold.eyeSlash : PhosphorIconsBold.eye,
            label: revealed ? 'Hide' : 'Details',
            onPressed: onReveal,
          ),
        ),
        Expanded(
          child: RoundAction(
            icon: PhosphorIconsBold.password,
            label: 'PIN',
            onPressed: () => card.kind == CardKind.physical
                ? showChangePinFlow(context, card)
                : showDemoToast(
                    context,
                    'No PIN on this card',
                    description:
                        'A ${card.kind.label.toLowerCase()} card pays online only.',
                  ),
          ),
        ),
        Expanded(
          child: card.kind == CardKind.disposable
              ? RoundAction(
                  icon: PhosphorIconsBold.arrowsCounterClockwise,
                  label: 'New number',
                  onPressed: () {
                    session.regenerate(card);
                    showBankToast(
                      context,
                      'New number',
                      description: 'The old one stops working now.',
                    );
                  },
                )
              : RoundAction(
                  icon: PhosphorIconsBold.wallet,
                  label: 'Add to wallet',
                  onPressed: () => showDemoToast(
                    context,
                    'Added to your wallet',
                    description: 'Pay with your phone or watch.',
                  ),
                ),
        ),
      ],
    );
  }
}

/// What the card has spent this month against its limit, and the limit.
class _SpendingLimit extends StatefulWidget {
  const _SpendingLimit({required this.card});

  final BankCard card;

  @override
  State<_SpendingLimit> createState() => _SpendingLimitState();
}

class _SpendingLimitState extends State<_SpendingLimit> {
  double? _dragging;

  @override
  void didUpdateWidget(covariant _SpendingLimit oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card != widget.card) _dragging = null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final card = widget.card;
    final limit = _dragging ?? card.limit;
    final share = (card.spent / limit).clamp(0, 1).toDouble();
    return Card(
      title: const Text('Monthly limit'),
      description: Text(
        card.frozen
            ? 'Frozen: every payment is declined'
            : '${money(limit - card.spent < 0 ? 0 : limit - card.spent, Currency.eur, decimals: 0)} left this month',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  AmountText(
                    card.spent,
                    Currency.eur,
                    style: theme.textTheme.large.copyWith(
                      color: scheme.foreground,
                    ),
                  ),
                  Text(' spent', style: theme.textTheme.muted),
                ],
              ),
              Text(
                'of ${money(limit, Currency.eur, decimals: 0)}',
                style: theme.textTheme.muted.tabular,
              ),
            ],
          ),
          const Gap.sm(),
          ProgressBar(
            value: share,
            color: share > .9 ? scheme.destructive : null,
            semanticLabel: 'Spent of the limit',
          ),
          const Gap.lg(),
          Slider(
            value: limit,
            min: 100,
            max: 10000,
            divisions: 99,
            showDivisionMarks: false,
            valueIndicator: SliderValueIndicator.whileDragging,
            valueLabel: (value) => money(value, Currency.eur, decimals: 0),
            semanticLabel: 'Monthly limit',
            onChanged: (value) => setState(() => _dragging = value),
            onChangeEnd: (value) {
              context.bank.setLimit(card, value);
              setState(() => _dragging = null);
            },
          ),
        ],
      ),
    );
  }
}

/// The number, the expiry and the CVV, to read or copy.
class _CardDetails extends StatelessWidget {
  const _CardDetails({
    required this.card,
    required this.revealed,
    required this.onReveal,
  });

  final BankCard card;
  final bool revealed;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    void copy(String label, String value) {
      Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
      showBankToast(context, '$label copied');
    }

    final mono = theme.textTheme.small
        .copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.foreground,
        )
        .tabular;
    return ListSection(
      margin: EdgeInsets.zero,
      header: Text('${card.name} · ${card.kind.label}'),
      headerTrailing: Button.link(
        onPressed: onReveal,
        child: Text(revealed ? 'Hide details' : 'Show details'),
      ),
      children: [
        if (card.arriving)
          ListTile(
            leading: const IconTile(
              icon: PhosphorIcon(PhosphorIconsRegular.truck),
            ),
            title: const Text('On its way'),
            subtitle: const Text('Arrives in 3–5 working days'),
            trailing: Badge.secondary(child: const Text('Ordered')),
          ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.creditCard),
          ),
          title: const Text('Card number'),
          subtitle: Text(
            revealed ? card.number : '•••• •••• •••• ${card.last4}',
            style: mono,
          ),
          trailing: IconButton.ghost(
            icon: const PhosphorIcon(PhosphorIconsRegular.copy),
            semanticLabel: 'Copy card number',
            onPressed: revealed
                ? () => copy('Card number', card.number)
                : onReveal,
          ),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.calendarBlank),
          ),
          title: const Text('Expires'),
          value: Text(card.expiry, style: mono),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.lockKey),
          ),
          title: const Text('Security code'),
          subtitle: Text(revealed ? card.cvv : '•••', style: mono),
          trailing: IconButton.ghost(
            icon: const PhosphorIcon(PhosphorIconsRegular.copy),
            semanticLabel: 'Copy security code',
            onPressed: revealed
                ? () => copy('Security code', card.cvv)
                : onReveal,
          ),
        ),
      ],
    );
  }
}

/// What the card may be used for.
class _Security extends StatelessWidget {
  const _Security({required this.card});

  final BankCard card;

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final physical = card.kind == CardKind.physical;
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Security'),
      children: [
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.globe),
          ),
          title: const Text('Online payments'),
          value: card.online,
          onChanged: (value) => session.update(() => card.online = value),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.contactlessPayment),
          ),
          title: const Text('Contactless'),
          subtitle: physical ? null : const Text('Only on a physical card'),
          value: card.contactless,
          enabled: physical,
          onChanged: (value) => session.update(() => card.contactless = value),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.money),
          ),
          title: const Text('Cash withdrawals'),
          subtitle: physical ? null : const Text('Only on a physical card'),
          value: card.atm,
          enabled: physical,
          onChanged: (value) => session.update(() => card.atm = value),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.airplaneTilt),
          ),
          title: const Text('Payments abroad'),
          value: card.abroad,
          onChanged: (value) => session.update(() => card.abroad = value),
        ),
      ],
    );
  }
}

/// The card's own lines of the statement.
class _CardTransactions extends StatelessWidget {
  const _CardTransactions({required this.card});

  final BankCard card;

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final lines = session.transactions
        .where((txn) => txn.cardId == card.id)
        .take(5)
        .toList();
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Recent on this card'),
      children: [
        if (lines.isEmpty)
          ListTile(
            leading: const IconTile(
              icon: PhosphorIcon(PhosphorIconsRegular.receipt),
            ),
            title: const Text('Nothing yet'),
            subtitle: Text(
              card.kind == CardKind.disposable
                  ? 'Its number changes after every payment'
                  : 'Payments with this card show here',
            ),
          ),
        for (final txn in lines)
          TxnTile(
            txn,
            showDate: true,
            onTap: () => showTxnDetail(context, txn),
          ),
      ],
    );
  }
}
