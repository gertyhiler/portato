import { test, expect } from 'bun:test';
import { mkdtempSync, rmSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

const guard = resolve(import.meta.dir, '../check-release-origin.sh');
test('release guard permits only an unambiguous upstream push destination', () => {
  const root = mkdtempSync('/tmp/portato-release-test-');
  const git = (...args) => execFileSync('git', args, { cwd: root });
  const allowed = () => Bun.spawnSync(['sh', guard], { cwd: root }).exitCode === 0;
  try {
    git('init', '-q');
    expect(allowed()).toBe(false);
    git('remote', 'add', 'origin', 'git@github.com:gertyhiler/portato.git');
    expect(allowed()).toBe(false);
    git('remote', 'set-url', 'origin', 'git@github.com:portuber/portato.git');
    expect(allowed()).toBe(true);
    git('remote', 'set-url', '--push', 'origin', 'https://github.com/gertyhiler/portato.git');
    expect(allowed()).toBe(false);
    git('remote', 'set-url', '--push', 'origin', 'https://github.com/portuber/portato.git');
    expect(allowed()).toBe(true);
    git('remote', 'set-url', '--add', '--push', 'origin', 'git@github.com:gertyhiler/portato.git');
    expect(allowed()).toBe(false);
  } finally { rmSync(root, { recursive: true, force: true }); }
});
