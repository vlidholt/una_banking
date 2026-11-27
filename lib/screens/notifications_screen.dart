import 'package:flutter/widgets.dart';
import 'package:una/una.dart';
import 'package:una_banking/session.dart';
import 'package:una_banking/widgets/pieces.dart';

/// Notifications: payments, security and vaults, new first.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final session = context.bank;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final fresh = session.notices.where((notice) => !notice.read).toList();
        final earlier = session.notices.where((notice) => notice.read).toList();
        ListTile tile(Notice notice) => ListTile(
          leading: IconTile(
            icon: PhosphorIcon(notice.icon),
            foregroundColor: notice.read ? null : scheme.tint,
          ),
          title: Text(
            notice.title,
            style: notice.read
                ? null
                : theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
          ),
          subtitle: Text('${notice.body} · ${ago(notice.date)}'),
          subtitleMaxLines: 2,
          trailing: notice.read
              ? null
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.tint,
                  ),
                ),
          onTap: () => session.update(() => notice.read = true),
        );
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (fresh.isNotEmpty)
                Button(
                  onPressed: session.markAllRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: PageContainer(
            scrollable: true,
            maxWidth: 720,
            child: UnaColumn(
              gap: GapSize.lg,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fresh.isEmpty && earlier.isEmpty)
                  const Empty(
                    icon: PhosphorIcon(PhosphorIconsRegular.bellSimpleSlash),
                    title: Text('All quiet'),
                    description: Text(
                      'Payments and security alerts show here.',
                    ),
                  ),
                if (fresh.isNotEmpty)
                  ListSection(
                    margin: EdgeInsets.zero,
                    header: const Text('New'),
                    children: [for (final notice in fresh) tile(notice)],
                  ),
                if (earlier.isNotEmpty)
                  ListSection(
                    margin: EdgeInsets.zero,
                    header: const Text('Earlier'),
                    children: [for (final notice in earlier) tile(notice)],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
