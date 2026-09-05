import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {
  ItemsParseError,
  extractLeadingId,
  parseCellSpecs,
  validateGenerationGate,
  validateGridCells,
} from '../src/items.js';

describe('items parser (strict, file-first)', () => {
  test('parses JSON array via @file', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asset-items-'));
    const file = path.join(dir, 'cells.json');
    fs.writeFileSync(file, JSON.stringify(['Cell A', 'Cell B', 'Cell C', 'Cell D']));

    const items = parseCellSpecs(undefined, `@${file}`, dir);
    assert.strictEqual(items.length, 4);
    assert.strictEqual(items[0].prompt, 'Cell A');
  });

  test('parses inline JSON array on Linux/macOS', () => {
    const specs = parseCellSpecs(undefined, '["a","b","c","d"]');
    assert.strictEqual(specs.length, 4);
    assert.strictEqual(specs[0].prompt, 'a');
  });

  test('parses { id, prompt } objects', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asset-items-'));
    const file = path.join(dir, 'cells.json');
    fs.writeFileSync(
      file,
      JSON.stringify([
        { id: 'window_bevel', prompt: 'FINANCIAL / FANTASY wordmark with bevel frame' },
        { id: 'crystal_flat', prompt: 'Flat crystal wordmark' },
        { id: 'minimal', prompt: 'Minimal vector logo' },
        { id: 'neon', prompt: 'Neon arcade title' },
      ]),
    );

    const specs = parseCellSpecs(undefined, `@${file}`, dir);
    assert.strictEqual(specs[0].id, 'window_bevel');
    assert.ok(specs[0].prompt.includes('FINANCIAL'));
  });

  test('extractLeadingId from "Cell A: description"', () => {
    assert.strictEqual(extractLeadingId('Cell A: FINANCIAL wordmark'), 'a');
    assert.strictEqual(extractLeadingId('B: crystal frame'), 'b');
  });

  test('throws on malformed JSON instead of silent fallback', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asset-items-'));
    const file = path.join(dir, 'bad.json');
    fs.writeFileSync(file, '["broken", json]');
    assert.throws(() => parseCellSpecs(undefined, `@${file}`, dir), ItemsParseError);
  });

  test('validateGridCells rejects count mismatch', () => {
    assert.throws(
      () => validateGridCells([{ prompt: 'only one' }], 4),
      ItemsParseError,
    );
  });

  test('validateGridCells rejects duplicate cell ids (case-insensitive)', () => {
    assert.throws(
      () =>
        validateGridCells(
          [
            { id: 'foo', prompt: 'Cell A' },
            { id: 'FOO', prompt: 'Cell B' },
            { id: 'bar', prompt: 'Cell C' },
            { id: 'bar', prompt: 'Cell D' },
          ],
          4,
        ),
      (err: unknown) => {
        assert.ok(err instanceof ItemsParseError);
        assert.match(err.message, /duplicate cell id/i);
        assert.match(err.message, /01_foo\.webp|01_bar\.webp|collid/i);
        return true;
      },
    );
  });

  test('validateGenerationGate requires matching token and grill ack', () => {
    assert.throws(() => validateGenerationGate({}, 'abc'), ItemsParseError);
    assert.throws(() => validateGenerationGate({ confirmToken: 'wrong' }, 'abc'), ItemsParseError);
    assert.throws(() => validateGenerationGate({ confirmToken: 'abc' }, 'abc'), ItemsParseError);
    assert.doesNotThrow(() => validateGenerationGate({ printPrompt: true }, 'abc'));
    assert.doesNotThrow(() => validateGenerationGate({ confirmToken: 'abc', skipGrillAck: true }, 'abc'));
    assert.doesNotThrow(() => validateGenerationGate({ confirmToken: 'abc', skipGrillAck: true }, 'abc', 'single'));
  });

  test('does not comma-split theme prompt', () => {
    const specs = parseCellSpecs(undefined, undefined);
    assert.deepStrictEqual(specs, []);
    assert.throws(() => validateGridCells(specs, 4), ItemsParseError);
  });

  test('accepts plain cells.json without @', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'asset-items-'));
    const file = path.join(dir, 'cells.json');
    fs.writeFileSync(file, JSON.stringify(['A', 'B', 'C', 'D']));
    const specs = parseCellSpecs(undefined, 'cells.json', dir);
    assert.strictEqual(specs.length, 4);
  });
});
