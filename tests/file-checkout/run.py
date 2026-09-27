#!/usr/bin/env python3
"""CLI path-checkout regression; all work happens in disposable repositories."""
from pathlib import Path
import os, subprocess, tempfile

project = Path(__file__).resolve().parents[2]
binary = Path(os.environ.get('AM_GIT_BIN', project / 'builds/bin/macos-arm/app')).resolve()
root = Path(tempfile.mkdtemp(prefix='amgit-file-checkout-'))
print(f'Fixtures: {root}', flush=True)

def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args], stderr=subprocess.STDOUT)

def fixture(name):
    repo = root / name
    repo.mkdir()
    git(repo, 'init', '-q')
    git(repo, 'config', 'user.name', 'Test')
    git(repo, 'config', 'user.email', 'test@example.invalid')
    (repo / 'file.txt').write_bytes(b'original\x00binary\n')
    (repo / 'other.txt').write_text('other original\n')
    (repo / 'nested').mkdir()
    (repo / 'nested/file with spaces.txt').write_text('nested original\n')
    git(repo, 'add', '.')
    git(repo, 'commit', '-qm', 'initial')
    (repo / 'other.txt').write_text('unrelated staged edits\n')
    git(repo, 'add', 'other.txt')
    return repo

def run(repo, *args):
    p = subprocess.run([str(binary), 'checkout', *args], cwd=repo, capture_output=True, text=True, check=True)
    return p.stdout + p.stderr

passed = 0
for kind in ('modified', 'staged', 'deleted', 'staged_deleted', 'nested', 'index', 'multiple', 'missing', 'preflight', 'traversal', 'symlink'):
    repo = fixture(kind)
    head_before = (repo / '.git/HEAD').read_bytes()
    commit_before = git(repo, 'rev-parse', 'HEAD')
    other_before = git(repo, 'ls-files', '--stage', '--', 'other.txt')
    target = repo / 'file.txt'
    expected = b'original\x00binary\n'
    target.write_text('local changes that must not leak to unrelated paths\n')
    if kind in ('staged', 'index'):
        git(repo, 'add', 'file.txt')
    if kind in ('deleted', 'staged_deleted'):
        target.unlink()
        if kind == 'staged_deleted': git(repo, 'add', 'file.txt')
    args = ['HEAD', '--', 'file.txt']
    reject = kind in ('missing', 'preflight', 'traversal', 'symlink')
    if kind == 'index':
        expected = target.read_bytes()
        target.write_text('newer unstaged edit\n')
        args = ['--', 'file.txt']
    elif kind == 'nested':
        target = repo / 'nested/file with spaces.txt'
        expected = target.read_bytes()
        target.unlink()
        target.parent.rmdir()
        args = ['HEAD', '--', 'nested/file with spaces.txt']
    elif kind == 'multiple':
        (repo / 'nested/file with spaces.txt').write_text('changed\n')
        args += ['nested/file with spaces.txt']
    elif kind == 'missing': args = ['HEAD', '--', 'missing.txt']
    elif kind == 'preflight': args += ['missing.txt']
    elif kind == 'traversal': args = ['HEAD', '--', '../outside.txt']
    elif kind == 'symlink':
        outside = root / 'outside.txt'
        outside.write_text('must survive\n')
        target.unlink()
        target.symlink_to(outside)
    before = target.read_bytes() if target.exists() else None
    index_before = (repo / '.git/index').read_bytes()
    output = run(repo, *args)
    if reject:
        assert 'checkout:' in output, (kind, output)
        assert target.read_bytes() == before, kind
        assert (repo / '.git/index').read_bytes() == index_before, kind
    else:
        assert 'Restored ' in output, (kind, output)
        assert target.read_bytes() == expected, kind
        if kind == 'index':
            assert (repo / '.git/index').read_bytes() == index_before, kind
        else:
            assert git(repo, 'diff', '--cached', '--name-only', '--', *args[2:]) == b'', kind
        if kind == 'multiple':
            assert (repo / 'nested/file with spaces.txt').read_text() == 'nested original\n'
    assert (repo / '.git/HEAD').read_bytes() == head_before, kind
    assert git(repo, 'rev-parse', 'HEAD') == commit_before, kind
    assert git(repo, 'ls-files', '--stage', '--', 'other.txt') == other_before, kind
    assert (repo / 'other.txt').read_text() == 'unrelated staged edits\n', kind
    passed += 1
print(f'PASS: {passed} checkout cases; HEAD, unrelated files and index entries preserved')
