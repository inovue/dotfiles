import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {
  aspectToFalSize,
  buildFalImageInput,
  GPT_IMAGE_EDIT_MODEL,
  GPT_IMAGE_GENERATE_MODEL,
} from '../src/fal.js';
import { PipelineValidationError } from '../src/validate.js';
import { inputToCliFlags, resolveGenmediaInvocation, formatDownloadFlag } from '../src/genmedia.js';

const MINI_PNG_B64 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

function writeMiniPng(dir: string, name: string): string {
  const file = path.join(dir, name);
  fs.writeFileSync(file, Buffer.from(MINI_PNG_B64, 'base64'));
  return file;
}

describe('aspectToFalSize', () => {
  test('maps supported fal aspect ratios', () => {
    assert.strictEqual(aspectToFalSize('16:9'), 'landscape_16_9');
    assert.strictEqual(aspectToFalSize('1:1'), 'square_hd');
    assert.deepStrictEqual(aspectToFalSize('1:1', true), { width: 2048, height: 2048 });
  });

  test('throws for unsupported aspect ratios', () => {
    for (const bad of ['21:9', '3:2', '2:3', '5:4' as const]) {
      assert.throws(() => aspectToFalSize(bad), PipelineValidationError);
    }
  });
});

describe('buildFalImageInput', () => {
  test('no refs → generate model, no image_urls yet', () => {
    const { modelId, input, refCount, refPaths } = buildFalImageInput('test prompt', { prompt: 'test prompt' });
    assert.strictEqual(modelId, GPT_IMAGE_GENERATE_MODEL);
    assert.strictEqual(refCount, 0);
    assert.deepStrictEqual(refPaths, []);
    assert.strictEqual(input.image_urls, undefined);
    assert.strictEqual(input.prompt, 'test prompt');
    assert.strictEqual(input.quality, 'medium');
  });

  test('single ref → edit model with local refPaths (upload deferred)', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fal-ref-'));
    const ref = writeMiniPng(dir, 'ref.png');

    const { modelId, input, refCount, refPaths } = buildFalImageInput('edit prompt', {
      prompt: 'edit prompt',
      refImages: [ref],
    });

    assert.strictEqual(modelId, GPT_IMAGE_EDIT_MODEL);
    assert.strictEqual(refCount, 1);
    assert.deepStrictEqual(refPaths, [ref]);
    assert.strictEqual(input.image_urls, undefined, 'upload happens at generate time via genmedia');
  });

  test('multiple refs → all existing paths kept (max 3)', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'fal-refs-'));
    const ref1 = writeMiniPng(dir, 'a.png');
    const ref2 = writeMiniPng(dir, 'b.png');

    const { modelId, refCount, refPaths } = buildFalImageInput('edit prompt', {
      prompt: 'edit prompt',
      refImages: [ref1, ref2],
    });

    assert.strictEqual(modelId, GPT_IMAGE_EDIT_MODEL);
    assert.strictEqual(refCount, 2);
    assert.deepStrictEqual(refPaths, [ref1, ref2]);
  });
});

describe('genmedia CLI helpers', () => {
  test('inputToCliFlags serializes objects and arrays as JSON', () => {
    const flags = inputToCliFlags({
      prompt: 'hello',
      num_images: 1,
      image_size: { width: 2048, height: 2048 },
      image_urls: ['https://example.com/a.png', 'https://example.com/b.png'],
    });
    assert.deepStrictEqual(flags, [
      '--prompt',
      'hello',
      '--num_images',
      '1',
      '--image_size',
      '{"width":2048,"height":2048}',
      '--image_urls',
      '["https://example.com/a.png","https://example.com/b.png"]',
    ]);
  });

  test('resolveGenmediaInvocation uses GENMEDIA_BIN when FAL_KEY cannot be hydrated', () => {
    const prevBin = process.env.GENMEDIA_BIN;
    const prevKey = process.env.FAL_KEY;
    // Non-bws / broken wrapper — hydrateFalKeyFromGenmediaBin fails, keep wrapper path
    process.env.GENMEDIA_BIN = 'nonexistent-wrapper run -- genmedia';
    delete process.env.FAL_KEY;
    try {
      assert.deepStrictEqual(resolveGenmediaInvocation(), {
        command: 'nonexistent-wrapper',
        prefixArgs: ['run', '--', 'genmedia'],
      });
    } finally {
      if (prevBin === undefined) delete process.env.GENMEDIA_BIN;
      else process.env.GENMEDIA_BIN = prevBin;
      if (prevKey === undefined) delete process.env.FAL_KEY;
      else process.env.FAL_KEY = prevKey;
    }
  });

  test('resolveGenmediaInvocation prefers bare genmedia when FAL_KEY is set', () => {
    const prevBin = process.env.GENMEDIA_BIN;
    const prevKey = process.env.FAL_KEY;
    process.env.GENMEDIA_BIN = 'bws run -- genmedia';
    process.env.FAL_KEY = 'test-key-not-real';
    try {
      assert.deepStrictEqual(resolveGenmediaInvocation(), {
        command: 'genmedia',
        prefixArgs: [],
      });
    } finally {
      if (prevBin === undefined) delete process.env.GENMEDIA_BIN;
      else process.env.GENMEDIA_BIN = prevBin;
      if (prevKey === undefined) delete process.env.FAL_KEY;
      else process.env.FAL_KEY = prevKey;
    }
  });

  test('formatDownloadFlag uses single --download=path argv', () => {
    const flag = formatDownloadFlag('/tmp/out/sheet.transparent.png');
    assert.strictEqual(flag, '--download=/tmp/out/sheet.transparent.png');
    assert.ok(!flag.includes(' '));
  });
});
