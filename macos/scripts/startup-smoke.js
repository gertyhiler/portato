import assert from 'node:assert/strict';
import { existsSync, writeFileSync } from 'node:fs';
import { app, cli, fixture, command, stop, until, spawn, cleanupOnExit } from './smoke-support.js';

const isolated = fixture('start');
const { root, env } = isolated;
const config = `${root}/config/portato/config.yaml`;
writeFileSync(config, 'tubers: []\n');
let gui;
const cleanup = cleanupOnExit(async () => {
  await stop(gui);
  if (existsSync(env.PORTATO_SOCKET) || existsSync(root + '/config/portato/daemon.socket')) {
    const result = Bun.spawnSync([cli, '--config', config, 'stop'], { env, timeout: 10000 });
    assert.equal(result.exitCode, 0, result.stderr.toString());
    await until(() => !existsSync(env.PORTATO_SOCKET), 'isolated daemon shutdown');
  }
  isolated.remove();
});
try {
  await assert.rejects(command([app, '--menu-json'], env), /exited 1:/);
  assert.ok(!existsSync(env.PORTATO_SOCKET), 'Diagnostic started daemon');
  console.log('PASS: diagnostic does not start daemon');
  gui = spawn([app, '-startDaemon', 'YES'], { env, stdout: 'inherit', stderr: 'inherit' });
  await until(async () => {
    assert.equal(gui.exitCode, null, 'GUI exited');
    try { await command([app, '--list-json'], env); return true; } catch { return false; }
  }, 'app starts bundled daemon', 150);
  console.log('PASS: menu starts bundled daemon with isolated config');
  await stop(gui);
  await command([app, '--list-json'], env);
  console.log('PASS: daemon survives menu exit');
} finally {
  await cleanup();
}
