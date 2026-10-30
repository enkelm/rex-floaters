# Floating Lazygit for Rex

Standalone **v0.1.0**, licensed under [MIT](LICENSE). No Hunk, Pluck, Pi, or Node dependency.

Press **Cmd+Shift+G**, or choose **Lazygit: Toggle Floating Window** in Rex's command palette.
Each Rex window has at most one floating Lazygit: press once to open it, and press again to close it,
even from another pane in the same window. Other windows have independent popups. The toggle
finds live popups after a config reload too; it does not rely on an in-memory list.

Lazygit opens in a centered floating terminal over the invoking pane's window, using that
terminal's foreground working directory (including a Git worktree or repository subdirectory).
The tiled panes are not split or resized. This calls `lazygit`, the executable behind `lg`.
The shortcut closes the popup directly, rather than typing a key into a potentially open Lazygit dialog.
The floating-terminal label `Lazygit` is reserved for this extension; tiled terminals are never toggled.

### Repository and worktree picker

Inside a Git checkout or any subdirectory of it, Lazygit opens immediately in the invoking directory.
This applies even when the repository has several worktrees: use **Lazygit's own worktree controls**
to switch between them.

The fzf picker appears only when launched outside a checkout, from an **umbrella directory containing
multiple distinct repositories**. It uses an fzf picker in single-selection mode. Rows show
`repository / branch`, clean/modified status, and the full checkout path.

- **Up/Down** moves between worktrees.
- Type to filter by repository, branch, or path. **Space** toggles; **Tab/Shift+Tab** toggles and moves.
  Selecting another row replaces the previous selection. **Enter** opens Lazygit there.
- **Ctrl+Space** inserts a search space; **Ctrl+X** clears the selection.
- **Esc** cancels and closes the popup. The toggle shortcut closes the picker too.
- Multiple worktrees of one repository count as **one repository**, not multiple choices requiring a picker.
  If an umbrella contains only that repository, Lazygit opens its main checkout under the umbrella,
  or another checkout there if the main checkout is elsewhere.

Umbrella discovery includes repositories below the starting directory and their registered linked
worktrees, even outside it. Discovery is bounded to three levels and 1,500 directories, skipping
dependency/build folders. When Worktrunk is installed, the picker uses its local-only JSON worktree listing, matching
the upstream Worktrunk extension. Missing Worktrunk, failed commands, and unsupported output fall back
to Git. Worktrunk's creation/switching actions remain separate: this picker does not create, switch,
fetch, or modify worktrees. The picker and Lazygit use the same floating terminal, so selection never
creates a second popup.

Quit Lazygit with **q** to close the popup too—there is no shell prompt left behind.
The previous focus and zoom are restored unless you have moved to another pane or tab,
or the original pane has closed. A failed launch keeps its error visible until you press Enter.
This uses your existing Lazygit configuration and runs on the Rex server's machine.

## Setup

Requires Rex, Git, fzf, `lazygit`, a POSIX shell, and macOS command-line tools including `realpath`,
`openssl`, and `uuidgen`. Worktrunk is optional. Git discovery and picker helpers ship in `lib/`;
there is no dependency on another extension or repository. Both the shortcut and terminal workflow
use Rex's embedded Lua through `rex do`: no Node, LuaJIT, or separate Lua interpreter starts on a shortcut.

Tested on macOS 27.2 with Rex `0.0.1793131181-gdd9a20` and fzf 0.74.5. These are tested versions,
not minimum requirements. Linux, native Windows, and mixed-version remote clients are not yet validated.
Popups use your login shell's PATH. The launcher does not load nvm or resolve Node; `REX_LAZYGIT_NODE`
is retired. `REX_HUNK_REX` names an explicit Rex executable and `REX_BIN_DIR` prepends a PATH directory.
The shared picker respects `REX_HUNK_FZF` as an explicit fzf executable; inherited `FZF_DEFAULT_OPTS`
and `FZF_DEFAULT_OPTS_FILE` are ignored so custom bindings cannot change selection behavior or output.

Clone into a fresh destination; substitute a supplied URL or local source checkout:

```sh
extension="${XDG_CONFIG_HOME:-$HOME/.config}/rex/rex-lazygit"
git clone --branch v0.1.0 /path/to/rex-lazygit "$extension"
```

Append to your **existing** Rex `init.lua` (or the file named by `REX_CONFIG`), without replacing it:

```lua
require("rex-lazygit").setup()
```

Rex resolves the module from its config directory, just like `rex-worktrunk`. A development checkout
can be symlinked to the path above. Custom module locations can use
`package.path = "/path/to/modules/?/init.lua;" .. package.path` before requiring it. Keep the complete checkout in place: launchers
and libraries resolve relative to it. Do not also load the former Hunk-bundled copy.

Requiring the module is inert. `setup()` registers its action and default shortcut and returns the
module. Repeated setup after config reload preserves discovery/toggling of an already-open popup.

Then run:

```sh
rex config check
rex config reload
```

To use another shortcut, call `rex.unbind("cmd+shift+g")` followed by
`rex.bind("your-chord", "lazygit_open")` after loading the module.
The same action can be invoked explicitly from a Rex terminal:

```sh
rex do lazygit_open -s "$REX_SESSION" -b "$REX_BLOCK"
```

## Update or uninstall

Inspect local changes before fetching and checking out a new release tag; do not reset a modified
checkout. Check and reload Rex after updating. To uninstall, close the popup, remove the
`require("rex-lazygit").setup()` line, reload Rex, then remove the checkout. Your Lazygit config and Git repositories remain untouched.

## Validation

Tests and assertions are Lua, run in Rex's embedded Lua. Development tools are Rex, Git, fzf,
LuaJIT (config fixtures/syntax), ShellCheck, and Python 3 (real PTY transport only). No Node, npm,
or third-party Lua packages are needed.

```sh
sh scripts/check.sh
sh scripts/test.sh --unit  # config contracts only; no Rex installation needed
sh scripts/test.sh         # disposable isolated Rex servers, Git repos, fzf, and PTYs
```

Scripts work from any caller directory and never reload or mutate your live Rex session. Tests
retain the original toggle, placement, focus/zoom, direct-launch, umbrella selection, cancellation,
error-acknowledgement, and Git/Worktrunk contracts. A Node trap verifies it is never launched.
See [VALIDATION.md](VALIDATION.md) for release evidence and [NOTICE.md](NOTICE.md) for provenance.
