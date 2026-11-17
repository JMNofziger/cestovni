'use strict';

const {
  GoogleTokenInvalidError,
  LoginCodeInvalidError,
  OAuthStateInvalidError,
  RefreshInvalidError,
  consumeLoginCode,
  consumeOAuthState,
  createLoginCode,
  createOAuthState,
  findOrCreateUser,
  getUser,
  randomToken,
  refreshSession,
  revokeSession,
  sha256,
  startSession,
  sweepExpired,
} = require('./identity');
const {
  authRefreshLimiter,
  authSignInLimiter,
  authStartLimiter,
} = require('./rate-limit');

const AUTH_MAX_BODY = 1024;
const GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const CLIENTS = new Set(['android', 'portal']);

function clientIp(req, trustProxyHops) {
  const socketIp = (req.socket && req.socket.remoteAddress) || '';
  if (!trustProxyHops) return socketIp;
  const raw = req.headers['x-forwarded-for'];
  const header = Array.isArray(raw) ? raw.join(',') : raw;
  if (typeof header !== 'string' || header.length === 0) return socketIp;
  const parts = header.split(',').map((part) => part.trim()).filter(Boolean);
  if (parts.length < trustProxyHops) return socketIp;
  // hops=1 selects the rightmost entry, which the nearest proxy appended.
  return parts[parts.length - trustProxyHops];
}

function portalRedirect() {
  const value = process.env.AUTH_PORTAL_REDIRECT;
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    if (!url.host) return null;
    return value;
  } catch {
    return null;
  }
}

function androidRedirect() {
  return process.env.AUTH_ANDROID_REDIRECT || 'cestovni://auth/callback';
}

function allowlistedRedirect(client) {
  if (client === 'android') return androidRedirect();
  if (client === 'portal') return portalRedirect();
  return null;
}

function googleCallbackUri() {
  return `${process.env.AUTH_ISSUER_URL}/api/v1/auth/google/callback`;
}

function sessionBody(user, session) {
  return {
    user_id: user.id,
    email: user.email == null ? null : user.email,
    access_token: session.accessToken,
    token_type: 'Bearer',
    expires_in: 900,
    refresh_token: session.refreshToken,
    refresh_expires_in: 5184000,
  };
}

function createAuthRoutes({
  verifyIdToken,
  exchangeAuthCode,
  trustProxyHops,
  sendJson,
  sendError,
  readBody,
}) {
  function sendRedirect(res, base, key, value) {
    let url;
    try {
      url = new URL(base);
    } catch {
      sendError(res, 500, 'internal', 'internal error', true);
      return;
    }
    url.searchParams.set(key, value);
    res.writeHead(302, {
      Location: url.toString(),
      'Cache-Control': 'no-store',
    });
    res.end();
  }

  function rateLimited(req, res, limiter) {
    const quota = limiter.take(clientIp(req, trustProxyHops), 1);
    if (quota.ok) return false;
    req.resume();
    sendError(res, 429, 'rate_limited', 'rate limit exceeded', true, {
      'Retry-After': String(quota.retryAfter),
    });
    return true;
  }

  async function readAuthJson(req, res) {
    const declared = Number(req.headers['content-length'] || 0);
    if (Number.isFinite(declared) && declared > AUTH_MAX_BODY) {
      req.resume();
      sendError(res, 413, 'payload_too_large', 'body exceeds 1 KiB', false);
      return null;
    }
    let raw;
    try {
      raw = await readBody(req, AUTH_MAX_BODY);
    } catch (err) {
      if (err.status === 413) {
        sendError(res, 413, 'payload_too_large', 'body exceeds 1 KiB', false);
        return null;
      }
      throw err;
    }
    let body;
    try {
      body = JSON.parse(raw.toString('utf8') || '');
    } catch {
      sendError(res, 400, 'bad_request', 'invalid JSON body', false);
      return null;
    }
    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      sendError(res, 400, 'bad_request', 'invalid JSON body', false);
      return null;
    }
    return body;
  }

  function stringField(body, name) {
    const value = body[name];
    if (typeof value !== 'string') return null;
    return value;
  }

  async function issueSession(res, googleSub, email) {
    const user = await findOrCreateUser({ googleSub, email });
    const session = await startSession(user.id);
    return sendJson(res, 200, sessionBody(user, session));
  }

  async function handleStart(req, res, url) {
    if (rateLimited(req, res, authStartLimiter)) return;
    const client = url.searchParams.get('client');
    if (!CLIENTS.has(client)) {
      sendError(res, 400, 'bad_request', 'client must be android or portal', false);
      return;
    }
    if (client === 'portal' && !portalRedirect()) {
      sendError(res, 400, 'bad_request', 'portal redirect is not configured', false);
      return;
    }
    await sweepExpired();
    const nonce = randomToken();
    const codeVerifier = randomToken();
    const state = await createOAuthState({ client, nonce, codeVerifier });
    const target = new URL(GOOGLE_AUTH_URL);
    target.searchParams.set('client_id', process.env.GOOGLE_CLIENT_ID);
    target.searchParams.set('redirect_uri', googleCallbackUri());
    target.searchParams.set('response_type', 'code');
    target.searchParams.set('scope', 'openid email');
    target.searchParams.set('state', state);
    target.searchParams.set('nonce', nonce);
    target.searchParams.set('code_challenge', sha256(codeVerifier).toString('base64url'));
    target.searchParams.set('code_challenge_method', 'S256');
    target.searchParams.set('prompt', 'select_account');
    res.writeHead(302, {
      Location: target.toString(),
      'Cache-Control': 'no-store',
    });
    res.end();
  }

  async function handleCallback(req, res, url) {
    const state = url.searchParams.get('state');
    if (typeof state !== 'string' || state.length === 0) {
      sendError(res, 400, 'oauth_state_invalid', 'oauth state invalid', false);
      return;
    }
    let consumed;
    try {
      consumed = await consumeOAuthState(state);
    } catch (err) {
      if (err instanceof OAuthStateInvalidError) {
        sendError(res, 400, 'oauth_state_invalid', 'oauth state invalid', false);
        return;
      }
      throw err;
    }
    const target = allowlistedRedirect(consumed.client);
    if (!target) {
      sendError(res, 500, 'internal', 'internal error', true);
      return;
    }
    if (url.searchParams.get('error')) {
      sendRedirect(res, target, 'error', 'access_denied');
      return;
    }
    let identity;
    try {
      const idToken = await exchangeAuthCode({
        code: url.searchParams.get('code'),
        codeVerifier: consumed.codeVerifier,
        redirectUri: googleCallbackUri(),
      });
      identity = await verifyIdToken(idToken, { nonce: consumed.nonce });
    } catch {
      sendRedirect(res, target, 'error', 'google_token_invalid');
      return;
    }
    const code = await createLoginCode({
      googleSub: identity.googleSub,
      email: identity.email,
    });
    sendRedirect(res, target, 'code', code);
  }

  async function handleGoogle(req, res) {
    if (rateLimited(req, res, authSignInLimiter)) return;
    const body = await readAuthJson(req, res);
    if (!body) return;
    const idToken = stringField(body, 'id_token');
    if (idToken == null) {
      sendError(res, 400, 'bad_request', 'id_token must be a string', false);
      return;
    }
    let identity;
    try {
      identity = await verifyIdToken(idToken);
    } catch (err) {
      if (err instanceof GoogleTokenInvalidError) {
        sendError(res, 401, 'google_token_invalid', 'google token invalid', false);
        return;
      }
      throw err;
    }
    await issueSession(res, identity.googleSub, identity.email);
  }

  async function handleExchange(req, res) {
    if (rateLimited(req, res, authSignInLimiter)) return;
    const body = await readAuthJson(req, res);
    if (!body) return;
    const code = stringField(body, 'code');
    if (code == null) {
      sendError(res, 400, 'bad_request', 'code must be a string', false);
      return;
    }
    await sweepExpired();
    let login;
    try {
      login = await consumeLoginCode(code);
    } catch (err) {
      if (err instanceof LoginCodeInvalidError) {
        sendError(res, 400, 'login_code_invalid', 'login code invalid', false);
        return;
      }
      throw err;
    }
    await issueSession(res, login.googleSub, login.email);
  }

  async function handleRefresh(req, res) {
    if (rateLimited(req, res, authRefreshLimiter)) return;
    const body = await readAuthJson(req, res);
    if (!body) return;
    const refreshToken = stringField(body, 'refresh_token');
    if (refreshToken == null) {
      sendError(res, 400, 'bad_request', 'refresh_token must be a string', false);
      return;
    }
    let next;
    try {
      next = await refreshSession(refreshToken);
    } catch (err) {
      if (err instanceof RefreshInvalidError) {
        sendError(res, 401, 'refresh_invalid', 'refresh token invalid', false);
        return;
      }
      throw err;
    }
    const user = await getUser(next.userId);
    if (!user) {
      sendError(res, 500, 'internal', 'internal error', true);
      return;
    }
    sendJson(res, 200, sessionBody(user, next));
  }

  async function handleLogout(req, res) {
    const body = await readAuthJson(req, res);
    if (!body) return;
    const refreshToken = stringField(body, 'refresh_token');
    if (refreshToken == null) {
      sendError(res, 400, 'bad_request', 'refresh_token must be a string', false);
      return;
    }
    await revokeSession(refreshToken);
    res.writeHead(204, { 'Cache-Control': 'no-store' });
    res.end();
  }

  return async function handleAuth(req, res, url) {
    if (req.method === 'GET' && url.pathname === '/api/v1/auth/google/start') {
      await handleStart(req, res, url);
      return true;
    }
    if (req.method === 'GET' && url.pathname === '/api/v1/auth/google/callback') {
      await handleCallback(req, res, url);
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/api/v1/auth/google') {
      await handleGoogle(req, res);
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/api/v1/auth/google/exchange') {
      await handleExchange(req, res);
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/api/v1/auth/refresh') {
      await handleRefresh(req, res);
      return true;
    }
    if (req.method === 'POST' && url.pathname === '/api/v1/auth/logout') {
      await handleLogout(req, res);
      return true;
    }
    return false;
  };
}

module.exports = { createAuthRoutes };
