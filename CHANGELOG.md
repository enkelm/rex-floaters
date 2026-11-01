# Changelog

## 0.2.0 - 2026-11-01

- Rename the extension and module to `rex-floaters`; replace `bindings.open` with named definitions.
- Discover definitions from a configurable directory, or accept a named `entries` array in setup.
- Add optional Lua collectors, configurable fzf/Television selection, and Lua/shell/argv executors.
- Pass selected values without shell interpolation; expose terminal-aware `ctx.exec` to Lua executors.
- Move Lazygit into this definition format and include a collector-free, unbound btop example.
- Add an unbound Rex tab picker using Television, with truecolor full-screen snapshots of every tiled split and remembered-pane focus across sessions; originating-app navigation uses the pane owner and Rex Remote Control.
- Show/hide specific floating layers without restarting their processes, including after reload.
- Require a Rex server/CLI with API revision 9 and `session.set_layer_state`.
- Close on executor completion or failure, including while hidden; remove the old error acknowledgement.
- Restore focus from native layer history instead of a stale launch-time pane.
- Replace mocked lifecycle fixtures with real-server lifecycle and collector/executor integration checks.

## 0.1.1 - 2026-11-01

- Accept one optional setup table with `bindings.open`, shortcut disabling, and popup `bounds`.
- Reject invalid options before registration and replace old shortcuts on reconfiguration.
- Verify custom bindings in the actual Rex keymap and bounds in the actual floating layout.
- Reorganize the README around installation, configuration, usage, troubleshooting, and contributing.

## 0.1.0

- Extract the floating Lazygit toggle into an independent MIT-licensed Rex extension.
- Configure with `require("rex-lazygit").setup()`; require is inert and setup can run again on reload.
- Include local Git/fzf helpers without requiring the Hunk, Pi, or Worktrunk extensions.
- Preserve direct launch inside checkouts and umbrella-only multi-repository selection.
- Keep window-scoped toggling, guarded focus/zoom restoration, and visible launch errors.
- Migrate config, Git discovery, actual popup, and real-PTY regressions to Lua; no Node test runner.
- Add additive installation docs, shell checks, and Lua config CI.

This release has not been published to a remote.
