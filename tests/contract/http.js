'use strict';

const crypto = require('crypto');
const { fakeIdToken } = require('./fake-google');

function assert(cond, msg) {
  if (!cond) {
    throw new Error(msg);
  }
}

function forwardedFor() {
  const octet = () => crypto.randomInt(1, 255);
  return `10.${octet()}.${octet()}.${octet()}`;
}

async function request(method, urlPath, { token, body, rawBody, headers: extra } = {}) {
  const headers = { ...(extra || {}) };
  if (token != null) headers.Authorization = `Bearer ${token}`;
  let payload;
  if (rawBody !== undefined) {
    payload = rawBody;
    headers['Content-Type'] = 'application/json';
  } else if (body !== undefined) {
    payload = JSON.stringify(body);
    headers['Content-Type'] = 'application/json';
  }
  const res = await fetch(new URL(urlPath, process.env.API_BASE_URL), {
    method,
    headers,
    body: payload,
  });
  const text = await res.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch (_) {
      json = null;
    }
  }
  return { status: res.status, headers: res.headers, json, text };
}

async function signUser(googleSub) {
  const res = await request('POST', '/api/v1/auth/google', {
    headers: { 'X-Forwarded-For': forwardedFor() },
    body: {
      id_token: fakeIdToken({
        sub: googleSub,
        email: `${googleSub}@example.test`,
      }),
    },
  });
  if (res.status !== 200 || !res.json || typeof res.json.access_token !== 'string') {
    throw new Error(`sign-in failed: ${res.status}`);
  }
  return {
    token: res.json.access_token,
    userId: res.json.user_id,
    refreshToken: res.json.refresh_token,
  };
}

module.exports = { assert, request, signUser };
