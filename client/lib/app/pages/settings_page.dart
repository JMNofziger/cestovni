import 'package:flutter/material.dart';

import '../../db/app_database.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';
import 'debug_page.dart';

/// Settings — pushed route from the shell header gear icon (CES-56).
/// Real preference wiring (units, currency, timezone, default
/// vehicle) lands with the `settings` DAO in M1. **Debug** is
/// reachable from inside Settings now that the bottom nav is locked
/// to the four feature tabs.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          vertical: CestovniMetrics.tilePadding,
        ),
        children: [
          _SectionLabel(text: 'Preferences'),
          const ListTile(
            leading: Icon(Icons.straighten),
            title: Text('Distance unit'),
            subtitle: Text('km (default)'),
          ),
          const ListTile(
            leading: Icon(Icons.local_drink),
            title: Text('Volume unit'),
            subtitle: Text('L (default)'),
          ),
          const ListTile(
            leading: Icon(Icons.attach_money),
            title: Text('Currency'),
            subtitle: Text('USD (default)'),
          ),
          const ListTile(
            leading: Icon(Icons.schedule),
            title: Text('Timezone'),
            subtitle: Text('Device default'),
          ),
          const HairlineDivider(),
          _SectionLabel(text: 'Backup'),
          const ListTile(
            leading: Icon(Icons.cloud_off_outlined),
            title: Text('Backup'),
            subtitle: Text('Offline — sign in lands in M3.'),
          ),
          const HairlineDivider(),
          _SectionLabel(text: 'Developer'),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug'),
            subtitle: const Text(
              'Schema + migration tooling. Pre-rollback (CES-47).',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DebugPage(db: db),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        CestovniMetrics.tilePadding,
        CestovniMetrics.pagePadding,
        4,
      ),
      child: Text(
        text.toUpperCase(),
        style: CestovniTypography.labelMono(
          color: context.cestovniColors.mutedForeground,
        ),
      ),
    );
  }
}
