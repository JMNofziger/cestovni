// PWA-lite Phase 1 — offline Log + History. No sync push/pull (Phase 2).
// Spec: docs/specs/pwa-lite-v1.md §1–4 + §"Constraints from Android".
import {
  getAll,
  get,
  put,
  saveFillUpWithOutbox,
  outboxStates,
  fillUpsForVehicle,
} from './idb.js';
import { flushPush, syncNow } from './sync.js';

// ---------------------------------------------------------------------------
// SI conversion (docs/specs/si-units.md). Canonical = INT64 integers only.
// ---------------------------------------------------------------------------
const UL_PER_L = 1000000;
const UL_PER_GAL = 3785411784; // exact: 3.785411784 L × 1e6
const M_PER_KM = 1000;
const M_PER_MI = 1609.344; // exact

// Banker's rounding (round-half-to-even) to the nearest integer.
function bankersRound(value) {
  const floor = Math.floor(value);
  const diff = value - floor;
  if (diff < 0.5) return floor;
  if (diff > 0.5) return floor + 1;
  return floor % 2 === 0 ? floor : floor + 1;
}

function distanceToMeters(value, unit) {
  return bankersRound(value * (unit === 'mi' ? M_PER_MI : M_PER_KM));
}
function volumeToMicroliters(value, unit) {
  return bankersRound(value * (unit === 'gal' ? UL_PER_GAL : UL_PER_L));
}
function priceToCents(value) {
  return bankersRound(value * 100);
}

// Banker's rounding to N decimal places for display.
function roundDp(value, dp) {
  const factor = Math.pow(10, dp);
  return bankersRound(value * factor) / factor;
}
function metersToDisplay(m, unit) {
  const v = unit === 'mi' ? m / M_PER_MI : m / M_PER_KM;
  return roundDp(v, 0).toFixed(0);
}
function microlitersToDisplay(uL, unit) {
  const v = unit === 'gal' ? uL / UL_PER_GAL : uL / UL_PER_L;
  return roundDp(v, 2).toFixed(2);
}
function centsToDisplay(cents) {
  return roundDp(cents / 100, 2).toFixed(2);
}

// ---------------------------------------------------------------------------
// Validation — port of client/lib/consumption/validation.dart#validateInsert.
// ---------------------------------------------------------------------------
const ValidationErrorCode = {
  odometerNegative: 'Odometer cannot be negative.',
  volumeNegative: 'Volume cannot be negative.',
  priceNegative: 'Total price cannot be negative.',
  filledAtInFuture: 'Date/time cannot be more than 24h in the future.',
  resetOnFirstFillup: 'Odometer reset is not allowed on the first fill-up.',
  odometerRegression: 'Odometer is lower than a previous fill-up.',
};

// candidate: { id, filled_at, odometer_m, volume_uL, total_price_cents, odometer_reset }
// existing: array of fill_up rows for the same vehicle.
function validateInsert(candidate, existing, nowUtc) {
  if (candidate.odometer_m < 0) return ValidationErrorCode.odometerNegative;
  if (candidate.volume_uL < 0) return ValidationErrorCode.volumeNegative;
  if (candidate.total_price_cents < 0) return ValidationErrorCode.priceNegative;

  const futureLimit = new Date(nowUtc.getTime() + 24 * 3600 * 1000);
  if (new Date(candidate.filled_at) > futureLimit) {
    return ValidationErrorCode.filledAtInFuture;
  }
  if (candidate.odometer_reset && existing.length === 0) {
    return ValidationErrorCode.resetOnFirstFillup;
  }
  if (!candidate.odometer_reset && existing.length > 0) {
    const prev = latestInSameLineage(existing, candidate);
    if (prev && candidate.odometer_m < prev.odometer_m) {
      return ValidationErrorCode.odometerRegression;
    }
  }
  return null;
}

function latestInSameLineage(existing, candidate) {
  const sorted = existing.slice().sort((a, b) => {
    if (a.filled_at !== b.filled_at) return a.filled_at < b.filled_at ? -1 : 1;
    return a.id < b.id ? -1 : 1;
  });
  let latest = null;
  for (const f of sorted) {
    if (f.odometer_reset) latest = null;
    const sameTime = f.filled_at === candidate.filled_at;
    if (
      f.filled_at > candidate.filled_at ||
      (sameTime && f.id >= candidate.id)
    ) {
      break;
    }
    latest = f;
  }
  return latest;
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
const DEFAULT_SETTINGS = {
  id: 'singleton',
  preferred_distance_unit: 'km',
  preferred_volume_unit: 'L',
  currency_code: 'EUR',
  timezone: 'Europe/Prague',
};

const state = {
  settings: DEFAULT_SETTINGS,
  vehicles: [],
  activeVehicleId: null,
  tab: 'log',
};

function liveVehicles(rows) {
  return rows
    .filter((v) => !v.deleted_at && !v.archived_at)
    .sort((a, b) => (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

async function loadState() {
  const settings = await get('settings', 'singleton');
  state.settings = settings || DEFAULT_SETTINGS;
  if (!settings) await put('settings', DEFAULT_SETTINGS);
  state.vehicles = liveVehicles(await getAll('vehicles'));
  const stored = sessionStorage.getItem('cestovni_active_vehicle');
  if (stored && state.vehicles.some((v) => v.id === stored)) {
    state.activeVehicleId = stored;
  } else if (state.vehicles.length > 0) {
    state.activeVehicleId = state.vehicles[0].id;
  }
}

// Dev affordance (Phase 1 only): ?devseed=1 inserts a demo vehicle so offline
// Log/History can be smoke-tested before Phase 2 vehicle pull exists.
async function maybeDevSeed() {
  const params = new URLSearchParams(location.search);
  if (params.get('devseed') !== '1') return;
  const existing = await getAll('vehicles');
  if (existing.length > 0) return;
  await put('vehicles', {
    id: crypto.randomUUID(),
    name: 'Demo Car',
    fuel_type: 'petrol',
    archived_at: null,
    deleted_at: null,
  });
}

// ---------------------------------------------------------------------------
// Rendering
// ---------------------------------------------------------------------------
const $ = (sel) => document.querySelector(sel);

function setActiveVehicle(id) {
  state.activeVehicleId = id;
  sessionStorage.setItem('cestovni_active_vehicle', id);
  renderHeader();
  render();
}

function renderHeader() {
  const dateEl = $('#header-date');
  dateEl.textContent = new Date().toLocaleDateString('en-GB', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    timeZone: state.settings.timezone,
  });

  const sel = $('#vehicle-select');
  sel.innerHTML = '';
  for (const v of state.vehicles) {
    const opt = document.createElement('option');
    opt.value = v.id;
    opt.textContent = v.name;
    if (v.id === state.activeVehicleId) opt.selected = true;
    sel.appendChild(opt);
  }
  sel.disabled = state.vehicles.length === 0;
}

async function renderSyncLabel() {
  const { count } = await outboxStates();
  const el = $('#sync-label');
  const online = navigator.onLine !== false;
  // SYNCED / N PENDING / OFFLINE — N PENDING (spec §"Header label").
  if (count === 0) {
    el.textContent = 'SYNCED';
  } else if (online) {
    el.textContent = `${count} PENDING`;
  } else {
    el.textContent = `OFFLINE — ${count} PENDING`;
  }
}

function emptyVehicleState() {
  return `<div class="ledger-card empty-state">
    <p class="label-mono">No vehicles</p>
    <p>Add a vehicle in the Android app, then open Cestovni online once to sync.</p>
  </div>`;
}

function renderLog() {
  const app = $('#app');
  if (state.vehicles.length === 0) {
    app.innerHTML = emptyVehicleState();
    return;
  }
  const s = state.settings;
  const distLabel = s.preferred_distance_unit;
  const volLabel = s.preferred_volume_unit;
  const nowLocal = toLocalDatetimeValue(new Date());
  app.innerHTML = `
    <form id="log-form" class="ledger-card" novalidate>
      <label class="field">
        <span class="label-mono">Date / time</span>
        <input class="input" type="datetime-local" name="filled_at" value="${nowLocal}" required>
      </label>
      <label class="field">
        <span class="label-mono">Odometer (${distLabel})</span>
        <input class="input" type="number" name="odometer" inputmode="decimal" min="0" step="1" required>
      </label>
      <label class="field">
        <span class="label-mono">Volume (${volLabel})</span>
        <input class="input" type="number" name="volume" inputmode="decimal" min="0" step="0.01" required>
      </label>
      <label class="field">
        <span class="label-mono">Total price (${s.currency_code})</span>
        <input class="input" type="number" name="total_price" inputmode="decimal" min="0" step="0.01" required>
      </label>
      <label class="field-row">
        <span class="label-mono">Full fill</span>
        <input type="checkbox" name="is_full" checked>
      </label>
      <label class="field">
        <span class="label-mono">Notes</span>
        <textarea class="textarea" name="notes" maxlength="500" rows="2"></textarea>
      </label>
      <details class="advanced">
        <summary class="label-mono">Advanced</summary>
        <label class="field-row">
          <span>Missed fill-up before this one
            <em class="helper">Lowers consumption-quality for the next computed segment.</em></span>
          <input type="checkbox" name="missed_before">
        </label>
        <label class="field-row">
          <span>Odometer was reset
            <em class="helper">Starts a new odometer lineage; skips the regression check.</em></span>
          <input type="checkbox" name="odometer_reset">
        </label>
      </details>
      <p id="form-error" class="form-error" role="alert"></p>
      <p id="form-success" class="form-success" role="status"></p>
      <button type="submit" class="btn-primary">Save fill-up</button>
    </form>`;
  $('#log-form').addEventListener('submit', onSave);
}

async function renderHistory() {
  const app = $('#app');
  if (state.vehicles.length === 0) {
    app.innerHTML = emptyVehicleState();
    return;
  }
  const rows = await fillUpsForVehicle(state.activeVehicleId);
  if (rows.length === 0) {
    app.innerHTML = `<div class="ledger-card empty-state">
      <p class="label-mono">No fill-ups yet</p>
      <p>Log your first fill-up from the Log tab.</p>
    </div>`;
    return;
  }
  const { pending, dead } = await outboxStates();
  const s = state.settings;
  const vname =
    state.vehicles.find((v) => v.id === state.activeVehicleId)?.name || '';
  app.innerHTML = rows
    .map((r) => {
      const date = new Date(r.filled_at).toLocaleString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
        timeZone: s.timezone,
      });
      const pill = dead.has(r.id)
        ? '<span class="pill pill-bad">ERROR</span>'
        : pending.has(r.id)
          ? '<span class="pill pill-warn">PENDING</span>'
          : '<span class="pill pill-good">SYNCED</span>';
      return `<div class="ledger-tile history-row">
        <div class="history-top">
          <span class="label-mono">${date}</span>
          ${pill}
        </div>
        <div class="history-body">
          <span>${escapeHtml(vname)}</span>
          <span class="mono">${microlitersToDisplay(r.volume_uL, s.preferred_volume_unit)} ${s.preferred_volume_unit}</span>
          <span class="mono">${metersToDisplay(r.odometer_m, s.preferred_distance_unit)} ${s.preferred_distance_unit}</span>
          <span class="mono">${centsToDisplay(r.total_price_cents)} ${escapeHtml(r.currency_code)}</span>
        </div>
      </div>`;
    })
    .join('');
}

function render() {
  $('#tab-log').classList.toggle('active', state.tab === 'log');
  $('#tab-history').classList.toggle('active', state.tab === 'history');
  if (state.tab === 'log') renderLog();
  else renderHistory();
  renderSyncLabel();
}

// ---------------------------------------------------------------------------
// Save flow — spec §2 "Save flow" + §"Constraints from Android".
// ---------------------------------------------------------------------------
async function onSave(event) {
  event.preventDefault();
  const form = event.currentTarget;
  const errEl = $('#form-error');
  const okEl = $('#form-success');
  errEl.textContent = '';
  okEl.textContent = '';

  const fd = new FormData(form);
  const s = state.settings;

  const odometerInput = parseFloat(fd.get('odometer'));
  const volumeInput = parseFloat(fd.get('volume'));
  const priceInput = parseFloat(fd.get('total_price'));
  if (Number.isNaN(odometerInput) || Number.isNaN(volumeInput) || Number.isNaN(priceInput)) {
    errEl.textContent = 'Odometer, volume and total price are required.';
    return;
  }

  const id = crypto.randomUUID();
  const nowIso = new Date().toISOString();
  const filledAtIso = new Date(fd.get('filled_at')).toISOString();
  const notesRaw = (fd.get('notes') || '').toString().trim();

  // Full snake_case row payload (matches §Constraints from Android exactly).
  const payload = {
    id,
    vehicle_id: state.activeVehicleId,
    filled_at: filledAtIso,
    odometer_m: distanceToMeters(odometerInput, s.preferred_distance_unit),
    volume_uL: volumeToMicroliters(volumeInput, s.preferred_volume_unit),
    total_price_cents: priceToCents(priceInput),
    currency_code: s.currency_code,
    is_full: fd.get('is_full') === 'on',
    missed_before: fd.get('missed_before') === 'on',
    odometer_reset: fd.get('odometer_reset') === 'on',
    notes: notesRaw.length > 0 ? notesRaw : null,
    updated_at: nowIso,
    deleted_at: null,
    mutation_id: crypto.randomUUID(), // row-level id, distinct from outbox enqueue id
  };

  const existing = await fillUpsForVehicle(state.activeVehicleId);
  const failure = validateInsert(payload, existing, new Date());
  if (failure) {
    errEl.textContent = failure;
    return;
  }

  // Stored fill_up row = payload + server-hydrated columns (null until pull).
  const fillUpRow = { ...payload, user_id: null, row_version: null };

  const outboxRow = {
    mutation_id: crypto.randomUUID(), // outbox enqueue id, reused on retry (Phase 2)
    table: 'fill_ups',
    op: 'insert',
    row_id: id,
    payload_json: JSON.stringify(payload),
    enqueued_at: nowIso,
    attempts: 0,
    last_error: null,
  };

  try {
    await saveFillUpWithOutbox(fillUpRow, outboxRow);
  } catch (e) {
    errEl.textContent = 'Could not save locally. Try again.';
    return;
  }

  form.reset();
  $('input[name="filled_at"]', form) &&
    (form.querySelector('input[name="filled_at"]').value = toLocalDatetimeValue(new Date()));
  form.querySelector('input[name="is_full"]').checked = true;
  okEl.textContent = 'Saved — pending sync.';
  form.querySelector('input[name="odometer"]').focus();
  renderSyncLabel();

  // Offline-first: save never blocks on network. Flush opportunistically.
  if (navigator.onLine !== false) {
    flushPush({ onChange: onSyncChange });
  }
}

// Re-render the active surface + label after a sync drain/pull updates IDB.
async function onSyncChange() {
  await renderSyncLabel();
  if (state.tab === 'history') await renderHistory();
}

// Pull caches (vehicles/settings/fill_ups) then refresh vehicle picker, so the
// zero-vehicle empty state resolves once online without ?devseed=1.
async function onPullChange() {
  await loadState();
  renderHeader();
  render();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
function toLocalDatetimeValue(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

function escapeHtml(str) {
  return String(str).replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  }[c]));
}

function applyTheme(theme) {
  document.documentElement.setAttribute('data-theme', theme);
  localStorage.setItem('cestovni_theme', theme);
}

// ---------------------------------------------------------------------------
// Wiring
// ---------------------------------------------------------------------------
async function init() {
  applyTheme(localStorage.getItem('cestovni_theme') || 'dark');
  $('#theme-toggle').addEventListener('click', () => {
    const next =
      document.documentElement.getAttribute('data-theme') === 'dark'
        ? 'light'
        : 'dark';
    applyTheme(next);
  });

  $('#tab-log').addEventListener('click', () => {
    state.tab = 'log';
    render();
  });
  $('#tab-history').addEventListener('click', () => {
    state.tab = 'history';
    render();
  });
  $('#vehicle-select').addEventListener('change', (e) =>
    setActiveVehicle(e.target.value),
  );

  // Manual retry: tap the header sync label (no toast spam — spec §"Triggers").
  $('#sync-label').addEventListener('click', () => {
    syncNow({ onChange: onPullChange });
  });

  await maybeDevSeed();
  await loadState();
  renderHeader();
  render();

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('./sw.js').catch(() => {});
  }

  // Sync triggers: page load/foreground, regained connectivity (spec §"Triggers").
  syncNow({ onChange: onPullChange });
  window.addEventListener('online', () => syncNow({ onChange: onPullChange }));
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
      syncNow({ onChange: onPullChange });
    }
  });
}

init();
