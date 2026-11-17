'use strict';

// Fixed window, in memory. Mutation and changes windows are one minute.
// Auth windows are longer and keyed by client IP. A reservation that does
// not fit is denied and does not consume quota. Not shared across processes.

function intEnv(name, fallback) {
  const raw = process.env[name];
  if (raw == null || raw === '') return fallback;
  const n = Number(raw);
  if (!Number.isInteger(n) || n < 1) {
    throw new Error(`${name} must be a positive integer`);
  }
  return n;
}

class FixedWindowLimiter {
  constructor(limit, windowMs = 60_000) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.buckets = new Map();
  }

  take(key, n) {
    const now = Date.now();
    let bucket = this.buckets.get(key);
    if (!bucket || now >= bucket.resetAt) {
      bucket = { count: 0, resetAt: now + this.windowMs };
      this.buckets.set(key, bucket);
    }
    if (bucket.count + n > this.limit) {
      const retryAfter = Math.max(1, Math.ceil((bucket.resetAt - now) / 1000));
      return { ok: false, retryAfter };
    }
    bucket.count += n;
    if (this.buckets.size > 10_000) this.prune(now);
    return { ok: true };
  }

  prune(now) {
    for (const [key, bucket] of this.buckets) {
      if (now >= bucket.resetAt) this.buckets.delete(key);
    }
  }
}

const mutationsPerMin = intEnv('RATE_LIMIT_MUTATIONS_PER_MIN', 60);
const changesPerMin = intEnv('RATE_LIMIT_CHANGES_PER_MIN', 120);

const mutationLimiter = new FixedWindowLimiter(mutationsPerMin);
const changesLimiter = new FixedWindowLimiter(changesPerMin);

const FIFTEEN_MIN_MS = 15 * 60 * 1000;
const SIXTY_MIN_MS = 60 * 60 * 1000;

// POST /auth/google and POST /auth/google/exchange share one bucket.
const authSignInLimiter = new FixedWindowLimiter(20, FIFTEEN_MIN_MS);
const authStartLimiter = new FixedWindowLimiter(30, FIFTEEN_MIN_MS);
const authRefreshLimiter = new FixedWindowLimiter(60, SIXTY_MIN_MS);

module.exports = {
  mutationLimiter,
  changesLimiter,
  mutationsPerMin,
  changesPerMin,
  authSignInLimiter,
  authStartLimiter,
  authRefreshLimiter,
};
