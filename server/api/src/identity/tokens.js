'use strict';

const crypto = require('crypto');

function randomToken() {
  return crypto.randomBytes(32).toString('base64url');
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest();
}

module.exports = { randomToken, sha256 };
