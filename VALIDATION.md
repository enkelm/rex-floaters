# v0.1.0 validation

Validated locally on 2026-10-30 with macOS 27.2, Rex `0.0.1793131181-gdd9a20`, fzf 0.74.5,
LuaJIT 2.1.1792588164, Python 3.15.2, and ShellCheck 0.11.0. These are tested versions, not minimums.

## Results

- **14 Lua tests pass, zero failures or skips.** There is no Node test runner or JavaScript runtime
  in this repository. Config fixtures use LuaJIT; integration assertions use Rex's embedded Lua.
- The entire suite passes with a deliberately failing `node` executable first on PATH. Per-fixture
  Node traps also confirm shortcuts and picker execution do not invoke it.
- Config fixtures check both chunk naming conventions, window-scoped toggling after reload,
  preservation of unrelated/tiled panes, placement, and guarded focus/zoom restoration.
- Real Rex servers and Python PTYs check umbrella selection/cancellation, exact selected paths,
  direct launch from main/linked/nested/single-repository/worktree-only locations, error visibility
  until acknowledgement, exit status, and the configured floating action's actual lifecycle.
- The locally included Git helpers are exercised against installed Worktrunk when available,
  both supported JSON schemas, invalid output fallback, and Git-only discovery.
- `sh scripts/test.sh --unit` and `sh scripts/check.sh` pass. Checks cover Lua compilation,
  shell syntax/ShellCheck, and Python syntax without Node.

Lazygit test contracts were moved from the previously passing combined Hunk suite, rather than
removed. Git/fzf helpers are included locally, so none of these tests resolves through `rex-hunk`
or the dotfiles implementation. The Lazygit executable is a synthetic terminal fixture in integration
tests; no user Git repository or Lazygit configuration is changed.

## Reproduce

```sh
sh scripts/check.sh
sh scripts/test.sh --unit
sh scripts/test.sh
```

The entry point starts a disposable runner server; tests start only isolated servers, temporary Git
repositories, and synthetic PTYs. They never reload or stop the user's server. Python is a test-only
PTY transport, not part of the plugin runtime. No Node, npm, or Lua packages are required.

## Limits

Hosted CI is configured but has not run remotely. Full integration tests require Rex/fzf on an
already provisioned macOS host. Minimum versions, Linux, native Windows, mixed-version remote clients,
and clean-machine provisioning have not been validated. No public remote or release upload exists.
Licensed under MIT; see LICENSE and NOTICE.md.
