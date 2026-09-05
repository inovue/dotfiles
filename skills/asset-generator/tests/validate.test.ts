import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { detectGridSeams } from '../src/grid-detect.js';
import {
  validateGridSeams,
  validateGridGeometry,
  measureAlphaCoverage,
  validateCellAlphaCoverage,
  validateCellDimensions,
  validateNoMagentaSubjectCollision,
  validateChromaKeyLeavesSubject,
  PipelineValidationError,
} from '../src/validate.js';
import type { GridMeta } from '../src/types.js';

const VALID_BANDS: GridMeta['bands'] = [
  { index: 0, row: 0, col: 0, left: 0, top: 0, width: 512, height: 512 },
  { index: 1, row: 0, col: 1, left: 512, top: 0, width: 512, height: 512 },
  { index: 2, row: 1, col: 0, left: 0, top: 512, width: 512, height: 512 },
  { index: 3, row: 1, col: 1, left: 512, top: 512, width: 512, height: 512 },
];

function fakeGridMeta(detector: GridMeta['detector'], overrides: Partial<GridMeta> = {}): GridMeta {
  return {
    version: 1,
    cols: 2,
    rows: 2,
    srcSize: [1024, 1024],
    keyColor: '#C0C0C0',
    separatorColor: '#FF00FF',
    bands: VALID_BANDS,
    colSeams: [512],
    rowSeams: [512],
    detector,
    seamConfidence: { col: [0.8], row: [0.01] },
    magentaSeamHits: detector === 'magenta' ? 2 : 0,
    totalSeams: 2,
    ...overrides,
  };
}

describe('pipeline quality gates', () => {
  test('validateGridSeams rejects weak-magenta by default', () => {
    assert.throws(
      () => validateGridSeams(fakeGridMeta('weak-magenta')),
      PipelineValidationError,
    );
    assert.doesNotThrow(() => validateGridSeams(fakeGridMeta('weak-magenta'), { allowWeakSeams: true }));
    assert.doesNotThrow(() => validateGridSeams(fakeGridMeta('magenta')));
  });

  test('validateGridGeometry rejects non-monotonic column seams', () => {
    assert.throws(
      () =>
        validateGridGeometry(
          fakeGridMeta('magenta', {
            cols: 3,
            rows: 2,
            colSeams: [400, 300],
            rowSeams: [512],
            bands: [
              { index: 0, row: 0, col: 0, left: 0, top: 0, width: 400, height: 512 },
              { index: 1, row: 0, col: 1, left: 400, top: 0, width: 624, height: 512 },
              { index: 2, row: 0, col: 2, left: 1024, top: 0, width: 0, height: 512 },
              { index: 3, row: 1, col: 0, left: 0, top: 512, width: 400, height: 512 },
              { index: 4, row: 1, col: 1, left: 400, top: 512, width: 624, height: 512 },
              { index: 5, row: 1, col: 2, left: 1024, top: 512, width: 0, height: 512 },
            ],
          }),
        ),
      (err: Error) =>
        err instanceof PipelineValidationError && err.message.includes('not strictly increasing'),
    );
  });

  test('validateGridGeometry rejects non-monotonic row seams', () => {
    assert.throws(
      () =>
        validateGridGeometry(
          fakeGridMeta('magenta', {
            cols: 2,
            rows: 3,
            colSeams: [512],
            rowSeams: [700, 400],
            bands: [
              { index: 0, row: 0, col: 0, left: 0, top: 0, width: 512, height: 700 },
              { index: 1, row: 0, col: 1, left: 512, top: 0, width: 512, height: 700 },
              { index: 2, row: 1, col: 0, left: 0, top: 700, width: 512, height: 324 },
              { index: 3, row: 1, col: 1, left: 512, top: 700, width: 512, height: 324 },
              { index: 4, row: 2, col: 0, left: 0, top: 1024, width: 512, height: 0 },
              { index: 5, row: 2, col: 1, left: 512, top: 1024, width: 512, height: 0 },
            ],
          }),
        ),
      (err: Error) =>
        err instanceof PipelineValidationError && err.message.includes('not strictly increasing'),
    );
  });

  test('validateGridGeometry rejects seams outside image bounds', () => {
    assert.throws(
      () =>
        validateGridGeometry(
          fakeGridMeta('magenta', {
            colSeams: [0],
          }),
        ),
      (err: Error) =>
        err instanceof PipelineValidationError && err.message.includes('outside'),
    );
  });

  test('validateGridGeometry rejects overlapping band layout', () => {
    assert.throws(
      () =>
        validateGridGeometry(
          fakeGridMeta('magenta', {
            bands: [
              { index: 0, row: 0, col: 0, left: 0, top: 0, width: 600, height: 512 },
              { index: 1, row: 0, col: 1, left: 512, top: 0, width: 512, height: 512 },
              { index: 2, row: 1, col: 0, left: 0, top: 512, width: 512, height: 512 },
              { index: 3, row: 1, col: 1, left: 512, top: 512, width: 512, height: 512 },
            ],
          }),
        ),
      (err: Error) =>
        err instanceof PipelineValidationError && err.message.includes('does not match seam layout'),
    );
  });

  test('validateCellAlphaCoverage rejects near-empty cells', async () => {
    const empty = await sharp({
      create: { width: 64, height: 64, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } },
    }).png().toBuffer();

    await assert.rejects(
      () => validateCellAlphaCoverage(empty, 'test cell', 0),
      PipelineValidationError,
    );
  });

  test('measureAlphaCoverage on solid shape', async () => {
    const buf = Buffer.alloc(100 * 100 * 4, 0);
    for (let i = 0; i < 100 * 50; i++) {
      buf[i * 4 + 3] = 255;
    }
    const png = await sharp(buf, { raw: { width: 100, height: 100, channels: 4 } }).png().toBuffer();
    const cov = await measureAlphaCoverage(png);
    assert.ok(cov > 0.45 && cov < 0.55);
  });

  test('validateCellDimensions rejects tiny exports', () => {
    assert.throws(
      () => validateCellDimensions(16, 64, 'tiny', 0),
      PipelineValidationError,
    );
    assert.doesNotThrow(() => validateCellDimensions(64, 32, 'ok', 0));
  });

  test('validateNoMagentaSubjectCollision passes when only seam lines are magenta', async () => {
    const width = 200;
    const height = 200;
    const rawBuffer = Buffer.alloc(width * height * 3, 192);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 3;
        if (x === 100 || y === 100) {
          rawBuffer[idx] = 255;
          rawBuffer[idx + 1] = 0;
          rawBuffer[idx + 2] = 255;
        } else {
          const cellLeft = x < 100 ? 0 : 100;
          const cellTop = y < 100 ? 0 : 100;
          const cx = cellLeft + 50;
          const cy = cellTop + 50;
          if ((x - cx) ** 2 + (y - cy) ** 2 <= 30 ** 2) {
            rawBuffer[idx] = 30;
            rawBuffer[idx + 1] = 90;
            rawBuffer[idx + 2] = 220;
          }
        }
      }
    }

    const tmpPath = path.join(os.tmpdir(), `test-magenta-gate-pass-${Date.now()}.png`);
    await sharp(rawBuffer, { raw: { width, height, channels: 3 } }).png().toFile(tmpPath);

    try {
      const gridMeta = await detectGridSeams(tmpPath, 2, 2);
      await assert.doesNotReject(() => validateNoMagentaSubjectCollision(tmpPath, gridMeta));
    } finally {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    }
  });

  test('validateChromaKeyLeavesSubject passes when blue subject survives chroma-key', async () => {
    const width = 200;
    const height = 200;
    const rawBuffer = Buffer.alloc(width * height * 3, 192);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 3;
        if (x === 100 || y === 100) {
          rawBuffer[idx] = 255;
          rawBuffer[idx + 1] = 0;
          rawBuffer[idx + 2] = 255;
        } else {
          const cellLeft = x < 100 ? 0 : 100;
          const cellTop = y < 100 ? 0 : 100;
          const cx = cellLeft + 50;
          const cy = cellTop + 50;
          if ((x - cx) ** 2 + (y - cy) ** 2 <= 30 ** 2) {
            rawBuffer[idx] = 30;
            rawBuffer[idx + 1] = 90;
            rawBuffer[idx + 2] = 220;
          }
        }
      }
    }

    const tmpPath = path.join(os.tmpdir(), `test-chroma-gate-pass-${Date.now()}.png`);
    await sharp(rawBuffer, { raw: { width, height, channels: 3 } }).png().toFile(tmpPath);

    try {
      const gridMeta = await detectGridSeams(tmpPath, 2, 2);
      await assert.doesNotReject(() => validateChromaKeyLeavesSubject(tmpPath, gridMeta));
    } finally {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    }
  });

  test('validateChromaKeyLeavesSubject rejects all-gray cell interiors', async () => {
    const width = 200;
    const height = 200;
    const rawBuffer = Buffer.alloc(width * height * 3, 192);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 3;
        if (x === 100 || y === 100) {
          rawBuffer[idx] = 255;
          rawBuffer[idx + 1] = 0;
          rawBuffer[idx + 2] = 255;
        }
      }
    }

    const tmpPath = path.join(os.tmpdir(), `test-chroma-gate-fail-${Date.now()}.png`);
    await sharp(rawBuffer, { raw: { width, height, channels: 3 } }).png().toFile(tmpPath);

    try {
      const gridMeta = await detectGridSeams(tmpPath, 2, 2);
      await assert.rejects(
        () => validateChromaKeyLeavesSubject(tmpPath, gridMeta),
        (err: Error) =>
          err instanceof PipelineValidationError && err.message.includes('chroma-key'),
      );
    } finally {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    }
  });

  test('validateNoMagentaSubjectCollision rejects large magenta cell interiors', async () => {
    const width = 200;
    const height = 200;
    const rawBuffer = Buffer.alloc(width * height * 3, 192);

    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        const idx = (y * width + x) * 3;
        if (x === 100 || y === 100) {
          rawBuffer[idx] = 255;
          rawBuffer[idx + 1] = 0;
          rawBuffer[idx + 2] = 255;
        } else if (x >= 20 && x < 80 && y >= 20 && y < 80) {
          rawBuffer[idx] = 255;
          rawBuffer[idx + 1] = 0;
          rawBuffer[idx + 2] = 255;
        }
      }
    }

    const tmpPath = path.join(os.tmpdir(), `test-magenta-gate-fail-${Date.now()}.png`);
    await sharp(rawBuffer, { raw: { width, height, channels: 3 } }).png().toFile(tmpPath);

    try {
      const gridMeta = await detectGridSeams(tmpPath, 2, 2);
      await assert.rejects(
        () => validateNoMagentaSubjectCollision(tmpPath, gridMeta),
        (err: Error) =>
          err instanceof PipelineValidationError && err.message.includes('magenta pixels'),
      );
    } finally {
      if (fs.existsSync(tmpPath)) fs.unlinkSync(tmpPath);
    }
  });
});
