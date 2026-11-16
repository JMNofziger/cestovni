'use strict';

class RefreshInvalidError extends Error {
  constructor() {
    super('refresh_invalid');
    this.name = 'RefreshInvalidError';
  }
}

class OAuthStateInvalidError extends Error {
  constructor() {
    super('oauth_state_invalid');
    this.name = 'OAuthStateInvalidError';
  }
}

class LoginCodeInvalidError extends Error {
  constructor() {
    super('login_code_invalid');
    this.name = 'LoginCodeInvalidError';
  }
}

class GoogleTokenInvalidError extends Error {
  constructor() {
    super('google_token_invalid');
    this.name = 'GoogleTokenInvalidError';
  }
}

module.exports = {
  RefreshInvalidError,
  OAuthStateInvalidError,
  LoginCodeInvalidError,
  GoogleTokenInvalidError,
};
