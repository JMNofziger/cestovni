import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

import {
  computeLifetime,
  computePriceHistory,
  computeSegments,
  validateInsert,
  type FillUp,
} from '../src/consumption.ts';

const fixturesDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../../tests/math/fixtures',
);

interface FixtureFillUp {
  id: string;
  vehicle_id: string;
  filled_at: string;
  odometer_m: number;
  volume_uL: number;
  total_price_cents: number;
  currency_code: string;
  is_full: boolean;
  missed_before?: boolean;
  odometer_reset?: boolean;
  notes?: string | null;
}

function parseFillUp(raw: FixtureFillUp): FillUp {
  return {
    id: raw.id,
    vehicleId: raw.vehicle_id,
    filledAt: new Date(raw.filled_at),
    odometerM: raw.odometer_m,
    volumeUL: raw.volume_uL,
    totalPriceCents: raw.total_price_cents,
    currencyCode: raw.currency_code,
    isFull: raw.is_full,
    missedBefore: raw.missed_before ?? false,
    odometerReset: raw.odometer_reset ?? false,
    notes: raw.notes ?? null,
  };
}

function sameInstant(actual: Date, iso: string): boolean {
  return actual.getTime() === Date.parse(iso);
}

function failField(fixture: string, field: string, actual: unknown, expected: unknown): never {
  const message =
    `${fixture}: ${field}\n` +
    `  actual:   ${JSON.stringify(actual)}\n` +
    `  expected: ${JSON.stringify(expected)}`;
  console.error(message);
  assert.fail(message);
}

function expectEqual(fixture: string, field: string, actual: unknown, expected: unknown): void {
  if (!Object.is(actual, expected)) failField(fixture, field, actual, expected);
}

interface Fixture {
  name?: string;
  input: {
    fillups: FixtureFillUp[];
    candidate?: FixtureFillUp;
    now_utc?: string;
  };
  expected: {
    kind: string;
    segments?: Array<Record<string, unknown>>;
    lifetime?: {
      l_per_100km_tenths: number | null;
      total_distance_m: number;
      total_volume_uL: number;
      total_spend_cents_by_currency: Record<string, number>;
    };
    price_history_by_currency?: Record<
      string,
      Array<{ fillup_id: string; filled_at: string; cents_per_litre_tenths: number }>
    >;
    validation?: { rejected: boolean; error_code: string | null };
  };
}

function assertSegments(file: string, fixture: Fixture): void {
  const fillUps = fixture.input.fillups.map(parseFillUp);
  const segments = computeSegments(fillUps);
  const lifetime = computeLifetime(segments, fillUps);
  const expected = fixture.expected;
  const wantSegments = expected.segments ?? [];

  expectEqual(file, 'segment count', segments.length, wantSegments.length);
  for (let i = 0; i < segments.length; i += 1) {
    const actual = segments[i];
    const want = wantSegments[i];
    expectEqual(file, `segment[${i}].prev_full_id`, actual.prevFullId, want.prev_full_id);
    expectEqual(file, `segment[${i}].next_full_id`, actual.nextFullId, want.next_full_id);
    expectEqual(file, `segment[${i}].status`, actual.status, want.status);
    expectEqual(file, `segment[${i}].distance_m`, actual.distanceM, want.distance_m);
    expectEqual(file, `segment[${i}].volume_uL`, actual.volumeUL, want.volume_uL);
    expectEqual(file, `segment[${i}].cost_cents`, actual.costCents, want.cost_cents);
    expectEqual(file, `segment[${i}].l_per_100km_tenths`, actual.lPer100kmTenths, want.l_per_100km_tenths);
    expectEqual(
      file,
      `segment[${i}].cents_per_km_tenths`,
      actual.centsPerKmTenths,
      want.cents_per_km_tenths,
    );
    const closedAt = want.closed_at;
    if (typeof closedAt !== 'string' || !sameInstant(actual.closedAt, closedAt)) {
      failField(file, `segment[${i}].closed_at`, actual.closedAt.toISOString(), closedAt);
    }
  }

  const wantLife = expected.lifetime;
  if (!wantLife) failField(file, 'lifetime', null, 'object');
  expectEqual(file, 'lifetime.l_per_100km_tenths', lifetime.lPer100kmTenths, wantLife.l_per_100km_tenths);
  expectEqual(file, 'lifetime.total_distance_m', lifetime.totalDistanceM, wantLife.total_distance_m);
  expectEqual(file, 'lifetime.total_volume_uL', lifetime.totalVolumeUL, wantLife.total_volume_uL);

  const wantSpend = wantLife.total_spend_cents_by_currency;
  const spendKeys = Object.keys(lifetime.totalSpendCentsByCurrency).sort();
  const wantKeys = Object.keys(wantSpend).sort();
  expectEqual(file, 'lifetime spend currencies', spendKeys.join(','), wantKeys.join(','));
  for (const currency of wantKeys) {
    expectEqual(
      file,
      `lifetime.total_spend[${currency}]`,
      lifetime.totalSpendCentsByCurrency[currency],
      wantSpend[currency],
    );
  }

  const wantHistory = expected.price_history_by_currency;
  if (wantHistory) {
    const history = computePriceHistory(fillUps);
    expectEqual(
      file,
      'price_history currencies',
      Object.keys(history).sort().join(','),
      Object.keys(wantHistory).sort().join(','),
    );
    for (const currency of Object.keys(wantHistory)) {
      const actualList = history[currency];
      const wantList = wantHistory[currency];
      if (!actualList) failField(file, `price_history[${currency}]`, null, wantList);
      expectEqual(file, `price_history[${currency}] count`, actualList.length, wantList.length);
      for (let i = 0; i < wantList.length; i += 1) {
        expectEqual(file, `price_history[${currency}][${i}].fillup_id`, actualList[i].fillUpId, wantList[i].fillup_id);
        if (!sameInstant(actualList[i].filledAt, wantList[i].filled_at)) {
          failField(
            file,
            `price_history[${currency}][${i}].filled_at`,
            actualList[i].filledAt.toISOString(),
            wantList[i].filled_at,
          );
        }
        expectEqual(
          file,
          `price_history[${currency}][${i}].cents_per_litre_tenths`,
          actualList[i].centsPerLitreTenths,
          wantList[i].cents_per_litre_tenths,
        );
      }
    }
  }

  if (expected.validation) {
    expectEqual(file, 'validation.rejected', expected.validation.rejected, false);
  }
}

function assertRejection(file: string, fixture: Fixture): void {
  const existing = fixture.input.fillups.map(parseFillUp);
  if (!fixture.input.candidate) failField(file, 'candidate', null, 'fill-up');
  if (!fixture.input.now_utc) failField(file, 'now_utc', null, 'timestamp');
  const candidate = parseFillUp(fixture.input.candidate);
  const result = validateInsert(candidate, existing, new Date(fixture.input.now_utc));
  const want = fixture.expected.validation;
  if (!want) failField(file, 'validation', null, 'object');
  expectEqual(file, 'validation.rejected', want.rejected, true);
  if (!result) failField(file, 'error_code', null, want.error_code);
  expectEqual(file, 'error_code', result.code, want.error_code);
}

const files = readdirSync(fixturesDir)
  .filter((name) => name.endsWith('.json'))
  .sort();

test('fixture directory has the shipped set', () => {
  assert.ok(files.length >= 20, `expected at least 20 fixtures, found ${files.length}`);
});

for (const name of files) {
  test(`fixture ${name}`, () => {
    const fixture = JSON.parse(readFileSync(path.join(fixturesDir, name), 'utf8')) as Fixture;
    const kind = fixture.expected.kind;
    if (kind === 'segments') assertSegments(name, fixture);
    else if (kind === 'validation_rejection') assertRejection(name, fixture);
    else failField(name, 'expected.kind', kind, 'segments | validation_rejection');
  });
}
