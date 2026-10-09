import assert from 'node:assert/strict';
import { cpSync, writeFileSync, existsSync, readFileSync, chmodSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { app, repo, fixture, command, stop, until, spawn, cleanupOnExit } from './smoke-support.js';

const isolated = fixture('compat');
const { root, env } = isolated;
let server, gui;
const cleanup = cleanupOnExit(async () => {
  await stop(gui);
  await stop(server);
  isolated.remove();
});
try {
  const bundle = join(root, 'Portato.app');
  cpSync(resolve(app, '../../..'), bundle, { recursive: true });
  const binary = join(bundle, 'Contents/MacOS/PortatoMenuBar');
  const sentinel = join(bundle, 'Contents/Resources/portato');
  writeFileSync(sentinel, `#!/bin/sh\necho started >> '${root}/launches'\nexit 1\n`);
  chmodSync(sentinel, 0o755);
  await command(['codesign', '--force', '--sign', '-', bundle], env);
  writeFileSync(join(root, 'portato.token'), 'a'.repeat(64));
  server = spawn([process.execPath, join(repo, 'macos/Tests/Fixtures/daemon.js'), env.PORTATO_SOCKET], {
    env, stdout: 'ignore', stderr: 'inherit',
  });
  await until(() => existsSync(env.PORTATO_SOCKET), 'compatibility fixture');
  const scenarios = [
    { status: 404, body: { error: 'not found' }, message: 'Update the running Go daemon' },
    { status: 401, body: { error: 'unauthorized' }, message: 'Daemon authentication changed' },
    { status: 200, body: { protocol: 2, config_path: '/tmp/config.yaml' }, message: 'unsupported protocol' },
  ];
  for (const scenario of scenarios) {
    writeFileSync(join(root, 'responses.json'), JSON.stringify({ '/info': scenario }));
    const result = Bun.spawnSync([binary, '--menu-json'], { env, timeout: 15000 });
    assert.equal(result.exitCode, 1, result.stderr.toString());
    const menu = JSON.parse(result.stdout.toString());
    assert.ok(menu.some(row => row.title.includes(scenario.message)), JSON.stringify(menu));
    assert.ok(!menu.find(row => row.title === 'Start Daemon')?.action);
    assert.equal(menu.find(row => row.title === 'Start Daemon')?.enabled, false);
    const requests = () => readFileSync(join(root, 'requests.log'), 'utf8').split('\n').filter(path => path === '/info').length;
    const before = requests();
    gui = spawn([binary, '-startDaemon', 'YES'], { env, stdout: 'ignore', stderr: 'inherit' });
    await until(() => {
      assert.equal(gui.exitCode, null, 'GUI exited unexpectedly');
      return requests() >= before + 2;
    }, 'GUI retries existing daemon');
    assert.ok(!existsSync(join(root, 'launches')), 'GUI attempted another daemon launch');
    await stop(gui);
    console.log(`PASS: ${scenario.message}: visible error, disabled start, no daemon launch`);
  }
} finally { await cleanup(); }
