import { test, expect, beforeEach, afterEach } from 'bun:test';
import { mkdtempSync, mkdirSync, writeFileSync, existsSync, realpathSync, rmSync, symlinkSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execFileSync } from 'node:child_process';
import { clean, artifacts } from '../clean.js';

const repo = resolve(import.meta.dir, '../..');
let root;
beforeEach(() => {
  root = mkdtempSync('/tmp/portato-tool-test-');
  execFileSync('git', ['init', '-q', root]);
});
afterEach(() => rmSync(root, { recursive: true, force: true }));
function file(path, content = 'data') {
  const full = join(root, path);
  mkdirSync(resolve(full, '..'), { recursive: true });
  writeFileSync(full, content);
}

test('clean removes artifacts and preserves configuration and dependency caches', () => {
  for (const path of artifacts) file(path.endsWith('.out') ? path : `${path}/artifact`);
  const preserved = ['.tools/bin/lint', '.runtime/dev/config.yaml', '.env', 'macos/.build/checkouts/package'];
  for (const path of preserved) file(path);
  clean(root);
  for (const path of artifacts) expect(existsSync(join(root, path))).toBe(false);
  for (const path of preserved) expect(existsSync(join(root, path))).toBe(true);
});

test('clean validates every target before deleting anything', () => {
  file('bin/artifact'); file('dist/tracked');
  execFileSync('git', ['add', 'dist/tracked'], { cwd: root });
  expect(() => clean(root)).toThrow('tracked');
  expect(existsSync(join(root, 'bin/artifact'))).toBe(true);
});

test('clean refuses symlinked ancestors and dangling targets', () => {
  file('outside/out/artifact'); mkdirSync(join(root, 'macos'));
  symlinkSync(join(root, 'outside'), join(root, 'macos/.build'));
  expect(() => clean(root)).toThrow('symlink');
  expect(existsSync(join(root, 'outside/out/artifact'))).toBe(true);
  rmSync(join(root, 'macos/.build'));
  symlinkSync(join(root, 'missing'), join(root, 'bin'));
  expect(() => clean(root)).toThrow('symlink');
});

test('checkout lock rejects concurrency and releases on command failure', async () => {
  const lock = join(repo, 'scripts/with-lock.js');
  const child = Bun.spawn([process.execPath, lock, 'sh', '-c', 'echo ready; read line'], { cwd: root, stdin: 'pipe', stdout: 'pipe' });
  try {
    const reader = child.stdout.getReader();
    await reader.read(); reader.releaseLock();
    const blocked = Bun.spawnSync([process.execPath, lock, 'true'], { cwd: root });
    expect(blocked.exitCode).not.toBe(0);
  } finally { child.stdin.end(); await child.exited; }
  const failed = Bun.spawnSync([process.execPath, lock, 'false'], { cwd: root });
  expect(failed.exitCode).toBe(1);
  expect(existsSync(join(root, '.runtime/runbook.lock.d'))).toBe(false);
});

test('verify stops before tests when check fails under parallel make', () => {
  file('Makefile', readFileSync(join(repo, 'Makefile')));
  file('overrides.mk', '_check:\n\t@false\n_test:\n\t@touch tests-ran\n');
  const result = Bun.spawnSync(['make', '-j4', '-f', 'Makefile', '-f', 'overrides.mk', '_verify', 'MAKE=make -f Makefile -f overrides.mk'], { cwd: root });
  expect(result.exitCode).not.toBe(0);
  expect(existsSync(join(root, 'tests-ran'))).toBe(false);
});

test('linter version rejects other releases and suffixes', () => {
  for (const version of ['v2.0.0', 'v1.64.8-dev', '1.64.8.1', '1.64.8']) {
    file('.tools/bin/golangci-lint', `#!/bin/sh\necho 'golangci-lint has version ${version}'\n`);
    execFileSync('chmod', ['+x', join(root, '.tools/bin/golangci-lint')]);
    const result = Bun.spawnSync(['sh', join(repo, 'scripts/check-linter.sh')], { cwd: root });
    expect(result.exitCode === 0).toBe(version === '1.64.8');
  }
});

test('dev uses its own foreground daemon and removes temporary sockets', () => {
  file('fake/go', '#!/bin/sh\nexit 0\n');
  file('.runtime/dev/portato', '#!/bin/sh\nprintf "%s\\n" "$@" "$XDG_CONFIG_HOME" "$PORTATO_SOCKET" > args\n');
  execFileSync('chmod', ['+x', join(root, 'fake/go'), join(root, '.runtime/dev/portato')]);
  const result = Bun.spawnSync(['sh', join(repo, 'scripts/dev.sh')], { cwd: root,
    env: { ...process.env, PATH: `${root}/fake:${process.env.PATH}`, PORTATO_SOCKET: '/tmp/user-daemon.sock' } });
  expect(result.exitCode).toBe(0);
  const args = readFileSync(join(root, 'args'), 'utf8').trim().split('\n');
  expect(args[2]).toBe('daemon');
  expect(args[3]).toBe(`${realpathSync(root)}/.runtime/dev/config`);
  expect(args[4]).toMatch(/^\/tmp\/portato-dev-/);
  expect(existsSync(resolve(args[4], '..'))).toBe(false);
});

test('interrupting dev stops its owned daemon before removing socket state', async () => {
  file('fake/go', '#!/bin/sh\nexit 0\n');
  file('.runtime/dev/portato', '#!/bin/sh\ntrap "exit 0" TERM\necho $$ > daemon-pid\nwhile :; do sleep 0.1; done\n');
  execFileSync('chmod', ['+x', join(root, 'fake/go'), join(root, '.runtime/dev/portato')]);
  const child = Bun.spawn(['sh', join(repo, 'scripts/dev.sh')], { cwd: root,
    env: { ...process.env, PATH: `${root}/fake:${process.env.PATH}` } });
  let pid;
  try {
    for (let i = 0; i < 100 && !existsSync(join(root, 'daemon-pid')); i++) await Bun.sleep(20);
    pid = Number(readFileSync(join(root, 'daemon-pid'), 'utf8'));
    child.kill('SIGTERM');
    expect(await child.exited).toBe(130);
    expect(() => process.kill(pid, 0)).toThrow();
  } finally {
    if (child.exitCode === null) child.kill('SIGKILL');
    if (pid) { try { process.kill(pid, 'SIGKILL'); } catch {} }
    await child.exited;
  }
});

test('lock interruption stops recipe descendants before releasing the lock', async () => {
  file('Makefile', "hold:\n\t@sh -c 'sleep 60 & echo $$! > descendant; wait'\n");
  const lock = join(repo, 'scripts/with-lock.js');
  const child = Bun.spawn([process.execPath, lock, 'make', 'hold'], { cwd: root, stdout: 'ignore', stderr: 'ignore' });
  let pid;
  try {
    for (let i = 0; i < 100; i++) {
      if (existsSync(join(root, 'descendant')) && readFileSync(join(root, 'descendant'), 'utf8').trim()) break;
      await Bun.sleep(20);
    }
    pid = Number(readFileSync(join(root, 'descendant'), 'utf8').trim());
    expect(pid).toBeGreaterThan(0);
    child.kill('SIGTERM');
    expect(await child.exited).toBe(130);
    expect(() => process.kill(pid, 0)).toThrow();
    expect(existsSync(join(root, '.runtime/runbook.lock.d'))).toBe(false);
  } finally {
    if (child.exitCode === null) child.kill('SIGTERM');
    await child.exited;
    if (pid) { try { process.kill(pid, 'SIGKILL'); } catch {} }
  }
});

test('dev-tui refuses missing or stale checkout sockets despite inherited user socket', () => {
  file('fake/go', '#!/bin/sh\ntouch wrong-daemon\n');
  execFileSync('chmod', ['+x', join(root, 'fake/go')]);
  const run = () => Bun.spawnSync(['sh', join(repo, 'scripts/dev-tui.sh')], { cwd: root,
    env: { ...process.env, PATH: `${root}/fake:${process.env.PATH}`, PORTATO_SOCKET: '/tmp/user.sock' } });
  expect(run().exitCode).not.toBe(0);
  file('.runtime/dev/socket', '/tmp/portato-dev-missing/ipc.sock\n');
  expect(run().exitCode).not.toBe(0);
  expect(existsSync(join(root, 'wrong-daemon'))).toBe(false);
});

test('dev-tui overrides an inherited user socket with the live checkout socket', async () => {
  const { createServer } = await import('node:net');
  const socket = join(root, 'ipc.sock');
  const server = createServer();
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(socket, resolve); });
  try {
    file('fake/go', '#!/bin/sh\nprintf "%s\\n" "$PORTATO_SOCKET" > selected-socket\n');
    file('.runtime/dev/socket', `${socket}\n`);
    execFileSync('chmod', ['+x', join(root, 'fake/go')]);
    const result = Bun.spawnSync(['sh', join(repo, 'scripts/dev-tui.sh')], { cwd: root,
      env: { ...process.env, PATH: `${root}/fake:${process.env.PATH}`, PORTATO_SOCKET: '/tmp/user.sock' } });
    expect(result.exitCode).toBe(0);
    expect(readFileSync(join(root, 'selected-socket'), 'utf8').trim()).toBe(socket);
  } finally { await new Promise(resolve => server.close(resolve)); }
});
