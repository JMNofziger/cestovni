import 'package:flutter/material.dart';

import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Log** tab — fast-entry fuel-up form per `cestovni-views.md`
/// (`Log a Fuel-Up`). M1 stub: empty state pointing to where the
/// real form will land in CES-39.
class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _StubBody(
      icon: Icons.local_gas_station_outlined,
      title: 'Log a fuel-up',
      body: 'The fast-entry form lands with CES-39. Until then this '
          'tab is a placeholder so the shell matches the target '
          'navigation.',
    );
  }
}

class _StubBody extends StatelessWidget {
  const _StubBody({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: CestovniMetrics.contentMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
          child: LedgerCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 32, color: colors.ink),
                const SizedBox(height: CestovniMetrics.tilePadding),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: CestovniMetrics.sectionGap),
                Text(
                  'CES-39 PLACEHOLDER',
                  style: CestovniTypography.labelMono(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
