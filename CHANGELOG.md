# Changelog

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
