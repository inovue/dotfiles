import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { isNonRetryableGenmediaError, hasGenmediaSavedKey } from '../src/genmedia.js';
import { writePipelineFailedMarker } from '../src/fail-marker.js';

function err(message: string): Error {
  return new Error(message);
}

describe('isNonRetryableGenmediaError', () => {
  describe('non-retryable: validation / 422', () => {
    test('422 Unprocessable Entity', () => {
      assert.equal(isNonRetryableGenmediaError(err('HTTP 422 Unprocessable Entity')), true);
    });

    test('Field required', () => {
      assert.equal(
        isNonRetryableGenmediaError(err('genmedia run failed: Field required: image_urls')),
        true,
      );
    });

    test('case-insensitive unprocessable', () => {
      assert.equal(isNonRetryableGenmediaError(err('UNPROCESSABLE content')), true);
    });
  });

  describe('non-retryable: auth', () => {
    test('401 Unauthorized', () => {
      assert.equal(isNonRetryableGenmediaError(err('401 Unauthorized')), true);
    });

    test('403 Forbidden', () => {
      assert.equal(isNonRetryableGenmediaError(err('403 Forbidden')), true);
    });

    test('invalid_auth', () => {
      assert.equal(isNonRetryableGenmediaError(err('invalid_auth: bad key')), true);
    });

    test('case-insensitive forbidden', () => {
      assert.equal(isNonRetryableGenmediaError(err('FORBIDDEN access')), true);
    });
  });

  describe('non-retryable: content policy', () => {
    test('content policy', () => {
      assert.equal(isNonRetryableGenmediaError(err('Request blocked by content policy')), true);
    });

    test('content-policy hyphenated', () => {
      assert.equal(isNonRetryableGenmediaError(err('content-policy violation')), true);
    });

    test('safety / moderation / nsfw', () => {
      assert.equal(isNonRetryableGenmediaError(err('safety filter triggered')), true);
      assert.equal(isNonRetryableGenmediaError(err('moderation rejected')), true);
      assert.equal(isNonRetryableGenmediaError(err('nsfw content detected')), true);
    });
  });

  describe('non-retryable: setup / missing resources', () => {
    test('model not found', () => {
      assert.equal(isNonRetryableGenmediaError(err('model not found: bad/endpoint')), true);
    });

    test('GENMEDIA_BIN is empty', () => {
      assert.equal(isNonRetryableGenmediaError(err('GENMEDIA_BIN is empty')), true);
    });

    test('genmedia CLI is not available', () => {
      assert.equal(
        isNonRetryableGenmediaError(err('[ERROR] genmedia CLI is not available.')),
        true,
      );
    });

    test('genmedia auth is not configured', () => {
      assert.equal(
        isNonRetryableGenmediaError(err('[ERROR] genmedia auth is not configured.')),
        true,
      );
    });
  });

  describe('retryable: transient errors', () => {
    test('429 rate limit', () => {
      assert.equal(isNonRetryableGenmediaError(err('429 Too Many Requests')), false);
    });

    test('5xx server errors', () => {
      assert.equal(isNonRetryableGenmediaError(err('500 Internal Server Error')), false);
      assert.equal(isNonRetryableGenmediaError(err('503 Service Unavailable')), false);
    });

    test('timeout', () => {
      assert.equal(isNonRetryableGenmediaError(err('request timeout after 60000ms')), false);
    });

    test('ECONNRESET', () => {
      assert.equal(isNonRetryableGenmediaError(err('read ECONNRESET')), false);
    });
  });

  describe('retryable: unknown / generic errors', () => {
    test('generic failure', () => {
      assert.equal(isNonRetryableGenmediaError(err('something went wrong')), false);
    });

    test('non-Error values', () => {
      assert.equal(isNonRetryableGenmediaError('422 bad'), true);
      assert.equal(isNonRetryableGenmediaError('network glitch'), false);
    });
  });

  describe('retryable wins over non-retryable substrings', () => {
    test('503 takes precedence when both patterns could match context', () => {
      assert.equal(isNonRetryableGenmediaError(err('503 upstream error')), false);
    });
  });
});

describe('hasGenmediaSavedKey', () => {
  test('accepts known key fields with non-empty strings', () => {
    assert.equal(hasGenmediaSavedKey({ api_key: 'sk-test' }), true);
    assert.equal(hasGenmediaSavedKey({ apiKey: 'sk-test' }), true);
    assert.equal(hasGenmediaSavedKey({ fal_key: 'sk-test' }), true);
    assert.equal(hasGenmediaSavedKey({ falKey: 'sk-test' }), true);
    assert.equal(hasGenmediaSavedKey({ encrypted_api_key: 'enc' }), true);
    assert.equal(hasGenmediaSavedKey({ encryptedApiKey: 'enc' }), true);
    assert.equal(hasGenmediaSavedKey({ key: 'sk-test' }), true);
  });

  test('rejects empty, whitespace-only, or missing key fields', () => {
    assert.equal(hasGenmediaSavedKey({}), false);
    assert.equal(hasGenmediaSavedKey({ api_key: '' }), false);
    assert.equal(hasGenmediaSavedKey({ api_key: '   ' }), false);
    assert.equal(hasGenmediaSavedKey({ other: 'value' }), false);
    assert.equal(hasGenmediaSavedKey(null), false);
    assert.equal(hasGenmediaSavedKey([]), false);
    assert.equal(hasGenmediaSavedKey('not-an-object'), false);
  });
});

describe('writePipelineFailedMarker', () => {
  test('writes manifest.failed.json with status and extra fields', () => {
    const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'fail-marker-'));
    writePipelineFailedMarker(outDir, new Error('rembg timeout'), {
      batchId: 'asset_test',
      stage: 'rembg',
    });

    const markerPath = path.join(outDir, 'manifest.failed.json');
    assert.equal(fs.existsSync(markerPath), true);
    const marker = JSON.parse(fs.readFileSync(markerPath, 'utf-8'));
    assert.equal(marker.status, 'failed');
    assert.equal(marker.error, 'rembg timeout');
    assert.equal(marker.batchId, 'asset_test');
    assert.equal(marker.stage, 'rembg');
    assert.match(marker.createdAt, /^\d{4}-\d{2}-\d{2}T/);
  });
});
