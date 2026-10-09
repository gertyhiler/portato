import { mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';

export const repo = resolve(import.meta.dir, '../..');
export const cli = join(repo, 'bin/portato');
export const app = join(process.env.PORTATO_APP_DIR || join(repo, 'dist/Portato Menu Bar.app'), 'Contents/MacOS/PortatoMenuBar');
export const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));

export function fixture(prefix) {
  const root = mkdtempSync(`/tmp/portato-${prefix}-`);
  mkdirSync(join(root, 'config/portato'), { recursive: true });
  const env = { ...process.env, XDG_CONFIG_HOME: join(root, 'config'),
    XDG_STATE_HOME: join(root, 'state'), PORTATO_SOCKET: join(root, 'ipc.sock') };
  return { root, env, remove: () => rmSync(root, { recursive: true, force: true }) };
}

let interrupted = false;
const commands = new Set();
export function spawn(args, options) {
  if (interrupted) throw new Error('Smoke check interrupted');
  return Bun.spawn(args, options);
}

export function cleanupOnExit(cleanup) {
  let pending;
  const finish = () => pending ??= Promise.resolve().then(cleanup);
  const interrupt = () => {
    if (interrupted) return;
    interrupted = true;
    Promise.all([...commands].map(stop)).then(finish).then(() => process.exit(130), error => { console.error(error); process.exit(1); });
  };
  for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, interrupt);
  return finish;
}

export async function command(args, env, timeout = 15000) {
  const child = spawn(args, { env, cwd: repo, stdout: 'pipe', stderr: 'pipe' });
  commands.add(child);
  const timer = setTimeout(() => child.kill('SIGKILL'), timeout);
  try {
    const [stdout, stderr, status] = await Promise.all([
      new Response(child.stdout).text(), new Response(child.stderr).text(), child.exited,
    ]);
    if (interrupted) throw new Error('Smoke check interrupted');
    if (status !== 0) throw new Error(`${args[0]} exited ${status}: ${stderr || stdout}`);
    return stdout;
  } finally { clearTimeout(timer); commands.delete(child); }
}

export async function stop(child) {
  if (!child || child.exitCode !== null) return;
  child.kill('SIGTERM');
  const timer = setTimeout(() => child.kill('SIGKILL'), 10000);
  try { await child.exited; } finally { clearTimeout(timer); }
}

export async function until(probe, label, attempts = 100) {
  for (let i = 0; i < attempts; i++) {
    if (await probe()) return;
    await sleep(100);
  }
  throw new Error(`Timed out: ${label}`);
}
