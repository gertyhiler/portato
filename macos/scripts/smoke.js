import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { createServer, createConnection } from 'node:net';
import { createInterface } from 'node:readline/promises';
import { parseArgs } from 'node:util';
import { app, cli, repo, fixture, command, stop, until, spawn, cleanupOnExit } from './smoke-support.js';

const { values } = parseArgs({ args: process.argv.slice(2), options: {
  ssh: { type: 'string' }, remote: { type: 'string', default: '127.0.0.1:2222' }, gui: { type: 'boolean' },
}});
const isolated = fixture('smoke');
const { root, env } = isolated;
const config = `${root}/config.yaml`;
let daemon, gui;
const cleanup = cleanupOnExit(async () => {
  await stop(gui);
  await stop(daemon);
  isolated.remove();
});
const run = (...args) => command([cli, '--config', config, ...args], env);
const list = async () => JSON.parse(await command([app, '--list-json'], env));
async function start() {
  daemon = spawn([cli, '--config', config, 'daemon'], {
    env, stdout: Bun.file(`${root}/daemon.log`), stderr: 'inherit',
  });
  await until(async () => {
    assert.equal(daemon.exitCode, null, 'Daemon exited during startup');
    try { await run('list', '--json'); return true; } catch { return false; }
  }, 'daemon startup');
}
async function freePort() {
  const server = createServer();
  await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}
async function banner(port) {
  await new Promise((resolve, reject) => {
    const socket = createConnection({ host: '127.0.0.1', port });
    let bytes = Buffer.alloc(0);
    socket.setTimeout(5000, () => socket.destroy(new Error('SSH banner timeout')));
    socket.once('error', reject);
    socket.once('end', () => reject(new Error('EOF before SSH banner')));
    socket.on('data', data => {
      bytes = Buffer.concat([bytes, data]);
      if (bytes.length < 8) return;
      socket.destroy();
      try { assert.ok(bytes.toString().startsWith('SSH-2.0-')); resolve(); } catch (error) { reject(error); }
    });
  });
}
try {
  const port = values.ssh ? await freePort() : 0;
  writeFileSync(config, values.ssh
    ? `tubers:\n  - name: corp-probe\n    type: local\n    ssh: ${JSON.stringify(values.ssh)}\n    local: 127.0.0.1:${port}\n    remote: ${JSON.stringify(values.remote)}\n    enabled: false\n`
    : 'tubers: []\n');
  await start();
  await list();
  console.log(await command(['swift', 'run', '--package-path', `${repo}/macos`, 'PortatoCoreChecks', '--real-daemon'], env, 120000));
  console.log('PASS: native client discovers authenticated real daemon');
  if (values.ssh) {
    const state = expected => until(async () => (await list())[0].state === expected, expected);
    await run('enable', 'corp-probe');
    await state('connected');
    await banner(port);
    await run('restart', 'corp-probe');
    await state('connected');
    await run('disable', 'corp-probe');
    await state('off');
    console.log('PASS: SSH forwarding and CLI changes visible to native client');
  }
  await stop(daemon);
  await start();
  await list();
  console.log('PASS: native client reads rotated daemon token after restart');
  const menu = JSON.parse(await command([app, '--menu-json'], env));
  assert.ok(menu.some(row => row.action === 'openTUI'));
  assert.ok(menu.some(row => row.action === 'quit'));
  if (values.ssh) {
    const children = menu.find(row => row.title.includes('corp-probe')).children;
    for (const title of ['Connect', 'Disconnect', 'Restart']) {
      assert.equal(children.find(row => row.title === title).enabled, title === 'Connect');
    }
  }
  console.log('PASS: AppKit menu labels, command bindings and disabled-state controls');
  if (values.gui) {
    gui = spawn([app], { env, stdout: 'inherit', stderr: 'inherit' });
    const terminal = createInterface({ input: process.stdin, output: process.stdout });
    try { await terminal.question(`GUI ready at ${env.PORTATO_SOCKET}. Press Enter to finish.\n`); }
    finally { terminal.close(); }
    assert.equal(gui.exitCode, null, 'GUI exited unexpectedly');
    await stop(gui);
    await list();
    console.log('PASS: quitting menu bar leaves daemon available');
  }
} finally {
  await cleanup();
}
