import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import sharp from 'sharp';
import { fitTransparentToSize } from '../src/rembg.js';

describe('fitTransparentToSize', () => {
  test('preserves aspect ratio with transparent letterbox (no stretch)', async () => {
    const srcW = 200;
    const srcH = 100;
    const raw = Buffer.alloc(srcW * srcH * 4, 0);
    for (let y = 20; y < 80; y++) {
      for (let x = 0; x < srcW; x++) {
        const idx = (y * srcW + x) * 4;
        raw[idx] = 255;
        raw[idx + 1] = 0;
        raw[idx + 2] = 0;
        raw[idx + 3] = 255;
      }
    }
    const src = await sharp(raw, { raw: { width: srcW, height: srcH, channels: 4 } })
      .png()
      .toBuffer();

    const destW = 100;
    const destH = 100;
    const out = await fitTransparentToSize(src, destW, destH);
    const meta = await sharp(out).metadata();
    assert.strictEqual(meta.width, destW);
    assert.strictEqual(meta.height, destH);

    const { data, info } = await sharp(out).ensureAlpha().raw().toBuffer({ resolveWithObject: true });

    const sample = (x: number, y: number) => {
      const i = (y * info.width + x) * info.channels;
      return { r: data[i], g: data[i + 1], b: data[i + 2], a: data[i + 3] };
    };

    // Top letterbox row should be transparent
    assert.strictEqual(sample(50, 5).a, 0);

    // Center content row should retain red (aspect preserved, not squashed to fill)
    const center = sample(50, 50);
    assert.ok(center.r > 200);
    assert.ok(center.a > 200);

    // Bottom letterbox row should be transparent
    assert.strictEqual(sample(50, 95).a, 0);
  });

  test('returns buffer unchanged when dimensions already match', async () => {
    const buf = await sharp({
      create: { width: 64, height: 64, channels: 4, background: { r: 0, g: 255, b: 0, alpha: 255 } },
    })
      .png()
      .toBuffer();

    const out = await fitTransparentToSize(buf, 64, 64);
    assert.strictEqual(out, buf);
  });
});
