import 'package:flutter/material.dart';

import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Metrics** tab — lifetime + range trend cards per
/// `cestovni-views.md` (`Metrics`). M1 stub.
class MetricsPage extends StatelessWidget {
  const MetricsPage({super.key});

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
                  Icons.show_chart_outlined,
                  size: 32,
                  color: colors.ink,
                ),
                const SizedBox(height: CestovniMetrics.tilePadding),
                Text(
                  'Metrics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '30D / 90D / YTD / ALL range filter, lifetime card, '
                  'and Cost-over-time trend. Depends on CES-38 '
                  'consumption math + CES-39 entry surfaces.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: CestovniMetrics.sectionGap),
                Text(
                  'CES-38 / CES-39 FOLLOW-ON',
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
