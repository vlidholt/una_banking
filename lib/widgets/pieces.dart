import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/session.dart';

/// A person's portrait in a circle.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(this.person, {this.size = 40, super.key});

  final Person person;
  final double size;

  @override
  Widget build(BuildContext context) => Avatar(
    person.photo,
    size: Size.square(size),
    fallback: Text(person.initials),
  );
}

/// A merchant's logo: its glyph on a tile in its own colours. Drawn by the
/// app; every merchant is fictional.
class MerchantLogo extends StatelessWidget {
  const MerchantLogo(this.merchant, {this.size = 40, super.key});

  final Merchant merchant;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (from, to) = merchant.colors;
    return Semantics(
      label: merchant.name,
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.circular(size * .3),
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [from, to],
            ),
          ),
          child: PhosphorIcon(
            merchant.icon,
            size: size * .5,
            color: const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}

/// The picture at the start of a statement line: the merchant's logo, the
/// person's portrait, the currencies of an exchange, a vault's photo.
class TxnAvatar extends StatelessWidget {
  const TxnAvatar(this.txn, {this.size = 40, super.key});

  final Txn txn;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (txn.merchant case final merchant?) {
      return MerchantLogo(merchant, size: size);
    }
    if (txn.person case final person?) return PersonAvatar(person, size: size);
    switch (txn.kind) {
      case TxnKind.exchange:
        return SizedBox.square(
          dimension: size,
          child: Stack(
            children: [
              CurrencyBadge(
                txn.amount < 0 ? txn.currency : txn.counterCurrency!,
                size: size * .68,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.card,
                      width: 2,
                    ),
                  ),
                  child: CurrencyBadge(
                    txn.amount < 0 ? txn.counterCurrency! : txn.currency,
                    size: size * .62,
                  ),
                ),
              ),
            ],
          ),
        );
      case TxnKind.vault:
        final photo = vaultSeeds
            .where((seed) => seed.id == txn.vaultId)
            .firstOrNull
            ?.photo;
        if (photo != null) {
          return ClipRSuperellipse(
            borderRadius: BorderRadius.circular(size * .3),
            child: Image.asset(
              photo,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          );
        }
      case TxnKind.topUp:
        return IconTile(
          size: size,
          icon: const PhosphorIcon(PhosphorIconsBold.plus),
        );
      default:
    }
    return IconTile(size: size, icon: PhosphorIcon(txn.category.icon));
  }
}

/// [amount] in [currency], or dots while balances are hidden.
class AmountText extends StatelessWidget {
  const AmountText(
    this.amount,
    this.currency, {
    this.style,
    this.sign = false,
    this.colorIncoming = false,
    this.decimals,
    this.strike = false,
    super.key,
  });

  final double amount;
  final Currency currency;
  final TextStyle? style;

  /// Writes a plus before money that came in.
  final bool sign;

  /// Sets money that came in in the success colour.
  final bool colorIncoming;
  final int? decimals;

  /// Strikes the amount through, for a declined payment.
  final bool strike;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = context.bank.hideBalances;
    var effective = (style ?? theme.textTheme.small).tabular;
    if (colorIncoming && amount > 0) {
      effective = effective.copyWith(color: theme.colorScheme.success);
    }
    if (strike) {
      effective = effective.copyWith(
        decoration: TextDecoration.lineThrough,
        color: theme.colorScheme.mutedForeground,
      );
    }
    return Text(
      hidden
          ? '${amount < 0 ? '−' : ''}${currency.suffix ? '•••• ${currency.symbol}' : '${currency.symbol}••••'}'
          : money(amount, currency, sign: sign, decimals: decimals),
      maxLines: 1,
      softWrap: false,
      style: effective,
    );
  }
}

/// A headline balance: the whole part large, the cents smaller and lighter.
class BalanceText extends StatelessWidget {
  const BalanceText(
    this.amount,
    this.currency, {
    this.size = 40,
    this.color,
    super.key,
  });

  final double amount;
  final Currency currency;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = color ?? theme.colorScheme.foreground;
    final big = theme.textTheme.h1
        .copyWith(
          fontSize: size,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -.03 * size,
          color: ink,
        )
        .tabular;
    if (context.bank.hideBalances) {
      return Text(
        currency.suffix
            ? '•••••• ${currency.symbol}'
            : '${currency.symbol}••••••',
        style: big,
        maxLines: 1,
      );
    }
    final (whole, cents) = moneyParts(amount, currency);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: whole),
          TextSpan(
            text: cents,
            style: big.copyWith(
              fontSize: size * .55,
              color: ink.withValues(alpha: ink.a * .62),
              letterSpacing: 0,
            ),
          ),
        ],
      ),
      style: big,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.fade,
    );
  }
}

/// One line of the statement.
class TxnTile extends StatelessWidget {
  const TxnTile(this.txn, {this.onTap, this.showDate = false, super.key});

  final Txn txn;
  final VoidCallback? onTap;

  /// Writes the day as well as the time under the title.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final time = DateFormat.Hm().format(txn.date);
    final when = showDate
        ? '${DateFormat.MMMd().format(txn.date)}, $time'
        : time;
    final status = txn.status == TxnStatus.completed
        ? ''
        : ' · ${txn.status.label}';
    return ListTile(
      leading: TxnAvatar(txn),
      title: Text(txn.title),
      subtitle: Text('$when · ${txn.detail}$status'),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AmountText(
            txn.amount,
            txn.currency,
            sign: true,
            colorIncoming: true,
            strike: txn.status == TxnStatus.declined,
            style: theme.textTheme.small.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.foreground,
            ),
          ),
          if (txn.currency != Currency.eur && txn.kind == TxnKind.card)
            AmountText(
              txn.inEuros,
              Currency.eur,
              style: theme.textTheme.caption,
            ),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// A heading over a group on a page, with an optional link at the end.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {this.action, this.onAction, super.key});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: theme.textTheme.h4),
          ),
        ),
        if (action != null)
          Button.link(onPressed: onAction, child: Text(action!)),
      ],
    );
  }
}

/// A page's title with a line under it on a desktop, and its actions.
class PageHeader extends StatelessWidget {
  const PageHeader({
    required this.title,
    this.subtitle,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final layout = theme.layoutTheme;
    final heading = Semantics(
      header: true,
      child: Text(title, style: theme.textTheme.h1),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: layout.gap(GapSize.xl),
      runSpacing: layout.gap(GapSize.md),
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (subtitle case final subtitle?) ...[
              const Gap.xs(),
              Text(
                subtitle,
                style: theme.textTheme.p.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
            ],
          ],
        ),
        if (actions.isNotEmpty)
          UnaRow(
            gap: GapSize.sm,
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
      ],
    );
  }
}

/// A round action under a balance: Add money, Send, Exchange, More.
class RoundAction extends StatelessWidget {
  const RoundAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.onImage = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Drawn over the hero's gradient: white glass instead of the theme's
  /// secondary fill.
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mobile = theme.formFactor == FormFactor.mobile;
    final disc = mobile ? 52.0 : 48.0;
    const white = Color(0xFFFFFFFF);
    return Pressable(
      onPressed: onPressed,
      semanticLabel: label,
      semanticContainer: true,
      builder: (context, states) {
        final hovered =
            states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.pressed);
        final fill = onImage
            ? white.withValues(alpha: hovered ? .3 : .2)
            : hovered
            ? scheme.accent
            : scheme.secondary;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FocusRing(
              visible: states.contains(WidgetState.focused),
              borderRadius: theme.radii.full,
              child: AnimatedFill(
                color: fill,
                borderRadius: theme.radii.full,
                child: SizedBox.square(
                  dimension: disc,
                  child: Center(
                    child: PhosphorIcon(
                      icon,
                      size: 22,
                      color: onImage ? white : scheme.foreground,
                    ),
                  ),
                ),
              ),
            ),
            const Gap.xs(),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: onImage ? white : scheme.foreground,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A toast with an optional action that dismisses it.
void showBankToast(
  BuildContext context,
  String title, {
  String? description,
  ToastVariant variant = ToastVariant.neutral,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final toaster = Toaster.of(context);
  late final Object id;
  id = toaster.show(
    Toast(
      variant: variant,
      title: Text(title),
      description: description == null ? null : Text(description),
      action: actionLabel == null
          ? null
          : Button.outline(
              size: ButtonSize.sm,
              onPressed: () {
                toaster.dismiss(id);
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
    ),
  );
}

/// "This is a demo": the answer of a control with nowhere real to go.
void showDemoToast(BuildContext context, String title, {String? description}) =>
    showBankToast(
      context,
      title,
      description:
          description ?? 'Una Banking is a demo: nothing leaves the app.',
    );

/// Opens a flow — sending money, exchanging, a card's PIN — as a sheet on a
/// phone and a dialog on a desktop. [builder] builds the content; the flow
/// closes itself with `Navigator.pop`.
Future<T?> showFlow<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
  String? description,
  double maxWidth = 460,
}) {
  final theme = Theme.of(context);
  if (theme.formFactor == FormFactor.mobile) {
    return showSheet<T>(
      context: context,
      builder: (context) => Sheet(
        title: Text(title),
        description: description == null ? null : Text(description),
        detents: const [SheetDetent.content],
        child: builder(context),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      title: Text(title),
      description: description == null ? null : Text(description),
      showCloseButton: true,
      style: DialogTheme(constraints: BoxConstraints(maxWidth: maxWidth)),
      child: builder(context),
    ),
  );
}

/// How long ago [date] was, as a statement's day heading says it.
String dayHeading(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  final difference = today.difference(day).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return DateFormat.EEEE().format(date);
  if (date.year == today.year) return DateFormat.MMMMd().format(date);
  return DateFormat.yMMMMd().format(date);
}

/// "2 h ago", "Yesterday", "Mon": a notification's age.
String ago(DateTime date) {
  final difference = DateTime.now().difference(date);
  if (difference.inMinutes < 1) return 'Now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} h ago';
  return dayHeading(date);
}

/// A button's label that shrinks with an ellipsis when the button is given
/// less room than the label needs (a button in an `Expanded`): `Button`
/// lays its label out at its natural width.
class ButtonLabel extends StatelessWidget {
  const ButtonLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Flexible(
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    ),
  );
}
