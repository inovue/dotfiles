import { test, describe } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import sharp from 'sharp';
import { detectGridSeams } from '../src/grid-detect.js';
import { clearSeamCorridors, extractAndSaveAssets } from '../src/pack.js';
import type { AssetManifest, GeneratorOptions, GridMeta } from '../src/types.js';

/** Mirrors engine.ts post-try manifest finalization — gridMeta must stay in outer scope. */
async function finalizeManifestLikeEngine(
  outDir: string,
  gridMeta: GridMeta,
  manifest: AssetManifest,
  confirmToken: string,
): Promise<AssetManifest> {
  manifest.confirmToken = confirmToken;
  manifest.gridDetector = gridMeta.detector;
  const coverages = manifest.items.map((i) => i.alphaCoverage).filter((v): v is number => v != null);
  manifest.quality = {
    gridDetector: gridMeta.detector,
    seamConfidence: gridMeta.seamConfidence,
    magentaSeamHits: gridMeta.magentaSeamHits,
    totalSeams: gridMeta.totalSeams,
    alphaGateMin: 0.02,
    minAlphaCoverage: coverages.length > 0 ? Math.min(...coverages) : undefined,
    dimensionGateMin: 32,
    cellsPassed: manifest.items.length,
  };
  fs.writeFileSync(
    path.join(outDir, 'manifest.json'),
    JSON.stringify(manifest, null, 2) + '\n',
  );
  return manifest;
}

describe('engine manifest finalization', () => {
  test('gridMeta remains in scope after try for manifest.json write', async () => {
    const outDir = fs.mkdtempSync(path.join(os.tmpdir(), 'engine-manifest-'));
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

    const rawPath = path.join(outDir, 'sheet.raw.png');
    await sharp(rawBuffer, { raw: { width, height, channels: 3 } }).png().toFile(rawPath);

    let manifest: AssetManifest;
    let gridMeta: GridMeta;
    try {
      gridMeta = await detectGridSeams(rawPath, 2, 2);
      const transparentPath = path.join(outDir, 'sheet.transparent.png');
      const rgba = Buffer.alloc(width * height * 4);
      for (let i = 0; i < width * height; i++) {
        const r = rawBuffer[i * 3];
        const g = rawBuffer[i * 3 + 1];
        const b = rawBuffer[i * 3 + 2];
        const transparent =
          (r === 192 && g === 192 && b === 192) || (r === 255 && g === 0 && b === 255);
        rgba[i * 4] = r;
        rgba[i * 4 + 1] = g;
        rgba[i * 4 + 2] = b;
        rgba[i * 4 + 3] = transparent ? 0 : 255;
      }
      await sharp(rgba, { raw: { width, height, channels: 4 } }).png().toFile(transparentPath);
      const processed = await clearSeamCorridors(transparentPath, gridMeta);
      const options: GeneratorOptions = {
        countOrGrid: '4',
        prompt: 'Smoke',
        format: 'webp',
        quality: 80,
        rembg: false,
        tight: true,
        allowEmptyCells: true,
      };
      manifest = await extractAndSaveAssets(
        processed,
        gridMeta,
        outDir,
        options,
        ['A', 'B', 'C', 'D'],
        'engine_smoke',
      );
    } catch (err) {
      throw err;
    }

    const finalized = await finalizeManifestLikeEngine(outDir, gridMeta, manifest, 'abc123def456');
    assert.strictEqual(finalized.gridDetector, 'magenta');
    assert.strictEqual(finalized.quality?.gridDetector, 'magenta');

    const onDisk = JSON.parse(fs.readFileSync(path.join(outDir, 'manifest.json'), 'utf-8'));
    assert.strictEqual(onDisk.gridDetector, 'magenta');
    assert.strictEqual(onDisk.confirmToken, 'abc123def456');
    assert.strictEqual(onDisk.items.length, 4);
  });
});
