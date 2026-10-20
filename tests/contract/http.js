'use strict';

const path = require('path');
const jwt = require(path.join(__dirname, '../../server/api/node_modules/jsonwebtoken'));

function assert(cond, msg) {
  if (!cond) {
    throw new Error(msg);
  }
}

async function request(method, urlPath, { token, body, rawBody } = {}) {
  const headers = {};
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

function signUser(sub, extra = {}) {
  return jwt.sign({ sub, ...extra }, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    expiresIn: extra.exp ? undefined : '1h',
  });
}

module.exports = { assert, request, signUser };
