import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/flows.dart';
import 'package:una_banking/widgets/pieces.dart';

/// A vault: its photo, how far along it is, the money in and out, and
/// round-ups.
class VaultScreen extends StatelessWidget {
  const VaultScreen({required this.vaultId, super.key});

  final String vaultId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    return Scaffold(
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final vault = session.vault(vaultId);
          final history = session.transactions
              .where((txn) => txn.vaultId == vault.id)
              .toList();
          final left = vault.target - vault.saved;
          // At the pace of the round-ups and a weekly €25, when it is full.
          final weeks = (left / (vault.roundUps ? 37 : 25)).ceil();
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverAppBar.large(
                title: Text(vault.name),
                subtitle: Text(
                  '${money(vault.saved, Currency.eur, decimals: 0)} of ${money(vault.target, Currency.eur, decimals: 0)}',
                ),
                expandedHeight: 240,
                // In line with the page under it on a wide window.
                maxWidth: 760,
                background: RevealImage.asset(vault.photo, fit: BoxFit.cover),
              ),
              SliverToBoxAdapter(
                child: PageContainer(
                  maxWidth: 760,
                  child: UnaColumn(
                    gap: GapSize.lg,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Row(
                          children: [
                            ProgressRing(
                              value: vault.progress,
                              size: 88,
                              strokeWidth: 9,
                              semanticLabel: '${vault.name} progress',
                              child: Text(
                                '${(vault.progress * 100).round()}%',
                                style: theme.textTheme.large
                                    .copyWith(
                                      fontWeight: FontWeight.w700,
                                    )
                                    .tabular,
                              ),
                            ),
                            const Gap.lg(),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  BalanceText(
                                    vault.saved,
                                    Currency.eur,
                                    size: 30,
                                  ),
                                  const Gap.xs(),
                                  Text(
                                    vault.reached
                                        ? 'Goal reached. Time to book it!'
                                        : '${money(left, Currency.eur, decimals: 0)} to go · about $weeks ${weeks == 1 ? 'week' : 'weeks'} at this pace',
                                    style: theme.textTheme.muted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      UnaRow(
                        gap: GapSize.sm,
                        children: [
                          Expanded(
                            child: Button(
                              leading: const PhosphorIcon(
                                PhosphorIconsBold.plus,
                              ),
                              onPressed: () =>
                                  showVaultMoneyFlow(context, vault),
                              child: const ButtonLabel('Add money'),
                            ),
                          ),
                          Expanded(
                            child: Button.outline(
                              leading: const PhosphorIcon(
                                PhosphorIconsBold.minus,
                              ),
                              onPressed: vault.saved > 0
                                  ? () => showVaultMoneyFlow(
                                      context,
                                      vault,
                                      withdraw: true,
                                    )
                                  : null,
                              child: const ButtonLabel('Take out'),
                            ),
                          ),
                        ],
                      ),
                      ListSection(
                        margin: EdgeInsets.zero,
                        header: const Text('Saving automatically'),
                        children: [
                          SwitchListTile(
                            secondary: IconTile(
                              icon: const PhosphorIcon(
                                PhosphorIconsRegular.coins,
                              ),
                              foregroundColor: scheme.tint,
                            ),
                            title: const Text('Round-ups'),
                            subtitle: const Text(
                              'Every card payment rounded up to the next euro, the change saved here',
                            ),
                            value: vault.roundUps,
                            onChanged: (value) =>
                                session.update(() => vault.roundUps = value),
                          ),
                          ListTile(
                            leading: const IconTile(
                              icon: PhosphorIcon(
                                PhosphorIconsRegular.calendarCheck,
                              ),
                            ),
                            title: const Text('Weekly transfer'),
                            subtitle: const Text('€25 every Monday from EUR'),
                            showChevron: true,
                            onTap: () => showDemoToast(
                              context,
                              'Weekly transfer',
                              description:
                                  'Change it under Payments › Scheduled.',
                            ),
                          ),
                        ],
                      ),
                      ListSection(
                        margin: EdgeInsets.zero,
                        header: const Text('History'),
                        children: [
                          if (history.isEmpty)
                            const ListTile(
                              title: Text('Nothing moved yet'),
                              subtitle: Text('Money you add shows here'),
                            ),
                          for (final txn in history)
                            ListTile(
                              leading: IconTile(
                                icon: PhosphorIcon(
                                  txn.amount < 0
                                      ? PhosphorIconsRegular.arrowDown
                                      : PhosphorIconsRegular.arrowUp,
                                ),
                              ),
                              title: Text(
                                txn.amount < 0 ? 'Added' : 'Taken out',
                              ),
                              subtitle: Text(dayHeading(txn.date)),
                              trailing: AmountText(
                                -txn.amount,
                                Currency.eur,
                                sign: true,
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: scheme.foreground,
                                ),
                              ),
                            ),
                          ListTile(
                            leading: const IconTile(
                              icon: PhosphorIcon(PhosphorIconsRegular.coins),
                            ),
                            title: const Text('Round-ups since you opened it'),
                            trailing: AmountText(
                              vault.saved * .08,
                              Currency.eur,
                              style: theme.textTheme.small.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
