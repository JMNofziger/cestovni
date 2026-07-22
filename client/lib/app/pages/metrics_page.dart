import 'package:flutter/material.dart';

import '../../consumption/adapters.dart';
import '../../db/app_database.dart';
import '../../db/repositories/fill_ups_repository.dart';
import '../../db/repositories/settings_repository.dart';
import '../../metrics/metrics_aggregation.dart';
import '../../units/display_units.dart';
import '../active_vehicle.dart';
import '../theme/cestovni_primitives.dart';
import '../theme/cestovni_tokens.dart';
import '../theme/cestovni_typography.dart';

/// **Metrics** tab — range filter, summary card, and cost-over-time
/// chart per `cestovni-views.md` §Metrics + `DATA_CONTRACTS.md`
/// §"Metrics contract (MVP)". CES-66 replaces the M1 stub.
///
/// Offline-first: reads local Drift only (fill-ups + settings
/// streams); zero network.
class MetricsPage extends StatefulWidget {
  const MetricsPage({
    super.key,
    required this.db,
    required this.onOpenSettings,
  });

  final AppDatabase db;
  final VoidCallback onOpenSettings;

  @override
  State<MetricsPage> createState() => _MetricsPageState();
}

class _MetricsPageState extends State<MetricsPage> {
  late final FillUpsRepository _fillUps;
  late final SettingsRepository _settings;
  MetricsRange _range = MetricsRange.all;

  @override
  void initState() {
    super.initState();
    _fillUps = FillUpsRepository(widget.db);
    _settings = SettingsRepository(widget.db);
    // Kick the bootstrap so the settings stream emits on fresh installs.
    _settings.getOrBootstrap();
  }

  /// Fixed offset used to build civil-date range boundaries.
  /// `settings.timezone == 'UTC'` (the default) is exact; for other
  /// IANA names we approximate with the device's current offset — the
  /// app has no tz database yet, and display elsewhere (History) uses
  /// device-local time too. Real IANA resolution is a follow-up.
  Duration _tzOffset(SettingsRow settings) => settings.timezone == 'UTC'
      ? Duration.zero
      : DateTime.now().timeZoneOffset;

  @override
  Widget build(BuildContext context) {
    final colors = context.cestovniColors;
    final vehicleId = ActiveVehicleScope.of(context).vehicleId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CestovniMetrics.pagePadding,
            CestovniMetrics.pagePadding,
            CestovniMetrics.pagePadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text('Metrics',
                    style: Theme.of(context).textTheme.headlineLarge),
              ),
              _rangeToggle(colors),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: vehicleId == null
              ? _noVehicle(context, colors)
              : _body(vehicleId, colors),
        ),
      ],
    );
  }

  // ────────────────────────────── Range toggle

  Widget _rangeToggle(CestovniColors colors) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colors.ink, width: CestovniMetrics.hairline),
        borderRadius: BorderRadius.circular(CestovniMetrics.radiusBase),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in MetricsRange.values) _rangeBtn(r, colors),
        ],
      ),
    );
  }

  Widget _rangeBtn(MetricsRange r, CestovniColors colors) {
    final isActive = r == _range;
    return GestureDetector(
      onTap: () => setState(() => _range = r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? colors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(CestovniMetrics.radiusSm),
        ),
        child: Text(
          metricsRangeLabel(r),
          style: CestovniTypography.mono(
            fontSize: 11,
            color: isActive ? colors.paper : colors.mutedForeground,
            weight: FontWeight.w600,
            letterSpacing: 0.08 * 11,
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Empty states

  Widget _noVehicle(BuildContext context, CestovniColors colors) {
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: CestovniMetrics.contentMaxWidth),
        child: Padding(
          padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
          child: LedgerCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No vehicles yet',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  'Add your first vehicle to start logging fuel-ups\nand maintenance.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: widget.onOpenSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.ink,
                    foregroundColor: colors.paper,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(CestovniMetrics.radiusBase),
                    ),
                  ),
                  child: Text(
                    'GO TO SETTINGS',
                    style: CestovniTypography.mono(
                      fontSize: 12,
                      color: colors.paper,
                      weight: FontWeight.w600,
                      letterSpacing: 0.12 * 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyFillUps(BuildContext context, CestovniColors colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(CestovniMetrics.pagePadding),
        child: LedgerCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_outlined, size: 32, color: colors.ink),
              const SizedBox(height: 12),
              Text('No fill-ups yet',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Log fuel-ups on the Log tab to see distance,\nspend, and economy here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Body

  Widget _body(String vehicleId, CestovniColors colors) {
    return StreamBuilder<SettingsRow?>(
      stream: _settings.watchSingle(),
      builder: (context, settingsSnap) {
        final settings = settingsSnap.data;
        if (settings == null) return const SizedBox.shrink();
        return StreamBuilder<List<FillUpRow>>(
          stream: _fillUps.watchForVehicle(vehicleId),
          builder: (context, snap) {
            if (!snap.hasData) return const SizedBox.shrink();
            final rows = snap.data!;
            if (rows.isEmpty) return _emptyFillUps(context, colors);

            final startUtc = metricsWindowStartUtc(
              _range,
              DateTime.now().toUtc(),
              tzOffset: _tzOffset(settings),
            );
            final summary =
                computeMetricsSummary(fillUpsFromRows(rows), startUtc);
            return _content(summary, settings, colors);
          },
        );
      },
    );
  }

  Widget _content(
    MetricsSummary summary,
    SettingsRow settings,
    CestovniColors colors,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        CestovniMetrics.pagePadding,
        0,
        CestovniMetrics.pagePadding,
        CestovniMetrics.pagePadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: CestovniMetrics.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _summaryCard(summary, settings, colors),
              const SizedBox(height: 12),
              _statTiles(summary, settings, colors),
              const SizedBox(height: 12),
              _chartCard(summary, settings, colors),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────── Summary card

  Widget _summaryCard(
    MetricsSummary summary,
    SettingsRow settings,
    CestovniColors colors,
  ) {
    final costLabel = _range == MetricsRange.all
        ? 'LIFETIME COST'
        : '${metricsRangeLabel(_range)} COST';
    final distanceUnit = settings.preferredDistanceUnit;

    // Lead with the user's preferred currency; any other currencies in
    // the window are listed below the headline (CES-51 owns deep
    // multi-currency handling).
    final spend = summary.spendCentsByCurrency;
    final primaryCurrency = spend.containsKey(settings.currencyCode) ||
            spend.isEmpty
        ? settings.currencyCode
        : (spend.keys.toList()..sort()).first;
    final otherCurrencies = (spend.keys
            .where((c) => c != primaryCurrency)
            .toList()
          ..sort())
        .map((c) => formatMoney(spend[c]!, c))
        .join(' · ');

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(costLabel,
                    style: CestovniTypography.labelMono(
                        color: colors.mutedForeground)),
              ),
              Text('DISTANCE',
                  style: CestovniTypography.labelMono(
                      color: colors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  formatMoney(spend[primaryCurrency] ?? 0, primaryCurrency),
                  style: Theme.of(context).textTheme.displaySmall,
                ),
              ),
              Text(
                formatDistance(summary.distanceM, distanceUnit),
                style: CestovniTypography.mono(
                  fontSize: 18,
                  color: colors.ink,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (otherCurrencies.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '+ $otherCurrencies',
              style: CestovniTypography.labelMono(
                  color: colors.mutedForeground),
            ),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────── Stat tiles

  Widget _statTiles(
    MetricsSummary summary,
    SettingsRow settings,
    CestovniColors colors,
  ) {
    final volumeUnit = settings.preferredVolumeUnit;
    final mpg =
        useMpg(settings.preferredDistanceUnit, settings.preferredVolumeUnit);
    final economy = economyTenths(
      distanceM: summary.distanceM,
      volumeUL: summary.volumeUL,
      mpg: mpg,
    );

    return Row(
      children: [
        Expanded(
          child: _statTile(
            'VOL (${volumeUnitLabel(volumeUnit)})',
            volumeToDisplay(summary.volumeUL, volumeUnit, decimals: 1),
            colors,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            'AVG ${economyUnitLabel(mpg)}',
            economy == null ? '—' : formatTenths(economy),
            colors,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statTile(
            'FILL-UPS',
            formatThousands(summary.fillUpCount),
            colors,
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, CestovniColors colors) {
    return LedgerTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  CestovniTypography.labelMono(color: colors.mutedForeground)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: Theme.of(context).textTheme.headlineSmall),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────── Chart card

  static const double _chartHeight = 180;

  Widget _chartCard(
    MetricsSummary summary,
    SettingsRow settings,
    CestovniColors colors,
  ) {
    final palette = [
      colors.chart1,
      colors.chart2,
      colors.chart3,
      colors.chart4,
      colors.chart5,
    ];
    final currencies = summary.costSeriesByCurrency.keys.toList()..sort();

    return LedgerCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Cost over time',
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              Text('FIG.',
                  style: CestovniTypography.labelMono(
                      color: colors.mutedForeground)),
            ],
          ),
          const SizedBox(height: 12),
          const HairlineDivider(),
          const SizedBox(height: 12),
          if (summary.isLowData)
            _lowDataPlaceholder(colors)
          else ...[
            SizedBox(
              height: _chartHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _CostChartPainter(
                  seriesByCurrency: summary.costSeriesByCurrency,
                  currencyOrder: currencies,
                  palette: palette,
                  labelColor: colors.mutedForeground,
                  gridColor: colors.rule,
                ),
              ),
            ),
            if (currencies.length > 1) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                children: [
                  for (var i = 0; i < currencies.length; i++)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette[i % palette.length],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(currencies[i],
                            style: CestovniTypography.labelMono(
                                color: colors.mutedForeground)),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Low-data placeholder — same height as the chart so the card
  /// layout is preserved (no shimmer per `cestovni-views.md` §Empty
  /// states).
  Widget _lowDataPlaceholder(CestovniColors colors) {
    return SizedBox(
      height: _chartHeight,
      width: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('NOT ENOUGH DATA',
              style:
                  CestovniTypography.labelMono(color: colors.mutedForeground)),
          const SizedBox(height: 8),
          Text(
            'Log at least two fill-ups in this range\nto draw a trend.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Cost-over-time polyline painter.
//
// Deliberately a minimal custom painter (no charting dependency) per
// the CES-66 scope gate: polyline + point dots per currency, a zero /
// mid / max y-grid with major-unit labels, and first/last date x
// labels. Extra chart variants are Later.
// ══════════════════════════════════════════════════════════════════════

class _CostChartPainter extends CustomPainter {
  _CostChartPainter({
    required this.seriesByCurrency,
    required this.currencyOrder,
    required this.palette,
    required this.labelColor,
    required this.gridColor,
  });

  final Map<String, List<CostPoint>> seriesByCurrency;
  final List<String> currencyOrder;
  final List<Color> palette;
  final Color labelColor;
  final Color gridColor;

  static const double _leftPad = 36;
  static const double _bottomPad = 18;
  static const double _topPad = 6;

  @override
  void paint(Canvas canvas, Size size) {
    final allPoints = [
      for (final s in seriesByCurrency.values) ...s,
    ];
    if (allPoints.isEmpty) return;

    var maxCents = 0;
    var minT = allPoints.first.filledAt.millisecondsSinceEpoch;
    var maxT = minT;
    for (final p in allPoints) {
      if (p.totalPriceCents > maxCents) maxCents = p.totalPriceCents;
      final t = p.filledAt.millisecondsSinceEpoch;
      if (t < minT) minT = t;
      if (t > maxT) maxT = t;
    }
    if (maxCents == 0) maxCents = 1;

    final plot = Rect.fromLTRB(
      _leftPad,
      _topPad,
      size.width,
      size.height - _bottomPad,
    );
    final spanT = maxT - minT;

    double xFor(DateTime t) => spanT == 0
        ? plot.center.dx
        : plot.left +
            (t.millisecondsSinceEpoch - minT) / spanT * plot.width;
    double yFor(int cents) =>
        plot.bottom - cents / maxCents * plot.height;

    // Grid: 0 / mid / max hairlines + major-unit labels.
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = CestovniMetrics.hairline;
    for (final cents in [0, maxCents ~/ 2, maxCents]) {
      final y = yFor(cents);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _label(
        canvas,
        formatThousands(divideMajor(cents)),
        Offset(0, y - 6),
        maxWidth: _leftPad - 4,
        alignRight: true,
      );
    }

    // X labels: first + last civil date.
    _label(canvas, _dateLabel(DateTime.fromMillisecondsSinceEpoch(minT)),
        Offset(plot.left, plot.bottom + 4));
    if (spanT > 0) {
      final lastLabel =
          _dateLabel(DateTime.fromMillisecondsSinceEpoch(maxT));
      _label(canvas, lastLabel,
          Offset(plot.right - _textWidth(lastLabel), plot.bottom + 4));
    }

    // Polylines + dots per currency.
    for (var i = 0; i < currencyOrder.length; i++) {
      final points = seriesByCurrency[currencyOrder[i]]!;
      final color = palette[i % palette.length];
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final dotPaint = Paint()..color = color;

      final path = Path();
      for (var j = 0; j < points.length; j++) {
        final o = Offset(
          xFor(points[j].filledAt),
          yFor(points[j].totalPriceCents),
        );
        if (j == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      if (points.length > 1) canvas.drawPath(path, linePaint);
      for (final p in points) {
        canvas.drawCircle(
          Offset(xFor(p.filledAt), yFor(p.totalPriceCents)),
          2.5,
          dotPaint,
        );
      }
    }
  }

  static int divideMajor(int cents) => cents ~/ 100;

  static String _dateLabel(DateTime utc) {
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  TextPainter _painterFor(String text) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const ['monospace'],
          fontSize: 10,
          color: labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp;
  }

  double _textWidth(String text) => _painterFor(text).width;

  void _label(
    Canvas canvas,
    String text,
    Offset offset, {
    double? maxWidth,
    bool alignRight = false,
  }) {
    final tp = _painterFor(text);
    var dx = offset.dx;
    if (alignRight && maxWidth != null) {
      dx = offset.dx + maxWidth - tp.width;
    }
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(_CostChartPainter oldDelegate) =>
      oldDelegate.seriesByCurrency != seriesByCurrency ||
      oldDelegate.labelColor != labelColor;
}
