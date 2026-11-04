# Rex Floaters

Run Lazygit, btop, or your own commands in floating Rex terminals.
Press a shortcut to open a floater, press it again to hide it, and return to the same running program
when you need it. The floater closes when the program exits.

Pluck is included too: copy URLs, paths, and other tokens from your panes by typing keyboard hints.

Configuration is plain Lua. There's no build step, and you don't need Node, npm, or a separate Lua runtime.

## Requirements

- A Rex server and CLI with **API revision 9** or later (`session.set_layer_state`). Tested with
  Rex `0.0.1793420730-g6d0d9a`.
- The programs you want to run, installed on the Rex server's machine and available on your login
  shell's PATH. Shell aliases don't count.
- Standard Unix tools, including `sh`, `find`, and `pwd`.

Each bundled floater has its own dependencies. You only need the tools for the ones you use:

| Floater | Required tools |
| --- | --- |
| Lazygit | `lazygit`, Git, and `realpath`. Also `fzf` to choose between repositories. Worktrunk is optional. |
| btop | `btop` |
| Pluck | `cat` and `stty`. Copying uses the Rex client's OSC 52 clipboard support. |
| Rex tab picker | Television (`tv`) 0.15.9. Enable **Remote Control** in Rex Settings under Rex Server to switch tabs or sessions. |

macOS is the tested platform. Linux and native Windows haven't been validated.

## Install

Clone the extension beside your active Rex `init.lua`. For the default config location:

```sh
git clone https://github.com/enkelm/rex-floaters.git ~/.config/rex/rex-floaters
```

Your config directory should look like this:

```text
~/.config/rex/
├── init.lua
└── rex-floaters/
    └── init.lua
```

If you use `XDG_CONFIG_HOME` or `REX_CONFIG`, use that config directory instead. If `init.lua` is a
symlink, put the checkout beside the link, not its target.

Add this to your existing `init.lua`:

```lua
require("rex-floaters").setup()
```

Check and reload the config:

```sh
rex config check
rex config reload
```

## Use the bundled floaters

| Floater | Default shortcut | What it does |
| --- | --- | --- |
| Lazygit | `cmd+shift+g` | Opens in the current repository, or lets you choose one when you're outside a checkout. |
| btop | Unbound | Opens the system monitor. |
| Pluck | `cmd+shift+y` | Shows keyboard hints over copyable text in the current tab's visible panes. |
| Rex tab picker | Unbound | Lists tabs across sessions, with a preview of each tab's splits. |

All four are available in Rex's command palette. To give btop or the tab picker a shortcut, add
bindings after `setup()`. Choose shortcuts that don't conflict with your existing config:

```lua
rex.bind("cmd+shift+b", "floaters_btop_toggle")
rex.bind("ctrl+shift+r", "floaters_rex_toggle")
```

Each Rex tab gets its own floaters. Hiding one keeps its program running; showing it again doesn't
restart it. To stop a floater, quit the program or use its "Close Floater" action in the palette.

Inside a Git checkout, Lazygit opens directly, including in linked worktrees and subdirectories.
Use Lazygit's own controls to switch worktrees. Outside a checkout, the bundled definition looks
for repositories and opens a picker if it finds more than one.

To copy with Pluck, press `cmd+shift+y` and type the hint over a URL, path, or other highlighted token.
It copies the original text and closes, without needing Enter. Esc cancels. Pluck fills the tab and
uses a frozen snapshot; close and reopen it to refresh. See the [Pluck guide](docs/pluck.md) for
controls and capture limits.

## Add your own command

For a small config, define your floaters directly in `setup()`:

```lua
require("rex-floaters").setup{
  bounds = { 0.1, 0.1, 0.8, 0.8 },
  entries = {
    {
      name = "btop",
      title = "System monitor",
      binding = "cmd+shift+b",
      execute = { "btop" },
    },
    {
      name = "lazygit",
      title = "Lazygit",
      binding = "cmd+shift+g",
      collect = "lazygit/collect.lua",
      execute = "lazygit/execute.lua",
    },
  },
}
```

Replace the earlier `setup()` call with this one. `entries` replaces the bundled list, so include
every floater you want to keep. The Lazygit entry above reuses the bundled scripts.

`execute = { "program", "argument" }` runs a command directly. For shell syntax, use an explicit
shell, such as `{ "sh", "-c", "date; read answer" }`. You can also run a `.lua`, `.sh`, or `.bash` script.

Bounds are `{ x, y, width, height }` as fractions of the Rex window. The example leaves a 10% margin
on each side.

For larger setups, keep definitions and scripts in a separate directory outside the checkout.
See the [configuration and scripting guide](docs/configuration.md) for directory setup, collectors,
pickers, script arguments, and programmatic control.

After changing definitions or bindings, run `rex config reload`. Close and reopen an existing
floater to pick up new settings or scripts; hiding and showing it keeps the old process.

## Troubleshooting

- Can't load `rex-floaters`? Check that the checkout is named `rex-floaters` and sits beside the active
  config file.
- API revision error? Compare `rex version` with `rex server status`. Updating the app doesn't update
  a running server. Restart the server when it's safe; the extension never restarts it for you.
- Program not found? Check that it's installed on the server machine and on your login shell's PATH.
- Tab picker won't switch tabs? Enable Remote Control in Rex Settings under Rex Server.
- New bounds or script changes aren't showing up? Close the floater and open a fresh one.
- Bundled floaters disappeared after setting `directory` or `entries`? Both replace the default list
  rather than adding to it.

To uninstall, close your floaters, remove the setup call and any floater bindings, reload Rex's
config, then delete the checkout. Your scripts and tool configurations are left alone.

## Development

There's no build step. Local checks need LuaJIT, ShellCheck, and Python 3:

```sh
sh scripts/test.sh --unit
sh scripts/check.sh
sh scripts/test.sh
```

Full integration tests also need a compatible Rex installation, fzf, and Television 0.15.9 for the
TV-specific checks. They use disposable servers and repositories, not your running server or working
repositories. To test another Rex executable, set `REX_FLOATERS_REX=/absolute/path/to/rex`.

See [VALIDATION.md](VALIDATION.md) for test coverage and limits, and [CHANGELOG.md](CHANGELOG.md) for
release history.

## License

[MIT](LICENSE). Pluck's Unicode data uses [Unicode License v3](LICENSE.unicode).
See [NOTICE.md](NOTICE.md) for provenance and third-party tools.
