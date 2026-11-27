import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:una/una.dart';
import 'package:una_banking/app_state.dart';
import 'package:una_banking/data.dart';
import 'package:una_banking/money.dart';
import 'package:una_banking/navigation.dart';
import 'package:una_banking/screens/notifications_screen.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/logo.dart';
import 'package:una_banking/widgets/pieces.dart';

/// You: your plan, how the app looks, security and the devices signed in,
/// notifications and help.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _Device {
  const _Device(this.name, this.where, this.icon, {this.current = false});

  final String name;
  final String where;
  final IconData icon;
  final bool current;
}

class _ProfileScreenState extends State<ProfileScreen> {
  var _twoFactor = true;
  var _biometrics = true;
  var _payments = true;
  var _security = true;
  var _insights = false;
  final _devices = [
    const _Device(
      'iPhone 17 Pro',
      'This device · Paris',
      PhosphorIconsRegular.deviceMobile,
      current: true,
    ),
    const _Device(
      'MacBook Pro',
      'Paris · 4 days ago',
      PhosphorIconsRegular.laptop,
    ),
    const _Device(
      'iPad Air',
      'Lyon · 3 weeks ago',
      PhosphorIconsRegular.deviceTablet,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final session = context.bank;
    return SignalBuilder(
      builder: (context, _) {
        // Read in the builder's own body, where the signals are tracked;
        // the sections below read them again.
        themeModeProvider.of(context).value;
        liquidGlassProvider.of(context).value;
        textScaleProvider.of(context).value;
        return ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final sections = [
              _header(context),
              _appearance(context),
              _securitySection(context),
              _notifications(context),
              _account(context),
              _help(context),
            ];
            return PageContainer(
              scrollable: true,
              maxWidth: 1100,
              child: FormFactorBuilder(
                mobile: (context) => UnaColumn(
                  gap: GapSize.lg,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: sections,
                ),
                desktop: (context) => UnaColumn(
                  gap: GapSize.lg,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PageHeader(
                      title: 'Profile',
                      subtitle: 'Your plan, the app, and keeping it all safe',
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final gap = Theme.of(context).layoutTheme
                            .gap(GapSize.lg);
                        final left = UnaColumn(
                          gap: GapSize.lg,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [sections[0], sections[1], sections[4]],
                        );
                        final right = UnaColumn(
                          gap: GapSize.lg,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [sections[2], sections[3], sections[5]],
                        );
                        if (constraints.maxWidth < 820) {
                          return UnaColumn(
                            gap: GapSize.lg,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: sections,
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
      },
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.bank;
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              const PersonAvatar(People.me, size: 64),
              const Gap.md(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(People.me.name, style: theme.textTheme.h4),
                    Text(People.me.handle, style: theme.textTheme.muted),
                    const Gap.xs(),
                    Badge(
                      backgroundColor: theme.colorScheme.tint.withValues(
                        alpha: .14,
                      ),
                      foregroundColor: theme.colorScheme.tint,
                      child: const Text('Premium'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap.lg(),
          UnaRow(
            gap: GapSize.md,
            children: [
              Expanded(
                child: _Figure(
                  label: 'Accounts',
                  value: Text('${session.accounts.length}'),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Cards',
                  value: Text('${session.cards.length}'),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Saved',
                  value: AmountText(
                    session.savedInVaults,
                    Currency.eur,
                    decimals: 0,
                    style: theme.textTheme.large,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearance(BuildContext context) {
    final themeMode = themeModeProvider.of(context);
    final glass = liquidGlassProvider.of(context);
    final scale = textScaleProvider.of(context);
    final session = context.bank;
    final mobile = Theme.of(context).formFactor == FormFactor.mobile;
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Appearance'),
      children: [
        _choiceTile(
          context,
          icon: PhosphorIconsRegular.moon,
          title: 'Theme',
          control: SegmentedControl<ThemeMode>(
            value: themeMode.value,
            size: ControlSize.sm,
            expand: mobile,
            onChanged: (mode) => themeMode.value = mode,
            segments: const [
              Segment(value: ThemeMode.light, label: Text('Light')),
              Segment(value: ThemeMode.dark, label: Text('Dark')),
              Segment(value: ThemeMode.system, label: Text('Auto')),
            ],
          ),
        ),
        _choiceTile(
          context,
          icon: PhosphorIconsRegular.drop,
          title: 'Liquid Glass',
          subtitle: 'Auto is on for iPhone, iPad and Mac',
          control: SegmentedControl<LiquidGlassMode>(
            value: glass.value,
            size: ControlSize.sm,
            expand: mobile,
            onChanged: (mode) => glass.value = mode,
            segments: const [
              Segment(value: LiquidGlassMode.auto, label: Text('Auto')),
              Segment(value: LiquidGlassMode.always, label: Text('On')),
              Segment(value: LiquidGlassMode.never, label: Text('Off')),
            ],
          ),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.eyeSlash),
          ),
          title: const Text('Hide balances'),
          subtitle: const Text('Dots instead of amounts, for the bus'),
          value: session.hideBalances,
          onChanged: (_) => session.toggleHideBalances(),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.textAa),
          ),
          title: const Text('Text size'),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Slider(
              value: scale.value,
              min: .85,
              max: 1.3,
              divisions: 9,
              showDivisionMarks: false,
              semanticLabel: 'Text size',
              onChanged: (value) => scale.value = value,
            ),
          ),
        ),
      ],
    );
  }

  /// A row with a choice: the control beside the title on a desktop,
  /// under it on a phone, where the two would not fit side by side.
  Widget _choiceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget control,
    String? subtitle,
  }) {
    final mobile = Theme.of(context).formFactor == FormFactor.mobile;
    if (!mobile) {
      return ListTile(
        leading: IconTile(icon: PhosphorIcon(icon)),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: control,
      );
    }
    return ListTile(
      leading: IconTile(icon: PhosphorIcon(icon)),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (subtitle != null) Text(subtitle),
          const Gap.sm(),
          control,
        ],
      ),
    );
  }

  Widget _securitySection(BuildContext context) {
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Security'),
      children: [
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.shieldCheck),
          ),
          title: const Text('Two-step verification'),
          subtitle: const Text('A code from your phone for new devices'),
          value: _twoFactor,
          onChanged: (value) {
            setState(() => _twoFactor = value);
            if (!value) {
              showBankToast(
                context,
                'Two-step verification is off',
                description: 'We recommend keeping it on.',
                variant: ToastVariant.warning,
                actionLabel: 'Turn on',
                onAction: () => setState(() => _twoFactor = true),
              );
            }
          },
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.scan),
          ),
          title: const Text('Face ID to open the app'),
          value: _biometrics,
          onChanged: (value) => setState(() => _biometrics = value),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.password),
          ),
          title: const Text('Change passcode'),
          showChevron: true,
          onTap: () => showDemoToast(
            context,
            'Passcode',
            description: 'You would choose six new digits here.',
          ),
        ),
        for (final device in _devices)
          ListTile(
            leading: IconTile(icon: PhosphorIcon(device.icon)),
            title: Text(device.name),
            subtitle: Text(device.where),
            trailing: device.current
                ? Badge.secondary(child: const Text('This device'))
                : Button.ghost(
                    size: ButtonSize.sm,
                    onPressed: () {
                      setState(() => _devices.remove(device));
                      showBankToast(
                        context,
                        '${device.name} signed out',
                        actionLabel: 'Undo',
                        onAction: () => setState(() => _devices.add(device)),
                      );
                    },
                    child: const Text('Sign out'),
                  ),
          ),
      ],
    );
  }

  Widget _notifications(BuildContext context) {
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Notifications'),
      headerTrailing: Button.link(
        onPressed: () =>
            context.pushPage<void>((context) => const NotificationsScreen()),
        child: const Text('See all'),
      ),
      children: [
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.creditCard),
          ),
          title: const Text('Every payment'),
          value: _payments,
          onChanged: (value) => setState(() => _payments = value),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.shieldWarning),
          ),
          title: const Text('Security alerts'),
          subtitle: const Text('Sign-ins, declined payments, frozen cards'),
          value: _security,
          onChanged: (value) => setState(() => _security = value),
        ),
        SwitchListTile(
          secondary: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.chartLineUp),
          ),
          title: const Text('Weekly insights'),
          subtitle: const Text('Your week in spending, every Sunday'),
          value: _insights,
          onChanged: (value) => setState(() => _insights = value),
        ),
      ],
    );
  }

  Widget _account(BuildContext context) {
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Account'),
      children: [
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.crown),
          ),
          title: const Text('Plan'),
          value: const Text('Premium · €9.99/mo'),
          showChevron: true,
          onTap: () => showDemoToast(
            context,
            'Premium',
            description: 'Metal card, travel insurance and no exchange fees on weekdays.',
          ),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.identificationCard),
          ),
          title: const Text('Personal details'),
          showChevron: true,
          onTap: () => showDemoToast(context, 'Personal details'),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.bank),
          ),
          title: const Text('Linked accounts'),
          value: const Text('Northbank •• 2210'),
          showChevron: true,
          onTap: () => showDemoToast(context, 'Linked accounts'),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.fileText),
          ),
          title: const Text('Statements'),
          showChevron: true,
          onTap: () => showDemoToast(
            context,
            'Statement downloaded',
            description: 'Last month’s statement, as a PDF.',
          ),
        ),
      ],
    );
  }

  Widget _help(BuildContext context) {
    return ListSection(
      margin: EdgeInsets.zero,
      header: const Text('Help'),
      children: [
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.chatsCircle),
          ),
          title: const Text('Chat with us'),
          subtitle: const Text('Usually answers in a few minutes'),
          showChevron: true,
          onTap: () => showDemoToast(
            context,
            'Support',
            description: 'A real app would open a chat with a person here.',
          ),
        ),
        ListTile(
          leading: const IconTile(
            icon: PhosphorIcon(PhosphorIconsRegular.info),
          ),
          title: const Text('About Una Banking'),
          showChevron: true,
          onTap: () => context.pushPage<void>(
            (context) => const LicensePage(
              applicationName: 'Una Banking',
              applicationVersion: '1.0',
              applicationIcon: SizedBox.square(
                dimension: 56,
                child: CustomPaint(painter: BankMarkPainter()),
              ),
              applicationLegalese:
                  'A demo of the una Flutter package. Every person, company and '
                  'number in it is fictional.',
            ),
          ),
        ),
        ListTile(
          title: const Text('Sign out'),
          destructive: true,
          onTap: () => showDemoToast(
            context,
            'You stay signed in',
            description: 'There is nowhere to sign out to. Stay a while!',
          ),
        ),
      ],
    );
  }
}

/// A figure and its label, side by side with others under the header.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.large
              .copyWith(
                color: theme.colorScheme.foreground,
              )
              .tabular,
          child: value,
        ),
        Text(label, style: theme.textTheme.caption),
      ],
    );
  }
}
