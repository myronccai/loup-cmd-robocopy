# AGENTS.md

This repository recreates the Windows `robocopy` command (copy and mirror
directory trees) in the Loup programming language, as part of the loup-cmd
series of example applications. The program is `host.dual` Loup built as a
native executable for Linux, with cmd's switch, wildcard, path and message
conventions. It plans a whole job first (a list of actions), then executes
it (or with `/L` only reports it), and returns robocopy's exit bit mask.
`source/win/` is a copy of the shared Windows code (master: loup-cmd-type).

## Skills

| Skill | Location | Use it when |
|-------|----------|-------------|
| `loup-programmer` | [skills/loup-programmer/SKILL.md](skills/loup-programmer/SKILL.md) | Writing, reviewing, debugging or explaining Loup code: `.lpscr`, `.loup`, `.lphc`, `.lpweb` or `.lpfree` source files, `.lppkg` manifests, `@mode(...)` directives, or the `loup` / `loup-bootstrap` commands. |

Read `skills/loup-programmer/SKILL.md` before writing or changing any Loup code
in this repository. It links to detailed references under
`skills/loup-programmer/references/` for syntax, types and ownership, execution
modes and projects, errors and diagnostics, the standard library, and common
mistakes. Load those only as needed.

## Code layout

```text
.
├── package.lppkg                # Loup manifest: name, version, toolchain, [build] entry, [test] pattern
├── Makefile                     # run, check, test, build, e2e, ci, clean
├── source/                      # all Loup code; modules import each other by path from here
│   ├── main.loup                # entry point: func main() calls run(runtime.args())
│   ├── appinfo.loup             # APP_NAME, APP_VERSION, APP_SUMMARY, exit bits 1 2 4 8 and 16
│   ├── cli/
│   │   ├── args.loup            # struct Options, robocopy_switches(), parse_args(), file_patterns(), option_words()
│   │   ├── usage.loup           # usage() (the /? summary), version_line()
│   │   └── app.loup             # run(): parse, fatal errors, /? and --version, run_robocopy
│   ├── commands/
│   │   ├── plan.loup            # struct Action, plan(): the sync planner (writes nothing)
│   │   ├── execute.loup         # execute(): copies, purges, moves, counts; delete_tree(), copy_checked()
│   │   ├── parallel.loup        # /MT: copy_all() on Thread.spawn workers, synchronized class CopyLog
│   │   ├── report.loup          # struct Stats, header_lines(), dir_line(), file_line(), summary_lines()
│   │   ├── robocopy.loup        # run_robocopy(), exit_bits()
│   │   ├── clock.loup           # now_long(), now_stamp() via `date`; format_elapsed(Duration)
│   │   └── fspaths.loup         # current_dir() via `pwd`, absolute_path(), is_within()
│   └── win/                     # shared Windows code (a copy; see below)
│       ├── switches.loup        # cmd switch parser: /S -s /A:H /AH /T 10 /S/Q /? --
│       ├── wildcard.loup        # Win32 wildcard matcher, expand(), find_recursive()
│       ├── paths.loup           # fs_path(), display_path(), split/join helpers
│       └── messages.loup        # Windows message texts
├── tests/
│   ├── *_test.loup              # unit tests: func test_*(): void (win_*_test.loup test source/win/)
│   └── e2e.sh                   # end-to-end tests of the native binary
├── specs/robocopy/              # requirements.md, design.md, tasks.md
├── skills/loup-programmer/      # the Loup skill and its references
├── .github/workflows/ci.yml     # installs Loup and runs `make ci`
└── build/                       # build output (git-ignored); unit tests write fixtures to build/tmp/
```

## Build, run and test

Prerequisites: Loup 1.26.0 (`loup` and `loup-bootstrap` on `PATH`), `make`,
and `clang` 17 or later for native builds.

Loup Lite comes from <https://github.com/code-craft-ai-company/loup-releases>;
[README.md](README.md#installing-loup-lite) has the install commands.

| Task | Command | Notes |
|------|---------|-------|
| Run from source | `make run ARGS="src dst /MIR /L"` | `loup run source/main.loup -- ARGS` |
| Type-check | `make check` | checks `source/main.loup` and every module it imports; tests are not checked |
| Run all tests | `make test` | every `tests/*_test.loup`, one at a time (`--no-parallel`) |
| Run matching tests | `make test TEST_ARGS="--filter plan"` | tests whose name contains `plan` |
| Run one test file | `make test TEST_ARGS="--file tests/plan_test.loup"` | |
| Build | `make build` | native binary at `build/robocopy` |
| Run the binary | `build/robocopy src dst /MIR /L` | quote `\`, `*`, `?` and `/?` in the shell |
| End-to-end tests | `make e2e` | runs `tests/e2e.sh build/robocopy`: stdout byte for byte, stderr exactly |
| Everything CI runs | `make ci` | check, test, build, e2e, then `build/robocopy --version` |
| Clean | `make clean` | removes `build/` and `.temp/` |

Run `make ci` before reporting a change as done. `loup run` and the native
build do not support the same things, so a change can pass `make test` and
still fail `make build`.

Do not call `loup test` or `loup check` directly on Linux x86-64. There `loup`
is the self-hosted driver: it refuses `check`, and its test runner cannot
resolve this project's imports. The Makefile uses `loup-bootstrap` (Stage0) for
both, and sets `LOUPPATH=source` for tests. Keep `--no-parallel`: Stage0's
parallel test runner fails these tests at random.

## Making a change

1. Update the spec in `specs/robocopy/` (see [specs/README.md](specs/README.md)).
2. Change the code under `source/`.
3. Add or update unit tests in `tests/` and cases in `tests/e2e.sh`.
4. Run `make ci`.
5. Tick the finished tasks in the spec's `tasks.md`.

Keep the two phases apart: `plan` only reads and returns actions, so unit
tests can check them; `execute` is the only code that writes, and every
`io.fs` write is checked afterwards (natively it fails silently, in Stage0
it throws). Deletion goes through `delete_tree`, which never follows a
symbolic link and calls `removeDir` only on an empty directory: native
`removeDir` follows links. End-to-end fixtures, and anything a test purges
or moves, live under `$TMP` only.

`source/win/` is a copy of the shared Windows code. Do not change it here
alone: changes go to the master copy in loup-cmd-type and
`ccai-examples/shared/windows/` first.

## Conventions

- Every source file is `@mode(host.dual)` with the `.loup` extension. Only
  `source/main.loup` has a `main()`.
- Modules import each other by path from `source/`:
  `from win.switches import (parse_switches);`. Tests import them the same
  way. Do not use relative imports (`from .args import ...`): the
  self-hosted `loup run` on Linux x86-64 fails on them.
- Windows conventions: switches via `win.switches` (a `/X` that is not
  declared is a path); operands go through `fs_path()` before file access;
  every printed path goes through `display_path()`; messages use Windows'
  wording from `win.messages`; usage errors are ERRORLEVEL 1.
- Struct fields read from another module must be `pub`.
- The native build supports less than `loup run` does. For example,
  `list.is_empty()` fails native codegen (`E-CODEGEN-UNHANDLED-METHOD`; use
  `len() == 0`), a `sort` comparator that captures a list of structs crashes,
  `system.text.parseInt` does not link, and `IoError` cannot be caught: check
  `isFile`/`isDir` before reading. A struct holding a list (`Options`,
  `Stats`) is deep-copied on every call natively: pass it as `edits` or
  pass its lists (`Flags` holds scalars only). Build structs only in their
  defining module (factories such as `make_action`, `make_flags`). A helper
  that grows a string parameter must copy it first (`var out = "" +
  text;`). There is no `cwd()` natively: `current_dir()` runs `pwd`.
- Keep `APP_VERSION` in `source/appinfo.loup` equal to `version` in
  `package.lppkg`.
- The skill's examples use the `loup init` layout (`src/`, `tests/`, and
  `from ..src.x import` in tests). This project uses `source/` and
  `tests/` with plain imports; follow this file.
- The skill documents toolchain 1.25.1; this template targets 1.26.0. When
  they disagree, trust the toolchain's behaviour.
