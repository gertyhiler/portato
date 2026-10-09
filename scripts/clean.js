import { lstatSync, rmSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { execFileSync } from 'node:child_process';

export const artifacts = ['bin', 'dist', 'cover.out', 'macos/.build/out',
  'macos/.build/arm64-apple-macosx', 'macos/.build/x86_64-apple-macosx'];

export function clean(root) {
  root = resolve(root);
  const targets = artifacts.map(relative => {
    const target = resolve(root, relative);
    for (let part = target; part !== root; part = dirname(part)) {
      if (lstatSync(part, { throwIfNoEntry: false })?.isSymbolicLink()) {
        throw new Error(`Refusing symlink in cleanup path: ${relative}`);
      }
    }
    if (execFileSync('git', ['ls-files', '--', relative], { cwd: root }).length) {
      throw new Error(`Refusing tracked cleanup target: ${relative}`);
    }
    return target;
  });
  for (const target of targets) rmSync(target, { recursive: true, force: true });
}

if (import.meta.main) clean(process.cwd());
