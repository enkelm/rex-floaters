# Validation

## v0.1.1 setup configuration

Validated locally on 2026-11-01 with Rex `0.0.1793299046-g2307b7`. Version 0.1.1 adds setup options.
The original `v0.1.0` tag is preserved.

- New option assertions failed before implementation. Config fixtures now pass for custom/disabled
  shortcuts, repeated setup, copied input, preserved unrelated keys, and validation before mutation.
- The native popup case verifies the replacement chord in Rex's resolved keymap and the custom
  bounds in the actual floating layout, then checks cancellation/focus restoration.
- All **14 cases pass**, zero failures/skips; Lua/shell/Python syntax and lint checks also pass.
- README Lua examples pass the installed Rex's `config check`; shell examples parse and local
  documentation links resolve. Installation pins `v0.1.1`, with contributor instructions for
  branching from the tagged checkout.

## v0.1.0 release record

Validated locally on 2026-10-30 with macOS 27.2, Rex `0.0.1793131181-gdd9a20`, fzf 0.74.5,
LuaJIT 2.1.1792588164, Python 3.15.2, and ShellCheck 0.11.0. These are tested versions, not minimums.

### Results

- **14 Lua tests pass, zero failures or skips.** There is no Node test runner or JavaScript runtime
  in this repository. Config fixtures use LuaJIT; integration assertions use Rex's embedded Lua.
- The entire suite passes with a deliberately failing `node` executable first on PATH. Per-fixture
  Node traps also confirm shortcuts and picker execution do not invoke it.
- A clean Git clone with spaces in its path passed all 14 Lua cases and checks from `/tmp`, without
  resolving any module through the source checkout or the Hunk repository.
- Config fixtures verify inert `require("rex-lazygit")`, explicit `setup()`, both chunk naming
  conventions, and cached-module setup while popups are open. Integration uses this same module
  interface through a named symlink. Other contracts include window-scoped toggling after reload,
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

### Reproduce

```sh
sh scripts/check.sh
sh scripts/test.sh --unit
sh scripts/test.sh
```

The entry point starts a disposable runner server; tests start only isolated servers, temporary Git
repositories, and synthetic PTYs. They never reload or stop the user's server. Python is a test-only
PTY transport, not part of the plugin runtime. No Node, npm, or Lua packages are required.

### Limits

Hosted CI is configured but has not run remotely. Full integration tests require Rex/fzf on an
already provisioned macOS host. Minimum versions, Linux, native Windows, mixed-version remote clients,
and clean-machine provisioning have not been validated. No public remote or release upload exists.
Licensed under MIT; see LICENSE and NOTICE.md.
