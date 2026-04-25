import 'package:flutter/material.dart';

import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **History** tab — unified fuel + maintenance timeline per
/// `cestovni-views.md` (`History`). M1 stub.
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

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
                  Icons.event_note_outlined,
                  size: 32,
                  color: colors.ink,
                ),
                const SizedBox(height: CestovniMetrics.tilePadding),
                Text(
                  'History',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Monthly timeline of fuel + maintenance entries with '
                  'All / Fuel / Maint filter chips. Lands with CES-39 '
                  'follow-on work.',
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
