import 'package:flutter/material.dart';

import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Maintenance** tab — entry form + history per `cestovni-views.md`
/// (`Maintenance`). Per `DATA_CONTRACTS.md` § *Performed time
/// (maintenance)*, date-only entries map to local-noon UTC. M1 stub.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});

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
                Icon(
                  Icons.build_outlined,
                  size: 32,
                  color: colors.ink,
                ),
                const SizedBox(height: CestovniMetrics.tilePadding),
                Text(
                  'Maintenance',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Maintenance entry form + history; reminder cadence '
                  'on `maintenance_rules`. Schema is ready (CES-53 + '
                  'CES-54). UI lands with CES-39 follow-on.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: CestovniMetrics.sectionGap),
                Text(
                  'CES-39 FOLLOW-ON',
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
