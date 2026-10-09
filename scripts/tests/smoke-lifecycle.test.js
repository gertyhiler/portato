import { test, expect } from 'bun:test';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { join, resolve } from 'node:path';

test('interrupting a smoke check cleans up owned processes', async () => {
  const root = mkdtempSync('/tmp/portato-lifecycle-');
  const file = join(root, 'probe.js');
  const support = resolve(import.meta.dir, '../../macos/scripts/smoke-support.js');
  writeFileSync(file, `
    import { spawn, stop, cleanupOnExit } from ${JSON.stringify(support)};
    const child = spawn(['sleep', '60'], {stdout:'ignore', stderr:'ignore'});
    cleanupOnExit(() => stop(child));
    console.log(child.pid);
    await child.exited;
    await Bun.sleep(60000);
  `);
  const child = Bun.spawn([process.execPath, file], { stdout: 'pipe' });
  let owned;
  try {
    const reader = child.stdout.getReader();
    const { value } = await reader.read(); reader.releaseLock();
    owned = Number(new TextDecoder().decode(value).trim());
    expect(owned).toBeGreaterThan(0);
    child.kill('SIGTERM');
    expect(await child.exited).toBe(130);
    expect(() => process.kill(owned, 0)).toThrow();
  } finally {
    if (child.exitCode === null) child.kill('SIGKILL');
    if (owned) { try { process.kill(owned, 'SIGKILL'); } catch {} }
    await child.exited;
    rmSync(root, { recursive: true, force: true });
  }
});
