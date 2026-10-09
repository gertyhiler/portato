import { mkdirSync, lstatSync, writeFileSync, unlinkSync, rmdirSync } from 'node:fs';
import { spawn } from 'node:child_process';

if (lstatSync('.runtime', { throwIfNoEntry: false })?.isSymbolicLink()) {
  throw new Error('Refusing symlinked .runtime');
}
mkdirSync('.runtime', { recursive: true });
const lock = '.runtime/runbook.lock.d';
try { mkdirSync(lock); } catch {
  throw new Error(`Another runbook command is active (or a stale lock exists): ${lock}`);
}
let child;
let signalReceived = false;
let forceTimer;
const alive = () => {
  if (!child?.pid) return false;
  try { process.kill(-child.pid, 0); return true; }
  catch (error) { if (error.code === 'ESRCH') return false; throw error; }
};
const signalGroup = signal => {
  if (!child?.pid) return;
  try { process.kill(-child.pid, signal); }
  catch (error) { if (error.code !== 'ESRCH') throw error; }
};
const interrupt = () => {
  if (signalReceived) return;
  signalReceived = true;
  signalGroup('SIGTERM');
  forceTimer = setTimeout(() => signalGroup('SIGKILL'), 5000);
};
for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, interrupt);
let status = 1;
try {
  writeFileSync(`${lock}/pid`, `${process.pid}\n`);
  const [command, ...args] = process.argv.slice(2);
  if (!command) throw new Error('Expected a command');
  child = spawn(command, args, { detached: true, stdio: 'inherit' });
  status = await new Promise((resolve, reject) => {
    child.once('error', reject);
    child.once('exit', (code, signal) => resolve(code ?? (signal ? 130 : 1)));
  });
} finally {
  signalGroup('SIGTERM');
  const deadline = Date.now() + 5000;
  while (alive()) {
    if (Date.now() >= deadline) signalGroup('SIGKILL');
    await Bun.sleep(20);
  }
  try { unlinkSync(`${lock}/pid`); } catch (error) { if (error.code !== 'ENOENT') throw error; }
  clearTimeout(forceTimer);
  rmdirSync(lock);
}
process.exit(signalReceived ? 130 : status);
