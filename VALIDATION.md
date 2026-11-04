# Validation

## Unreleased: bundled Pluck

Validated locally on macOS with Rex `0.0.1793420730-g6d0d9a`, API revision 9.

- **43 cases pass, zero failures/skips**, including the existing Lazygit, btop, and Television cases.
  Pluck uses the shared Floaters launcher and cleanup, not its former standalone setup or launcher.
- Native Pluck coverage checks the default shortcut, automatic full-tab zoom, hide/show with the same
  process, config reload, cancellation, original focus/zoom restoration, and unchanged source output
  and terminal size. A pre-zoomed source excludes its hidden neighbor.
- Real PTYs verify exact OSC 52 clipboard bytes, UTF-8 tokens, large viewports, cancellation, ignored
  paste, multi-letter hints, Backspace, resize/clipping, tiny terminals, paged captures, split/floating
  composition, other-tab exclusion, and rejection of a mismatched server. The tests intercept OSC 52
  instead of writing a user's clipboard.
- All 766 official Unicode 17 grapheme vectors run, along with token, snapshot, and visibility checks.
  A visibility regression confirms minimized floaters neither supply tokens nor hide visible sources;
  the standalone planner reproduces the incorrect minimized-overlay capture.
- `sh scripts/test.sh --unit` and `sh scripts/check.sh` pass. The unit command includes Pluck without
  requiring Rex. Unicode data, vectors, their license, and the optional regeneration script are local.
- The checks and full suite also pass from `/tmp` against a separate copy in a path containing spaces,
  with no sibling rex-pluck checkout. Documentation links resolve and Lua/shell examples parse.

### Cold-start performance

`sh scripts/test.sh --bench-pluck` measures the shipping launcher through the first complete PTY
frame. Every sample starts a new Rex/Lua process; it doesn't reuse an open picker, preloaded modules,
or cached captures. Three samples per case produce these local medians:

| Source viewport | Before | After |
| --- | --- | --- |
| 120×40 ASCII | 425 ms | 197 ms |
| 240×80 ASCII | 1,416 ms | 392 ms |
| 240×80 mixed Unicode | 1,418 ms | 400 ms |
| 240×80 mixed Unicode + 1,000 history rows | 4,713 ms | 489 ms |

The same benchmark fails its 750 ms budget against a separate copy with the unoptimized renderer,
snapshot parser, and token scanner, and passes all four cases after optimization. Its target-count
check prevents a faster result from silently dropping unique copy targets. Fixture setup is outside
the timed interval; launcher/process startup and the PTY transport are included.

Profiling identified repeated Unicode work and a renderer that searched every token for every cell,
not slow Rex capture calls. The renderer now walks ordered tokens once. ASCII takes direct paths
through segmentation, width measurement, and wrapping, including ASCII pairs inside mixed text.
Snapshot layout walks backward from the latest screen instead of wrapping old history. VT cleanup
uses native string scans and byte patterns rather than decoding every character in the capture.
The token scanner decodes each line once for paths and filenames and rejects nested path starts
before rescanning their tails. No result cache or prewarming was added.

All 43 ordinary cases, the 766 Unicode vectors, unit checks, and syntax/lint checks still pass.
A deterministic comparison of 3,000 mixed ASCII/Unicode/control and arbitrary-byte inputs also
matches the original sanitization, grapheme, width, wrapping, full/partial-screen, and token results.
Timing checks remain opt-in for provisioned hosts.

Validation uses only disposable servers and synthetic panes; it doesn't edit the sibling rex-pluck
checkout or live user configuration. Actual client clipboard writes, unusual fonts, Linux, native
Windows, and mixed-version remote clients have not been validated.

### Push-readiness recheck

Rechecked on macOS with Rex `0.0.1793632279-ge7974b`, API revision 10:

- Syntax/lint checks, all 11 standalone unit cases, and all 43 full-suite cases pass with zero
  failures or skips, including the 766 Unicode grapheme vectors.
- Checks, unit tests, and the full suite also pass from `/tmp` against an independent copy in a
  path containing spaces, without a sibling rex-pluck checkout.
- All local links in the README, guides, and notice resolve; 14 Lua and 6 shell examples parse.
- Fresh-process benchmark medians are 193 ms (120×40 ASCII), 320 ms (240×80 ASCII), 381 ms
  (240×80 mixed Unicode), and 474 ms (mixed Unicode plus history), all below the 750 ms budget.

## v0.2.0 Rex Floaters

Validated locally on 2026-11-01 with the Rex Beta 1734 bundled server/CLI,
`0.0.1793420730-g6d0d9a`, API revision 9. Capability discovery on a disposable server confirmed
`session.set_layer_state`, including `normal`/`minimized`, targeted focus, and minimized layers
remaining in `session.view`. The live user server was already on API revision 9 and was not restarted.

- **23 integration/registration cases pass, zero failures/skips.** The real-server cases replace
  the former mocked toggle/dismiss fixtures; registration validation retains a small LuaJIT fixture.
- Directory discovery, inline named entries, actual keymaps and bounds, namespaced ownership,
  independent entries/tabs, cached live-popup discovery after reload, and unchanged process IDs
  across hide/show are covered. Old servers get an actionable API-revision error.
- Native lifecycle checks cover current-pane focus history, initial zoom restoration, hidden
  executor completion without activating an old tab, cancellation, unrelated tiled labels, and
  a surviving sibling in a split floating layer.
- Real PTYs cover single/multi-selection, cancellation, single-item fzf bypass, empty/malformed
  collectors, Lua context/selection, shell positional arguments with quotes/newlines/shell syntax,
  and nonzero exit statuses. Native fast-failure checks confirm dead terminals do not remain open.
- Television 0.15.9 checks cover one row per tab, a right-side bounded composite of every tiled split,
  palette and truecolor full-screen terminal snapshots, remembered-pane focus, cancellation, stale pane
  handling, exclusion of owned floater terminals, and cross-session server focus.
- Existing Lazygit repository/worktree discovery and optional Worktrunk schema/fallback cases
  remain covered. Lazygit is now a normal collector/executor definition. The bundled btop definition
  is exercised with a synthetic executable, missing fzf, and a failing Git trap: no selection arguments
  or Git calls are introduced.
- The new registration contract fails against the previous HEAD with `unknown setup option entries`.
- `sh scripts/check.sh`, `sh scripts/test.sh --unit`, and the full suite pass in this checkout
  and in a separate copy whose path contains spaces. All 13 README Lua/shell code blocks parse and
  local documentation links resolve.

Reproduce with a compatible Rex executable (the PATH binary may still be an older channel):

```sh
sh scripts/check.sh
sh scripts/test.sh --unit
REX_FLOATERS_REX=/absolute/path/to/api-9/rex sh scripts/test.sh
```

All integration servers, repositories, commands, and terminal output are disposable fixtures.
No live user configuration is reloaded by the suite. Full hosted integration, Linux/native Windows,
actual btop/Lazydocker/Memex rendering, successful originating-app cross-session handoff with Remote
Control enabled, and mixed-version remote hosts have not been validated. The live app's disabled Remote
Control setting was confirmed to refuse `client.perform` with Rex's documented 403 response. Setup supports reconfiguration,
but removed palette actions require a full config reload to disappear; stale actions cannot run
removed executors. Runtime errors close the popup rather than retaining an acknowledgement prompt.
The records below describe prior releases, not the new configuration interface.

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
