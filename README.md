# Floating Lazygit for Rex

**v0.1.1** · [MIT](LICENSE)

Press **Cmd+Shift+G** to open Lazygit over your current Rex tab. Press it again to close the popup.
Your tiled panes stay where they are. No Hunk, Pluck, Pi, or Node dependency.

[Install](#install) · [Configure](#configure) · [Use](#use) · [Troubleshoot](#troubleshoot) · [Develop](#develop)

## Install

You need Rex, Git, fzf, `lazygit`, and the standard tools `sh`, `realpath`, `openssl`, and `uuidgen`.
Worktrunk is optional. On macOS, `brew install git fzf lazygit` installs the Git tools.
Clone into Rex's configuration directory:

```sh
git clone https://github.com/enkelm/rex-lazygit ~/.config/rex/rex-lazygit
```

Add to `~/.config/rex/init.lua`, keeping your existing configuration:

```lua
require("rex-lazygit").setup{ bindings = { open = "cmd+shift+g" } }
```

Turn on **Remote Control** in **Rex → Settings → Rex Server**, then reload:

```sh
rex config reload
```

Rex loads modules from beside the `init.lua` it opens. If `init.lua` is a symlink, clone next to
the link, not its target. With `XDG_CONFIG_HOME` or `REX_CONFIG`, use that config directory instead
of `~/.config/rex`. The tools must be on the PATH your login shell sets on the Rex server's machine;
an interactive `lg` alias is not enough.

Press **Cmd+Shift+G** to toggle Lazygit, or choose **Lazygit: Toggle Floating Window** from the
command palette. Any Rex key chord or sequence can be used; see [Configure](#configure).
If it is already installed, [update it](#update-or-uninstall) instead of cloning over it.
Do not also load the older Hunk-bundled Lazygit module.

## Configure

`setup` accepts one optional table. This is the complete configuration with default values:

```lua
require("rex-lazygit").setup{
  bindings = {
    open = "cmd+shift+g",
  },
  bounds = { 0.05, 0.05, 0.9, 0.9 },
}
```

Use this in place of the minimal setup call, not in addition to it. Despite the name `open`, this
binding both opens and closes the popup.

| Option | Default | Meaning |
| --- | --- | --- |
| `bindings.open` | `"cmd+shift+g"` | Toggle this tab's Lazygit popup. Set to `false` to leave the action unbound. |
| `bindings` | See above | Set the whole field to `false` to register the action without shortcuts. |
| `bounds` | `{ 0.05, 0.05, 0.9, 0.9 }` | `{ x, y, width, height }`, as fractions of the Rex window. |

For a different shortcut and a smaller popup:

```lua
require("rex-lazygit").setup{
  bindings = { open = "ctrl+shift+g" },
  bounds = { 0.1, 0.15, 0.8, 0.7 },
}
```

That places the popup 10% from the left and 15% from the top, at 80% width and 70% height.
Bounds must be exactly four finite numbers. Width and height must be positive, and the entire
rectangle must fit inside `0..1`. New bounds apply the next time a popup is created.

For palette-only use:

```lua
require("rex-lazygit").setup{ bindings = false }
```

You can then manage shortcuts yourself with `rex.bind("ctrl+shift+g", "lazygit_open")` after setup.
The same toggle is available from a Rex terminal:

```sh
rex do lazygit_open -s "$REX_SESSION" -b "$REX_BLOCK"
```

`setup()` and `setup{}` use defaults. Omitted fields also use defaults; another setup call starts
from defaults rather than patching the previous call. Your table is copied, and reconfiguration
removes the extension's old chords without clearing unrelated keys. Unknown options and invalid
values are rejected before registration. Key strings use Rex's key-chord syntax.

Importing alone does nothing. `setup` registers the action and bindings, returns the module, and
can run again after a config reload. The toggle still finds an already-open popup after reload.

For a key sequence like a tmux prefix, set `bindings.open = "ctrl+space>g"`. Bind the prefix pressed
twice to send it to the terminal:

```lua
rex.bind("ctrl+space>ctrl+space", "pane.send_key", { key = "ctrl+space" })
```

## Use

Focus the terminal whose working directory you want to use, then run the toggle. Each Rex tab
(called a window in the API) has at most one floating Lazygit. The shortcut closes that popup even
when invoked from another pane in the same tab; other tabs have independent popups.

| Where you launch it | What happens |
| --- | --- |
| Inside a Git checkout, including a subdirectory or linked worktree | Lazygit opens immediately in that directory. |
| Inside a repository that has multiple worktrees | Lazygit still opens immediately. Use Lazygit's own worktree controls to switch. |
| Outside a checkout, in a parent directory containing several distinct repositories | An fzf picker lets you choose a checkout first. |
| In a parent directory containing only one repository | Lazygit opens that repository's main checkout under the parent, or another checkout there if its main checkout is elsewhere. |

The directory comes from the focused terminal's foreground process, falling back to its shell.
The popup does not split or resize tiled panes. Quit Lazygit with **q**, or run the toggle again,
to close it. The shortcut closes the popup directly, without typing into an open Lazygit dialog.

When Lazygit exits, the previous focus and zoom are restored if you have not moved to another pane
or tab and the original pane still exists. A failed launch keeps its error visible until Enter.
The floating-terminal label `Lazygit` is reserved for this extension; tiled terminals are never toggled.

### Repository picker keys

Rows show `repository / branch`, clean/modified status, and the full checkout path. Selection is
single-choice. The picker and Lazygit share one floating terminal; choosing a checkout does not
create a second popup.

| Key | Action |
| --- | --- |
| Up / Down | Move between rows. |
| Type | Filter by repository, branch, or path. |
| Space | Select or deselect the current row. Selecting another replaces the previous selection. |
| Tab / Shift+Tab | Toggle selection and move. |
| Enter | Open Lazygit in the chosen checkout. |
| Ctrl+Space | Insert a space into the search. |
| Ctrl+X | Clear selection. |
| Esc or the toggle shortcut | Cancel and close the popup. |

Several worktrees of one repository count as one repository, not several repositories requiring
a picker. Discovery includes repositories below the starting directory and their registered linked
worktrees, including those outside it. It stops after three levels or 1,500 directories and skips
common dependency/build directories.

When installed, Worktrunk supplies its local-only JSON worktree listing. Missing Worktrunk, command
failures, and unsupported output fall back to Git. This extension does not create, switch, fetch,
or modify worktrees during discovery. No Worktrunk extension needs to be installed.

## Troubleshoot

| Problem | What to check |
| --- | --- |
| `module rex-lazygit not found` | The whole checkout must be named `rex-lazygit` beside the active Rex config file. Check the path reported by `rex config check`, especially with `REX_CONFIG`. |
| `lazygit` or `fzf` cannot be found | Install the executable on the Rex server's machine and make it available on the login-shell PATH. A shell alias is not enough. |
| A setup option is ignored on an older checkout | Update to `v0.1.1` or later; `v0.1.0` predates setup options. |
| No picker appears in a multi-worktree repository | This is intentional. The picker is only for multiple distinct repositories outside a checkout. |
| The working directory cannot be determined | Focus a running terminal with a local foreground process, then try again. |
| New bounds do not affect an open popup | Close it with the toggle and reopen. Bounds are applied when the popup is created. |

For unusual installations, the launcher supports these existing environment overrides:

| Variable | Purpose |
| --- | --- |
| `REX_BIN_DIR` | Prepend a directory containing Rex to the launcher's PATH. |
| `REX_HUNK_REX` | Use an explicit Rex executable. The name is retained for compatibility; Hunk is not required. |
| `REX_HUNK_FZF` | Use an explicit fzf executable, also with a compatibility name. |

The picker ignores `FZF_DEFAULT_OPTS` and `FZF_DEFAULT_OPTS_FILE` so user fzf bindings cannot change
its selection rules or output format. Lazygit's own configuration is unchanged.

## Develop

The installation is already a Git checkout. Create a branch before editing:

```sh
cd "${XDG_CONFIG_HOME:-$HOME/.config}/rex/rex-lazygit"
git switch -c my-change
```

No build step is required. To contribute, fork this repository and push your branch to your fork,
then open a pull request. To work elsewhere, replace the installed directory with a symlink to
your checkout after moving the old one somewhere safe. Do not delete local edits. For other module
locations, prepend `"/path/to/modules/?/init.lua;"` to `package.path` before requiring.

### Tools and checks

Development needs LuaJIT, ShellCheck, and Python 3 in addition to the runtime tools. Python only
transports test PTYs; assertions are Lua. On macOS with Homebrew:

```sh
brew install luajit shellcheck python
```

From the checkout:

```sh
sh scripts/test.sh --unit  # LuaJIT config/toggle/restore checks; Rex is not needed
sh scripts/check.sh        # Lua, shell/ShellCheck, and Python syntax
sh scripts/test.sh         # full suite with real Rex servers, Git repos, fzf, and PTYs
```

Tests create disposable Rex servers, temporary repositories, and a synthetic Lazygit executable.
They do not reload or stop your server, change your Lazygit configuration, or mutate your working
repositories. A Node trap checks that runtime workflows never invoke Node. There are no npm or
third-party Lua packages to install. Scripts also work from other directories and paths with spaces.

### Where to change things

| Files | Responsibility |
| --- | --- |
| `init.lua`, `lib/config.lua` | Public setup, bindings, popup geometry, and live-popup discovery/toggling. |
| `launch.sh`, `cli.lua` | Launch lifecycle and choosing the checkout used by Lazygit. |
| `dismiss.lua` | Guarded focus and zoom restoration. |
| `lib/git.lua` | Repository/worktree discovery and optional Worktrunk integration. |
| `lib/picker.lua`, `lib/util.lua` | fzf interaction, terminal/process helpers, and safe temporary state. |
| `tests/` | Lua assertions, Git fixtures, and real Rex/PTY integration. |

After edits, run `rex config check` and `rex config reload`, then close and reopen any existing popup.
For a bug fix, add a regression that fails before the fix, then run the checks and full suite.
Reports should include `rex version`, the OS, the directory layout that triggers the problem, and
the exact error with private paths or other secrets redacted.

The extension uses Rex's embedded Lua, with no Node, npm, or separate Lua runtime dependency.
It is tested on macOS; Linux, native Windows, and mixed-version remote clients are not yet validated.
See [VALIDATION.md](VALIDATION.md) for tested versions, results, and platform limits. Hosted CI covers
config tests and lint, not full Rex integration, and has not yet been run remotely.

## Update or uninstall

Inspect local changes and save them before switching versions. Choose the desired release from
[CHANGELOG.md](CHANGELOG.md), then fetch and check out its tag:

```sh
extension="${XDG_CONFIG_HOME:-$HOME/.config}/rex/rex-lazygit"
git -C "$extension" status --short
# Once your local changes are safely committed or stashed:
git -C "$extension" fetch --tags origin
git -C "$extension" switch --detach v0.1.1  # replace with the release you want
rex config check
rex config reload
```

Review [CHANGELOG.md](CHANGELOG.md) before updating. Never reset a modified checkout just to update it.
Close and reopen any running popup to use the new launcher/runtime code.

To uninstall, close the popup, remove its setup call from your Rex config, and reload Rex. You can
then remove the checkout. Your Lazygit configuration and Git repositories are left untouched.

## License

[MIT](LICENSE). See [NOTICE.md](NOTICE.md) for provenance and third-party tools.
