import { execFile, execFileSync } from 'node:child_process';
import { promisify } from 'node:util';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const execFileAsync = promisify(execFile);

export const MAX_RETRIES = 3;

export type GenmediaJson = Record<string, unknown>;

/**
 * When GENMEDIA_BIN wraps secrets (e.g. `bws run -- genmedia`), hydrate FAL_KEY into
 * the process env once, then call the real genmedia binary via execFile.
 * Passing multiline --prompt through `bws run` re-enters a shell and truncates the prompt.
 */
export function hydrateFalKeyFromGenmediaBin(): void {
  if (process.env.FAL_KEY?.trim()) return;
  const override = process.env.GENMEDIA_BIN?.trim();
  if (!override) return;

  const parts = override.split(/\s+/).filter(Boolean);
  const dd = parts.indexOf('--');
  if (dd < 0 || dd >= parts.length - 1) return;

  const command = parts[0];
  const prefixThroughDash = parts.slice(1, dd + 1); // includes '--'
  try {
    const stdout = execFileSync(command, [...prefixThroughDash, 'printenv', 'FAL_KEY'], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: process.env,
      timeout: 30_000,
    });
    const key = String(stdout ?? '').trim();
    if (key) {
      process.env.FAL_KEY = key;
    }
  } catch {
    // leave unset — assertGenmediaAuthReady / API call will surface auth errors
  }
}

/** Resolve genmedia invocation. Override with GENMEDIA_BIN="bws run -- genmedia" if needed. */
export function resolveGenmediaInvocation(): { command: string; prefixArgs: string[] } {
  hydrateFalKeyFromGenmediaBin();

  // Prefer bare genmedia once FAL_KEY is available (avoids shell-wrapping multiline prompts).
  if (process.env.FAL_KEY?.trim()) {
    return { command: 'genmedia', prefixArgs: [] };
  }

  const override = process.env.GENMEDIA_BIN?.trim();
  if (override) {
    const parts = override.split(/\s+/).filter(Boolean);
    if (parts.length === 0) {
      throw new Error('GENMEDIA_BIN is empty');
    }
    return { command: parts[0], prefixArgs: parts.slice(1) };
  }
  return { command: 'genmedia', prefixArgs: [] };
}

export function ensureGenmediaAvailable(): void {
  const { command, prefixArgs } = resolveGenmediaInvocation();
  try {
    execFileSync(command, [...prefixArgs, 'version', '--json'], {
      encoding: 'utf-8',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, GENMEDIA_NO_UPDATE: process.env.GENMEDIA_NO_UPDATE ?? '1' },
      timeout: 30_000,
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(
      '\x1b[31m[ERROR] genmedia CLI is not available.\x1b[0m\n' +
        'Install: curl https://genmedia.sh/install -fsS | bash\n' +
        'Auth: export FAL_KEY=...  OR  genmedia setup --non-interactive --api-key "$FAL_KEY"\n' +
        'If you wrap secrets (e.g. Bitwarden): export GENMEDIA_BIN="bws run -- genmedia"\n' +
        `Detail: ${msg}`,
    );
  }
}

const GENMEDIA_CONFIG_KEY_FIELDS = [
  'api_key',
  'apiKey',
  'fal_key',
  'falKey',
  'encrypted_api_key',
  'encryptedApiKey',
  'key',
] as const;

/** True when parsed genmedia config JSON contains any known non-empty key field. */
export function hasGenmediaSavedKey(config: unknown): boolean {
  if (config == null || typeof config !== 'object' || Array.isArray(config)) {
    return false;
  }
  const record = config as Record<string, unknown>;
  return GENMEDIA_CONFIG_KEY_FIELDS.some((field) => {
    const value = record[field];
    return typeof value === 'string' && value.trim().length > 0;
  });
}

export function resolveGenmediaConfigPath(): string {
  const xdg = process.env.XDG_CONFIG_HOME?.trim();
  const base = xdg && xdg.length > 0 ? xdg : path.join(os.homedir(), '.config');
  return path.join(base, 'genmedia', 'config.json');
}

function readGenmediaSavedConfig(): unknown | null {
  const configPath = resolveGenmediaConfigPath();
  if (!fs.existsSync(configPath)) return null;
  try {
    return JSON.parse(fs.readFileSync(configPath, 'utf-8')) as unknown;
  } catch {
    return null;
  }
}

/** Fail fast before paid genmedia calls when no auth source is available. */
export function assertGenmediaAuthReady(): void {
  ensureGenmediaAvailable();

  if (process.env.FAL_KEY?.trim()) return;
  if (process.env.GENMEDIA_BIN?.trim()) return;

  const saved = readGenmediaSavedConfig();
  if (hasGenmediaSavedKey(saved)) return;

  const configPath = resolveGenmediaConfigPath();
  throw new Error(
    '\x1b[31m[ERROR] genmedia auth is not configured.\x1b[0m\n' +
      'Install: curl https://genmedia.sh/install -fsS | bash\n' +
      'Auth: export FAL_KEY=...  OR  genmedia setup --non-interactive --api-key "$FAL_KEY"\n' +
      'If you wrap secrets (e.g. Bitwarden): export GENMEDIA_BIN="bws run -- genmedia"\n' +
      `Expected saved config at: ${configPath}`,
  );
}

/** Prefer FAL_KEY when set; otherwise rely on genmedia saved config / GENMEDIA_BIN wrapper. */
export function requireFalKey(): string {
  assertGenmediaAuthReady();
  return process.env.FAL_KEY?.trim() ?? '';
}

/** Patterns that indicate transient failures — always eligible for retry. */
const RETRYABLE_ERROR_PATTERNS: RegExp[] = [
  /timeout/i,
  /ECONNRESET/,
  /\b429\b/,
  /\b5\d{2}\b/,
];

/** Patterns that indicate client/auth/policy errors — fail fast, do not retry. */
const NON_RETRYABLE_ERROR_PATTERNS: RegExp[] = [
  /\b422\b/,
  /unprocessable/i,
  /field required/i,
  /\b401\b/,
  /\b403\b/,
  /invalid_auth/i,
  /unauthorized/i,
  /forbidden/i,
  /content.?policy/i,
  /\bsafety\b/i,
  /\bmoderation\b/i,
  /\bnsfw\b/i,
  /not found/i,
  /GENMEDIA_BIN is empty/i,
  /genmedia CLI is not available/i,
  /genmedia auth is not configured/i,
];

function errorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  return String(err);
}

export function isNonRetryableGenmediaError(err: unknown): boolean {
  const msg = errorMessage(err);
  if (RETRYABLE_ERROR_PATTERNS.some((re) => re.test(msg))) {
    return false;
  }
  return NON_RETRYABLE_ERROR_PATTERNS.some((re) => re.test(msg));
}

export async function withRetry<T>(
  operation: () => Promise<T>,
  operationName: string,
  maxRetries: number = MAX_RETRIES,
): Promise<T> {
  let attempt = 0;
  while (attempt < maxRetries) {
    try {
      return await operation();
    } catch (err: unknown) {
      if (isNonRetryableGenmediaError(err)) {
        throw new Error(`${operationName} failed (non-retryable): ${errorMessage(err)}`);
      }
      attempt++;
      const msg = errorMessage(err);
      if (attempt >= maxRetries) {
        throw new Error(`${operationName} failed after ${maxRetries} attempts: ${msg}`);
      }
      const delayMs = Math.pow(2, attempt) * 1000;
      console.warn(
        `\x1b[33m[WARN] ${operationName} failed (attempt ${attempt}/${maxRetries}). Retrying in ${delayMs / 1000}s... (${msg})\x1b[0m`,
      );
      await new Promise((resolve) => setTimeout(resolve, delayMs));
    }
  }
  throw new Error(`${operationName} failed`);
}

function formatCliValue(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number' || typeof value === 'boolean') return String(value);
  return JSON.stringify(value);
}

/** Convert model input object to genmedia `--flag value` pairs. */
export function inputToCliFlags(input: Record<string, unknown>): string[] {
  const flags: string[] = [];
  for (const [key, value] of Object.entries(input)) {
    if (value === undefined || value === null) continue;
    flags.push(`--${key}`, formatCliValue(value));
  }
  return flags;
}

export async function runGenmediaJson(args: string[]): Promise<GenmediaJson> {
  const { command, prefixArgs } = resolveGenmediaInvocation();
  const fullArgs = [...prefixArgs, ...args, '--json'];
  const env = { ...process.env, GENMEDIA_NO_UPDATE: process.env.GENMEDIA_NO_UPDATE ?? '1' };

  let stdout: string;
  let stderr: string;
  try {
    const result = await execFileAsync(command, fullArgs, {
      encoding: 'utf-8',
      maxBuffer: 32 * 1024 * 1024,
      env,
      // Image generation can take several minutes
      timeout: 10 * 60 * 1000,
    });
    stdout = result.stdout ?? '';
    stderr = result.stderr ?? '';
  } catch (err: any) {
    const out = `${err.stdout ?? ''}\n${err.stderr ?? ''}`.trim();
    throw new Error(
      `genmedia ${args[0] ?? ''} failed (exit ${err.code ?? '?'}): ${out || err.message}`,
    );
  }

  const text = stdout.trim();
  if (!text) {
    throw new Error(`genmedia returned empty stdout. stderr: ${stderr.trim() || '(none)'}`);
  }

  // Some wrappers may emit non-JSON lines before the payload — take the last JSON object.
  const jsonText = extractJsonObject(text);
  try {
    return JSON.parse(jsonText) as GenmediaJson;
  } catch {
    throw new Error(`Failed to parse genmedia JSON:\n${text.slice(0, 2000)}`);
  }
}

function extractJsonObject(text: string): string {
  const trimmed = text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) return trimmed;
  const start = trimmed.lastIndexOf('\n{');
  if (start >= 0) return trimmed.slice(start + 1).trim();
  const brace = trimmed.indexOf('{');
  if (brace >= 0) return trimmed.slice(brace).trim();
  return trimmed;
}

export async function genmediaUpload(localPath: string): Promise<string> {
  const resolved = path.resolve(localPath);
  if (!fs.existsSync(resolved)) {
    throw new Error(`Upload file not found: ${resolved}`);
  }
  const result = await runGenmediaJson(['upload', resolved]);
  const url = (result.cdn_url ?? result.url) as string | undefined;
  if (!url) {
    throw new Error(`genmedia upload returned no cdn_url: ${JSON.stringify(result)}`);
  }
  return url;
}

/** Single-argv download flag — genmedia expects `--download=<path>`, not two separate args. */
export function formatDownloadFlag(destPath: string): string {
  return `--download=${path.resolve(destPath)}`;
}

/**
 * Run a fal endpoint via genmedia and download the first media file to destPath.
 * Uses `--download=<path>` (single argv; space-separated form can leave downloaded_files empty).
 */
export async function genmediaRunDownload(
  endpointId: string,
  input: Record<string, unknown>,
  destPath: string,
): Promise<GenmediaJson> {
  ensureDirForFile(destPath);
  const resolvedDest = path.resolve(destPath);
  const flags = inputToCliFlags(input);
  const result = await runGenmediaJson([
    'run',
    endpointId,
    ...flags,
    formatDownloadFlag(resolvedDest),
  ]);

  settleDownloadedFile(result, resolvedDest);
  if (!fs.existsSync(resolvedDest)) {
    throw new Error(
      `genmedia --download did not create ${resolvedDest}. ` +
        `downloaded_files=${JSON.stringify(result.downloaded_files ?? null)}`,
    );
  }
  return result;
}

function ensureDirForFile(filePath: string): void {
  fs.mkdirSync(path.dirname(path.resolve(filePath)), { recursive: true });
}

function settleDownloadedFile(result: GenmediaJson, destPath: string): void {
  if (fs.existsSync(destPath)) return;

  const files = result.downloaded_files;
  const list = Array.isArray(files)
    ? files.filter((f): f is string => typeof f === 'string')
    : typeof files === 'string'
      ? [files]
      : [];

  const candidates = [
    ...list,
    `${destPath}.png`,
    `${destPath}.webp`,
    `${destPath}.jpg`,
    destPath.replace(/\.png$/i, '') + '.png',
  ];

  for (const src of candidates) {
    if (!src || src === destPath) continue;
    if (!fs.existsSync(src)) continue;
    fs.mkdirSync(path.dirname(destPath), { recursive: true });
    fs.renameSync(src, destPath);
    return;
  }
}
