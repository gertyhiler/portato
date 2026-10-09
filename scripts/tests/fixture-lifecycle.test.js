import { test, expect } from 'bun:test';
import { mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';

test('IPC fixture exits when its test runner dies', async () => {
  const root = mkdtempSync('/tmp/portato-fixture-test-');
  const fixture = resolve(import.meta.dir, '../../macos/Tests/Fixtures/daemon.js');
  writeFileSync(join(root, 'portato.token'), 'a'.repeat(64));
  const script = join(root, 'parent.js');
  writeFileSync(script, `
    import {existsSync} from 'node:fs';
    const child = Bun.spawn([process.execPath, ${JSON.stringify(fixture)}, ${JSON.stringify(join(root, 'ipc.sock'))}], {stdout:'ignore',stderr:'inherit'});
    while (!existsSync(${JSON.stringify(join(root, 'ipc.sock'))})) await Bun.sleep(10);
    console.log(child.pid);
    await child.exited;
  `);
  const parent = Bun.spawn([process.execPath, script], { stdout: 'pipe' });
  let pid;
  try {
    const reader = parent.stdout.getReader();
    const { value } = await reader.read(); reader.releaseLock();
    pid = Number(new TextDecoder().decode(value).trim());
    expect(pid).toBeGreaterThan(0);
    parent.kill('SIGKILL');
    await parent.exited;
    const alive = () => { try { process.kill(pid, 0); return true; } catch { return false; } };
    for (let i = 0; i < 100 && alive(); i++) await Bun.sleep(20);
    expect(alive()).toBe(false);
  } finally {
    if (parent.exitCode === null) parent.kill('SIGKILL');
    await parent.exited;
    if (pid) { try { process.kill(pid, 'SIGKILL'); } catch {} }
    rmSync(root, { recursive: true, force: true });
  }
});
