// Cestovni reusable visual primitives (CES-55).
//
// Source of truth: `docs/product/ux/cestovni-styling.md` §6.
//
// - [LedgerCard]: hero/recap card. `card` surface, 1px ink border,
//   `radiusBase`, hard offset shadow (`x=3, y=3, blur=0, ink`).
// - [LedgerTile]: compact stat tile. `paperDeep` surface, 1px ink,
//   `radiusBase`, 12dp padding.
// - [HairlineDivider]: 1px `rule` separator.
//
// All primitives read colours via `context.cestovniColors` so they
// follow theme switches without per-call wiring.

import 'package:flutter/material.dart';

import 'cestovni_tokens.dart';

/// Hero / recap surface — [`card` + 1px ink + radiusBase + hard
/// offset shadow](docs/product/ux/cestovni-styling.md#ledger-card).
class LedgerCard extends StatelessWidget {
  const LedgerCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CestovniMetrics.cardPadding),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cestovniColors;
    final radius = BorderRadius.circular(CestovniMetrics.radiusBase);
    final content = Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border.all(color: c.ink, width: CestovniMetrics.hairline),
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: c.ink,
            offset: CestovniMetrics.cardShadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// Compact stat / metric tile — [`paperDeep` + 1px ink + radiusBase +
/// 12dp padding](docs/product/ux/cestovni-styling.md#ledger-tile).
class LedgerTile extends StatelessWidget {
  const LedgerTile({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(CestovniMetrics.tilePadding),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.cestovniColors;
    final radius = BorderRadius.circular(CestovniMetrics.radiusBase);
    final content = Container(
      decoration: BoxDecoration(
        color: c.paperDeep,
        border: Border.all(color: c.ink, width: CestovniMetrics.hairline),
        borderRadius: radius,
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: content,
      ),
    );
  }
}

/// 1px `rule` separator used between grouped sections. Defaults to
/// the full available width; pass `indent`/`endIndent` for inset
/// rules inside cards.
class HairlineDivider extends StatelessWidget {
  const HairlineDivider({
    super.key,
    this.indent = 0,
    this.endIndent = 0,
  });

  final double indent;
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final c = context.cestovniColors;
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: Container(
        height: CestovniMetrics.hairline,
        color: c.rule,
      ),
    );
  }
}
