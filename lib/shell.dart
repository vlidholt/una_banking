import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:una/una.dart';
import 'package:una_banking/app_state.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/screens/analytics_screen.dart';
import 'package:una_banking/screens/cards_screen.dart';
import 'package:una_banking/screens/home_screen.dart';
import 'package:una_banking/screens/notifications_screen.dart';
import 'package:una_banking/screens/payments_screen.dart';
import 'package:una_banking/screens/profile_screen.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/logo.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Una Banking's chrome around the screen of the selected [Destination].
///
/// * **Desktop** (from [topBarFrom]) — a top bar with the logo, the five
///   destinations, and the eye that hides balances, notifications and your
///   account.
/// * **Phone and tablet** — an app bar with your portrait, the eye and
///   notifications; the floating bottom bar with the five destinations.
class BankShell extends StatefulWidget {
  const BankShell({super.key});

  /// The width from which the desktop shell is used.
  static const topBarFrom = 1024.0;

  @override
  State<BankShell> createState() => _BankShellState();
}

class _BankShellState extends State<BankShell> {
  var _precached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_precached) return;
    _precached = true;
    // Portraits and vault photos are on the first screens: decode them up
    // front, so Home opens with its pictures rather than revealing them, and
    // a vault's page opens on its photograph.
    for (final person in [People.me, ...People.contacts]) {
      unawaited(RevealImage.precache(context, AssetImage(person.photo)));
    }
    for (final vault in vaultSeeds) {
      unawaited(RevealImage.precache(context, AssetImage(vault.photo)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= BankShell.topBarFrom;
        return SignalBuilder(
          builder: (context, _) {
            final destination = destinationProvider.of(context).value;
            final session = context.bank;
            return ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                final theme = Theme.of(context);
                final portrait = (theme.navigationBarTheme.iconSize ?? 24) + 4;
                return NavigationScaffold(
                  layout: wide
                      ? NavigationLayout.auto
                      : NavigationLayout.bottomBar,
                  selectedIndex: destination.index,
                  onDestinationSelected: (index) =>
                      context.goTo(Destination.values[index]),
                  destinations: [
                    const NavigationDestination(
                      icon: PhosphorIcon(PhosphorIconsRegular.house),
                      selectedIcon: PhosphorIcon(PhosphorIconsFill.house),
                      label: 'Home',
                    ),
                    const NavigationDestination(
                      icon: PhosphorIcon(PhosphorIconsRegular.creditCard),
                      selectedIcon: PhosphorIcon(PhosphorIconsFill.creditCard),
                      label: 'Cards',
                    ),
                    const NavigationDestination(
                      icon: PhosphorIcon(PhosphorIconsRegular.arrowsLeftRight),
                      selectedIcon: PhosphorIcon(
                        PhosphorIconsFill.arrowsLeftRight,
                      ),
                      label: 'Payments',
                    ),
                    const NavigationDestination(
                      icon: PhosphorIcon(PhosphorIconsRegular.chartPieSlice),
                      selectedIcon: PhosphorIcon(
                        PhosphorIconsFill.chartPieSlice,
                      ),
                      label: 'Analytics',
                    ),
                    NavigationDestination(
                      icon: PersonAvatar(People.me, size: portrait),
                      selectedIcon: _RingedPortrait(size: portrait),
                      label: 'Profile',
                      showInTopBar: false,
                    ),
                  ],
                  leading: BankLogo(
                    onPressed: () => context.goTo(Destination.home),
                  ),
                  actions: [
                    const _HideBalancesButton(),
                    const _NotificationsButton(),
                    const _AccountMenu(),
                  ],
                  mobileAppBar: const _MobileAppBar(),
                  body: DestinationStack(
                    index: destination.index,
                    builders: [
                      (context) => const HomeScreen(),
                      (context) => const CardsScreen(),
                      (context) => const PaymentsScreen(),
                      (context) => const AnalyticsScreen(),
                      (context) => const ProfileScreen(),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _RingedPortrait extends StatelessWidget {
  const _RingedPortrait({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.tint, width: 2),
      ),
      child: PersonAvatar(People.me, size: size - 7),
    );
  }
}

/// The eye that hides every balance, for a glance at the app in public.
class _HideBalancesButton extends StatelessWidget {
  const _HideBalancesButton();

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return IconButton(
      icon: PhosphorIcon(
        session.hideBalances
            ? PhosphorIconsRegular.eyeSlash
            : PhosphorIconsRegular.eye,
      ),
      semanticLabel: session.hideBalances ? 'Show balances' : 'Hide balances',
      onPressed: session.toggleHideBalances,
    );
  }
}

class _NotificationsButton extends StatelessWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context) {
    final unread = context.bank.unread;
    return IndicatorBadge(
      count: unread,
      semanticLabel: '$unread unread',
      child: IconButton(
        icon: const PhosphorIcon(PhosphorIconsRegular.bell),
        semanticLabel: 'Notifications',
        onPressed: () =>
            context.pushPage<void>((context) => const NotificationsScreen()),
      ),
    );
  }
}

/// Your portrait on the desktop bar: profile, appearance, Liquid Glass.
class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = themeModeProvider.of(context).value == ThemeMode.dark;
    final glass = liquidGlassProvider.of(context);
    return DropdownMenu(
      items: [
        MenuItem(
          leading: const PersonAvatar(People.me, size: 28),
          onPressed: () => context.goTo(Destination.profile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(People.me.name),
              Text('Premium · Paris', style: theme.textTheme.caption),
            ],
          ),
        ),
        const MenuDivider(),
        MenuItem(
          leading: const PhosphorIcon(PhosphorIconsRegular.userCircle),
          onPressed: () => context.goTo(Destination.profile),
          child: const Text('Profile and settings'),
        ),
        MenuItem(
          leading: const PhosphorIcon(PhosphorIconsRegular.bell),
          onPressed: () =>
              context.pushPage<void>((context) => const NotificationsScreen()),
          child: const Text('Notifications'),
        ),
        MenuItem(
          leading: PhosphorIcon(
            dark ? PhosphorIconsRegular.sun : PhosphorIconsRegular.moon,
          ),
          onPressed: () => toggleThemeMode(context),
          child: Text(dark ? 'Light mode' : 'Dark mode'),
        ),
        MenuItem(
          leading: const PhosphorIcon(PhosphorIconsRegular.drop),
          items: [
            for (final mode in LiquidGlassMode.values)
              MenuItem(
                leading: mode == glass.value
                    ? const PhosphorIcon(PhosphorIconsBold.check)
                    : const SizedBox.square(dimension: 16),
                onPressed: () => glass.value = mode,
                child: Text(switch (mode) {
                  LiquidGlassMode.auto => 'Automatic',
                  LiquidGlassMode.always => 'On',
                  LiquidGlassMode.never => 'Off',
                }),
              ),
          ],
          child: const Text('Liquid Glass'),
        ),
        const MenuDivider(),
        MenuItem(
          leading: const PhosphorIcon(PhosphorIconsRegular.signOut),
          onPressed: () => showDemoToast(
            context,
            'You stay signed in',
            description: 'There is nowhere to sign out to. Stay a while!',
          ),
          child: const Text('Sign out'),
        ),
      ],
      builder: (context, controller, child) => Pressable(
        onPressed: controller.toggle,
        semanticLabel: 'Your account',
        builder: (context, states) => FocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: theme.radii.full,
          child: const PersonAvatar(People.me, size: 34),
        ),
      ),
    );
  }
}

/// The phone's app bar: your portrait (your profile), the eye and the
/// bell.
class _MobileAppBar extends StatelessWidget {
  const _MobileAppBar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBar(
      actionsGap: 0,
      leading: Pressable(
        onPressed: () => context.goTo(Destination.profile),
        semanticLabel: 'Your profile',
        builder: (context, states) => FocusRing(
          visible: states.contains(WidgetState.focused),
          borderRadius: theme.radii.full,
          child: const PersonAvatar(People.me, size: 34),
        ),
      ),
      title: const BankLogo(),
      actions: const [_HideBalancesButton(), _NotificationsButton()],
    );
  }
}
