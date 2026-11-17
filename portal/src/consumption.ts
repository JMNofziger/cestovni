// Consumption math for the portal. A line-for-line port of
// client/lib/consumption/ (CES-38), without the Drift adapter.
//
// Spec: docs/specs/consumption-math.md
// Fixtures: tests/math/fixtures/
//
// Integer arithmetic only. Rounding is round-half-to-even at the final
// division. No DOM, no network.

export interface FillUp {
  id: string;
  vehicleId: string;
  filledAt: Date;
  odometerM: number;
  volumeUL: number;
  totalPriceCents: number;
  currencyCode: string;
  isFull: boolean;
  missedBefore: boolean;
  odometerReset: boolean;
  notes: string | null;
}

export type SegmentStatus =
  | 'known'
  | 'unknown_missed'
  | 'unknown_reset_boundary'
  | 'degenerate_zero_distance';

export interface SegmentOutcome {
  prevFullId: string;
  nextFullId: string;
  status: SegmentStatus;
  distanceM: number;
  volumeUL: number;
  costCents: number;
  closedAt: Date;
  lPer100kmTenths: number | null;
  centsPerKmTenths: number | null;
}

export interface LifetimeConsumption {
  lPer100kmTenths: number | null;
  totalDistanceM: number;
  totalVolumeUL: number;
  totalSpendCentsByCurrency: Record<string, number>;
}

export interface PricePoint {
  fillUpId: string;
  filledAt: Date;
  centsPerLitreTenths: number;
}

export const ValidationErrorCode = {
  odometerNegative: 'ODOMETER_NEGATIVE',
  volumeNegative: 'VOLUME_NEGATIVE',
  priceNegative: 'PRICE_NEGATIVE',
  filledAtInFuture: 'FILLED_AT_IN_FUTURE',
  odometerRegression: 'ODOMETER_REGRESSION',
  resetOnFirstFillup: 'RESET_ON_FIRST_FILLUP',
} as const;

export type ValidationErrorCode =
  (typeof ValidationErrorCode)[keyof typeof ValidationErrorCode];

export interface ValidationFailure {
  code: ValidationErrorCode;
}

function compareFillUps(a: FillUp, b: FillUp): number {
  const t = a.filledAt.getTime() - b.filledAt.getTime();
  if (t !== 0) return t;
  if (a.id < b.id) return -1;
  if (a.id > b.id) return 1;
  return 0;
}

function absBig(n: bigint): bigint {
  return n < 0n ? -n : n;
}

// Dart `~/` and JS BigInt `/` both truncate toward zero.
export function divideRoundHalfEven(numerator: bigint, denominator: bigint): number {
  if (denominator === 0n) {
    throw new Error('denominator must be non-zero');
  }

  const q = numerator / denominator;
  const r = numerator - q * denominator;
  if (r === 0n) return Number(q);

  const absR2 = absBig(r) * 2n;
  const absD = absBig(denominator);
  if (absR2 < absD) return Number(q);

  const stepSign = (numerator < 0n) !== (denominator < 0n) ? -1n : 1n;
  if (absR2 > absD) return Number(q + stepSign);

  const qEven = q % 2n === 0n;
  return Number(qEven ? q : q + stepSign);
}

export function computeSegments(fillUps: readonly FillUp[]): SegmentOutcome[] {
  const sorted = [...fillUps].sort(compareFillUps);
  if (sorted.length === 0) return [];

  const outcomes: SegmentOutcome[] = [];
  let prevFull: FillUp | null = null;
  const pendingPartials: FillUp[] = [];

  for (const f of sorted) {
    if (f.odometerReset) {
      prevFull = null;
      pendingPartials.length = 0;
      if (f.isFull) prevFull = f;
      else pendingPartials.push(f);
      continue;
    }

    if (prevFull === null) {
      if (f.isFull) prevFull = f;
      else pendingPartials.push(f);
      continue;
    }

    if (f.isFull) {
      outcomes.push(closeSegment(prevFull, f, [...pendingPartials, f]));
      prevFull = f;
      pendingPartials.length = 0;
    } else {
      pendingPartials.push(f);
    }
  }

  return outcomes;
}

function closeSegment(prevFull: FillUp, nextFull: FillUp, inclusive: readonly FillUp[]): SegmentOutcome {
  const distanceM = nextFull.odometerM - prevFull.odometerM;

  let volumeUL = 0n;
  let costCents = 0n;
  let hasMissed = false;
  for (const f of inclusive) {
    if (f.missedBefore) hasMissed = true;
    volumeUL += BigInt(f.volumeUL);
    // Same currency as the closing full. Other currencies stay in price history.
    if (f.currencyCode === nextFull.currencyCode) {
      costCents += BigInt(f.totalPriceCents);
    }
  }

  let status: SegmentStatus;
  if (hasMissed) status = 'unknown_missed';
  else if (distanceM === 0) status = 'degenerate_zero_distance';
  else if (distanceM < 0) status = 'unknown_reset_boundary';
  else status = 'known';

  const lPer100kmTenths =
    status === 'known' ? divideRoundHalfEven(volumeUL, BigInt(distanceM)) : null;
  const centsPerKmTenths =
    distanceM > 0 ? divideRoundHalfEven(costCents * 10000n, BigInt(distanceM)) : null;

  return {
    prevFullId: prevFull.id,
    nextFullId: nextFull.id,
    status,
    distanceM,
    volumeUL: Number(volumeUL),
    costCents: Number(costCents),
    closedAt: nextFull.filledAt,
    lPer100kmTenths,
    centsPerKmTenths,
  };
}

export function computeLifetime(
  segments: readonly SegmentOutcome[],
  allFillUps: readonly FillUp[] = [],
): LifetimeConsumption {
  let totalDistanceM = 0n;
  let totalVolumeUL = 0n;
  for (const s of segments) {
    if (s.status !== 'known') continue;
    totalDistanceM += BigInt(s.distanceM);
    totalVolumeUL += BigInt(s.volumeUL);
  }

  const lPer100kmTenths =
    totalDistanceM > 0n ? divideRoundHalfEven(totalVolumeUL, totalDistanceM) : null;

  const totalSpendCentsByCurrency: Record<string, number> = {};
  for (const f of allFillUps) {
    totalSpendCentsByCurrency[f.currencyCode] =
      (totalSpendCentsByCurrency[f.currencyCode] ?? 0) + f.totalPriceCents;
  }

  return {
    lPer100kmTenths,
    totalDistanceM: Number(totalDistanceM),
    totalVolumeUL: Number(totalVolumeUL),
    totalSpendCentsByCurrency,
  };
}

export function computePriceHistory(
  fillUps: readonly FillUp[],
): Record<string, PricePoint[]> {
  const sorted = [...fillUps].sort(compareFillUps);
  const result: Record<string, PricePoint[]> = {};

  for (const f of sorted) {
    if (f.volumeUL === 0) continue;
    const centsPerLitreTenths = divideRoundHalfEven(
      BigInt(f.totalPriceCents) * 10000000n,
      BigInt(f.volumeUL),
    );
    const list = result[f.currencyCode] ?? [];
    list.push({
      fillUpId: f.id,
      filledAt: f.filledAt,
      centsPerLitreTenths,
    });
    result[f.currencyCode] = list;
  }

  return result;
}

export function validateInsert(
  candidate: FillUp,
  existingForVehicle: readonly FillUp[],
  nowUtc: Date,
): ValidationFailure | null {
  if (candidate.odometerM < 0) return { code: ValidationErrorCode.odometerNegative };
  if (candidate.volumeUL < 0) return { code: ValidationErrorCode.volumeNegative };
  if (candidate.totalPriceCents < 0) return { code: ValidationErrorCode.priceNegative };

  const futureLimit = nowUtc.getTime() + 24 * 60 * 60 * 1000;
  if (candidate.filledAt.getTime() > futureLimit) {
    return { code: ValidationErrorCode.filledAtInFuture };
  }

  if (candidate.odometerReset && existingForVehicle.length === 0) {
    return { code: ValidationErrorCode.resetOnFirstFillup };
  }

  if (!candidate.odometerReset && existingForVehicle.length > 0) {
    const prev = latestInSameLineage(existingForVehicle, candidate);
    if (prev !== null && candidate.odometerM < prev.odometerM) {
      return { code: ValidationErrorCode.odometerRegression };
    }
  }

  return null;
}

function latestInSameLineage(existing: readonly FillUp[], candidate: FillUp): FillUp | null {
  const sorted = [...existing].sort(compareFillUps);
  let latest: FillUp | null = null;
  for (const f of sorted) {
    if (f.odometerReset) latest = null;
    const cmp = f.filledAt.getTime() - candidate.filledAt.getTime();
    if (cmp > 0 || (cmp === 0 && f.id >= candidate.id)) break;
    latest = f;
  }
  return latest;
}
