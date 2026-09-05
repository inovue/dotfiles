import fs from 'node:fs';
import path from 'node:path';

function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return String(err);
}

/** Write manifest.failed.json without touching a successful manifest.json. */
export function writePipelineFailedMarker(
  outDir: string,
  err: unknown,
  extra?: Record<string, unknown>,
): void {
  const payload = {
    status: 'failed' as const,
    error: errorMessage(err),
    createdAt: new Date().toISOString(),
    ...extra,
  };

  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(
    path.join(outDir, 'manifest.failed.json'),
    JSON.stringify(payload, null, 2) + '\n',
  );
}
