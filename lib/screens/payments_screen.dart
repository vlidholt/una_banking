import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/flows.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Payments: the people you pay, what you asked for, what repeats, and
/// exchange — beside it on a desktop, a flow of its own on a phone.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => PageContainer(
        scrollable: true,
        maxWidth: 1200,
        child: FormFactorBuilder(
          mobile: (context) => const UnaColumn(
            gap: GapSize.lg,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _QuickActions(),
              _Contacts(),
              _Requests(),
              _Scheduled(),
              _RecentTransfers(),
            ],
          ),
          desktop: (context) => UnaColumn(
            gap: GapSize.lg,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Payments',
                subtitle: 'Send, request and exchange, free between friends',
                actions: [
                  Button.outline(
                    leading: const PhosphorIcon(PhosphorIconsRegular.handCoins),
                    onPressed: () => showRequestFlow(context),
                    child: const Text('Request'),
                  ),
                  Button(
                    leading: const PhosphorIcon(
                      PhosphorIconsBold.paperPlaneTilt,
                    ),
                    onPressed: () => showSendFlow(context),
                    child: const Text('Send money'),
                  ),
                ],
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = Theme.of(context).layoutTheme.gap(GapSize.lg);
                  const left = UnaColumn(
                    gap: GapSize.lg,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Contacts(),
                      _Requests(),
                      _Scheduled(),
                    ],
                  );
                  const right = UnaColumn(
                    gap: GapSize.lg,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        title: Text('Exchange'),
                        description: Text(
                          'Between your accounts, at the mid-market rate',
                        ),
                        child: ExchangePanel(inFlow: false),
                      ),
                      _RecentTransfers(),
                    ],
                  );
                  if (constraints.maxWidth < 860) {
                    return const UnaColumn(
                      gap: GapSize.lg,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, right],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Expanded(flex: 6, child: left),
                      SizedBox(width: gap),
                      const Expanded(flex: 5, child: right),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RoundAction(
            icon: PhosphorIconsBold.paperPlaneTilt,
            label: 'Send',
            onPressed: () => showSendFlow(context),
          ),
        ),
        Expanded(
          child: RoundAction(
            icon: PhosphorIconsBold.handCoins,
            label: 'Request',
            onPressed: () => showRequestFlow(context),
          ),
        ),
        Expanded(
          child: RoundAction(
            icon: PhosphorIconsBold.arrowsClockwise,
            label: 'Exchange',
            onPressed: () => showExchangeFlow(context),
          ),
        ),
        Expanded(
          child: RoundAction(
            icon: PhosphorIconsBold.plus,
            label: 'Add money',
            onPressed: () => showAddMoneyFlow(context),
          ),
        ),
      ],
    );
  }
}

/// The people you pay, a tap from sending to them again.
class _Contacts extends StatelessWidget {
  const _Contacts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      title: const Text('Send again'),
      action: Button.link(
        onPressed: () => showSendFlow(context),
        child: const Text('Everyone'),
      ),
      child: SizedBox(
        height: 84,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: People.contacts.length,
          separatorBuilder: (context, index) => const Gap.md(),
          itemBuilder: (context, index) {
            final person = People.contacts[index];
            return Pressable(
              onPressed: () => showSendFlow(context, to: person),
              semanticLabel: 'Send to ${person.name}',
              builder: (context, states) => SizedBox(
                width: 60,
                child: Column(
                  children: [
                    FocusRing(
                      visible: states.contains(WidgetState.focused),
                      borderRadius: theme.radii.full,
                      child: AnimatedScale(
                        scale: states.contains(WidgetState.hovered) ? 1.06 : 1,
                        duration: Motion.of(context).fast,
                        child: PersonAvatar(person, size: 52),
                      ),
                    ),
                    const Gap.xs(),
                    Text(
                      person.firstName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.caption.copyWith(
                        color: theme.colorScheme.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Money you asked for and are waiting on.
class _Requests extends StatelessWidget {
  const _Requests();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    final open = session.requests.where((request) => !request.paid).toList();
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Waiting on'),
      headerTrailing: Button.link(
        onPressed: () => showRequestFlow(context),
        child: const Text('New request'),
      ),
      children: [
        if (open.isEmpty)
          const ListTile(
            leading: IconTile(
              icon: PhosphorIcon(PhosphorIconsRegular.checkCircle),
            ),
            title: Text('Nobody owes you anything'),
            subtitle: Text('Requests you send wait here until they are paid'),
          ),
        for (final request in open)
          ListTile(
            leading: PersonAvatar(request.person),
            title: Text(request.person.name),
            subtitle: Text('${request.note} · ${ago(request.date)}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AmountText(
                  request.amount,
                  Currency.eur,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.foreground,
                  ),
                ),
                DropdownMenu(
                  items: [
                    MenuItem(
                      leading: const PhosphorIcon(
                        PhosphorIconsRegular.bellRinging,
                      ),
                      onPressed: () => showBankToast(
                        context,
                        'Reminder sent',
                        description: '${request.person.firstName} got a nudge.',
                      ),
                      child: const Text('Remind'),
                    ),
                    MenuItem(
                      leading: const PhosphorIcon(
                        PhosphorIconsRegular.checkCircle,
                      ),
                      onPressed: () {
                        session.settleRequest(request);
                        showBankToast(
                          context,
                          '${request.person.firstName} paid you',
                          description:
                              '${money(request.amount, Currency.eur)} is in your EUR account.',
                          variant: ToastVariant.success,
                        );
                      },
                      child: const Text('Mark as paid'),
                    ),
                    const MenuDivider(),
                    MenuItem(
                      destructive: true,
                      leading: const PhosphorIcon(PhosphorIconsRegular.x),
                      onPressed: () => session.cancelRequest(request),
                      child: const Text('Cancel request'),
                    ),
                  ],
                  builder: (context, controller, child) => IconButton.ghost(
                    size: ButtonSize.sm,
                    icon: const PhosphorIcon(
                      PhosphorIconsRegular.dotsThreeVertical,
                    ),
                    semanticLabel: 'Request options',
                    onPressed: controller.toggle,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Payments that repeat, each with a switch to pause it.
class _Scheduled extends StatelessWidget {
  const _Scheduled();

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Scheduled'),
      children: [
        for (final payment in session.scheduled)
          ListTile(
            leading: IconTile(icon: PhosphorIcon(payment.icon)),
            title: Text(payment.title),
            subtitle: Text(
              payment.paused
                  ? 'Paused'
                  : '${money(payment.amount, Currency.eur)} · ${payment.every.toLowerCase()} · next ${DateFormat.MMMd().format(payment.next)}',
            ),
            trailing: Switch(
              value: !payment.paused,
              onChanged: (value) =>
                  session.update(() => payment.paused = !value),
            ),
          ),
      ],
    );
  }
}

/// Money between you and other people, lately.
class _RecentTransfers extends StatelessWidget {
  const _RecentTransfers();

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    final lines = session.transactions
        .where(
          (txn) => txn.kind == TxnKind.transfer || txn.kind == TxnKind.exchange,
        )
        .take(6)
        .toList();
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Recent transfers'),
      children: [
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
