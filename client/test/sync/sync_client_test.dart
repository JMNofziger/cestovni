import 'dart:convert';

import 'package:cestovni/sync/sync_client.dart';
import 'package:cestovni/sync/sync_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('getChanges and getRestoreManifest parse the CES-43 bodies', () async {
    final mock = MockClient((req) async {
      expect(req.headers['authorization'], 'Bearer jwt-from-runtime');
      if (req.url.path == '/api/v1/changes') {
        expect(req.url.queryParameters['table'], 'vehicles');
        expect(req.url.queryParameters['since'], '4');
        expect(req.url.queryParameters['limit'], '2');
        return http.Response(
          jsonEncode({
            'table': 'vehicles',
            'rows': [
              {'id': 'v', 'row_version': 5},
            ],
            'next_since': 5,
            'has_more': false,
          }),
          200,
          headers: {'x-limit-clamped': 'true'},
        );
      }
      expect(req.url.path, '/api/v1/restore/manifest');
      return http.Response(
        jsonEncode({
          'tables': [
            {'table': 'vehicles', 'row_count': 1, 'max_row_version': 5},
            {'table': 'settings', 'row_count': 0, 'max_row_version': 0},
          ],
        }),
        200,
      );
    });
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 'compile-time',
      tokenProvider: () => 'jwt-from-runtime',
      httpClient: mock,
    );
    addTearDown(client.close);

    final page = await client.getChanges(table: 'vehicles', since: 4, limit: 2);
    expect(page.rows, hasLength(1));
    expect(page.rows.single['row_version'], 5);
    expect(page.nextSince, 5);
    expect(page.hasMore, isFalse);
    expect(page.limitClamped, isTrue);

    final manifest = await client.getRestoreManifest();
    expect(manifest.tables, hasLength(2));
    expect(manifest.tables.first.rowCount, 1);
    expect(manifest.tables.first.maxRowVersion, 5);
    expect(manifest.tables.last.table, 'settings');
  });

  test('429 surfaces Retry-After seconds', () async {
    final mock = MockClient(
      (req) async => http.Response('no', 429, headers: {'retry-after': '12'}),
    );
    final client = SyncClient(
      baseUrl: 'http://127.0.0.1:8080',
      bearerToken: 't',
      httpClient: mock,
    );
    addTearDown(client.close);
    await expectLater(
      client.getRestoreManifest(),
      throwsA(
        isA<SyncHttpError>()
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.retriable, 'retriable', isTrue)
            .having((e) => e.retryAfterSeconds, 'retry', 12),
      ),
    );
  });

  test('copyWithToken replaces the compile-time bearer', () {
    const cfg = SyncConfig(baseUrl: 'http://127.0.0.1:8080', bearerToken: 'dev');
    final next = cfg.copyWithToken('header.payload.sig');
    expect(next.baseUrl, cfg.baseUrl);
    expect(next.bearerToken, 'header.payload.sig');
    expect(next.isConfigured, isTrue);
    expect(const SyncConfig(baseUrl: '', bearerToken: '').isConfigured, isFalse);
  });
}
