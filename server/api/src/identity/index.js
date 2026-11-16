'use strict';

const {
  RefreshInvalidError,
  OAuthStateInvalidError,
  LoginCodeInvalidError,
  GoogleTokenInvalidError,
} = require('./errors');
const { randomToken, sha256 } = require('./tokens');
const { withAuthRole, checkIdentityReady } = require('./db');
const { createGoogleVerifier, exchangeAuthCode } = require('./google');
const { findOrCreateUser, getUser } = require('./users');
const {
  mintAccessToken,
  startSession,
  refreshSession,
  revokeSession,
  sessionIsActive,
} = require('./sessions');
const {
  createOAuthState,
  consumeOAuthState,
  createLoginCode,
  consumeLoginCode,
  sweepExpired,
} = require('./codes');

module.exports = {
  RefreshInvalidError,
  OAuthStateInvalidError,
  LoginCodeInvalidError,
  GoogleTokenInvalidError,
  randomToken,
  sha256,
  withAuthRole,
  checkIdentityReady,
  createGoogleVerifier,
  exchangeAuthCode,
  findOrCreateUser,
  getUser,
  mintAccessToken,
  startSession,
  refreshSession,
  revokeSession,
  sessionIsActive,
  createOAuthState,
  consumeOAuthState,
  createLoginCode,
  consumeLoginCode,
  sweepExpired,
};
