# Configuration and scripting

The [README](../README.md) covers installation and running the bundled floaters. This guide covers
custom definitions, scripts, pickers, and lifecycle details.

## Setup options

`setup()` accepts three options:

| Option | Default | What it controls |
| --- | --- | --- |
| `directory` | The checkout's `floaters/` directory | Where to find definitions and resolve inline script paths. Must be absolute or start with `~/`. |
| `entries` | Not set | An array of named definitions. When set, directory scanning is disabled. An empty array registers nothing. |
| `bounds` | `{ 0.05, 0.05, 0.9, 0.9 }` | Default `{ x, y, width, height }` for each floater, as fractions of the window. |

Bounds must contain four finite numbers, have positive dimensions, and fit inside the window.
Individual definitions can override them.

A new `setup()` call starts from defaults, rather than patching the previous configuration. Importing
the module without calling `setup()` registers nothing. Unknown fields, sparse arrays, duplicate
names or shortcuts, unreadable script paths, and invalid values are rejected before registration.
Configuration tables are copied.

Rex loads modules beside the active config file. To keep the checkout elsewhere, prepend its parent
directory's module pattern to `package.path` before requiring it:

```lua
package.path = "/path/to/modules/?/init.lua;" .. package.path
require("rex-floaters").setup()
```

Here the checkout lives at `/path/to/modules/rex-floaters`.

## Keep definitions in a separate directory

Keeping your definitions outside the extension checkout makes it easier to update without touching
your scripts:

```lua
require("rex-floaters").setup{
  directory = os.getenv("HOME") .. "/.config/rex/floaters",
  bounds = { 0.05, 0.05, 0.9, 0.9 },
}
```

```text
~/.config/rex/floaters/
├── btop/
│   └── init.lua
└── projects/
    ├── init.lua
    ├── collect.lua
    └── execute.sh
```

A custom directory replaces the bundled directory; it doesn't merge with it. You can copy the
bundled btop definition directly. The bundled Lazygit collector imports Git helpers from the
checkout, so copying it elsewhere also requires changing those imports to absolute paths into
the extension checkout.

Each immediate child directory containing `init.lua` is a definition. Definitions are loaded in
sorted order. The directory name is the floater's identifier: lowercase letters, digits, and
underscores, starting with a letter. An explicit `name` must match the directory name.

Each `init.lua` returns a table. These files run when Rex loads its config; collectors and executors
run only when the floater opens. Treat all definition and script files as trusted code.

### Run a command directly

```lua
-- btop/init.lua
return {
  title = "System monitor",
  binding = "cmd+shift+b",
  execute = { "btop" },
  bounds = { 0.1, 0.1, 0.8, 0.8 },
}
```

No collector or picker is needed. Commands are argument arrays, not shell strings. To use shell
syntax, run a shell explicitly, for example `{ "sh", "-c", "date; read answer" }`.

### Choose something before running a script

A collector supplies choices to a picker. The executor receives the selected values.

```lua
-- projects/init.lua
return {
  title = "Choose a project",
  binding = "cmd+shift+p",
  collect = "collect.lua",
  picker = {
    title = "Projects",
    multiple = false,
    skip_single = true,
  },
  execute = "execute.sh",
}
```

```lua
-- projects/collect.lua
local ctx = ...
return {
  { value = ctx.cwd, label = "Current directory", description = ctx.cwd },
  { value = os.getenv("HOME") .. "/Projects", label = "All projects" },
}
```

```sh
#!/bin/sh
# projects/execute.sh: each selected value is a separate argument.
set -eu
cd -- "$1"
exec "${SHELL:-/bin/sh}"
```

Script paths resolve relative to the definition's directory, not the invoking terminal's working
directory. The floater and executor start in the invoking terminal's working directory. Paths with
spaces, quotes, and newlines are passed as arguments, never pasted into shell source.

## Define entries inline

If you prefer one config file, use `entries`. Each entry needs a `name`, and relative script paths
resolve against `directory` (the bundled `floaters/` directory by default):

```lua
require("rex-floaters").setup{
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

For Lazygit without repository discovery, use `execute = { "lazygit" }` and omit `collect`.

## Definition fields

| Field | Meaning |
| --- | --- |
| `name` | Required for inline entries; otherwise taken from the containing directory. |
| `title` | Display text; defaults to the name. |
| `binding` | Optional Rex shortcut or sequence, such as `ctrl+space>g`. Omit it or set it to `false` to leave the floater unbound. |
| `execute` | Required. An argument array, or a path to a `.lua`, `.sh`, or `.bash` script. |
| `collect` | Optional path to a Lua collector. |
| `picker` | Picker options, described below. |
| `bounds` | Overrides setup's default bounds for this entry. |
| `zoom` | Set to `true` to fill the tab on launch and when shown again. Defaults to `false`; used by Pluck. |
| `category`, `description`, `keywords` | Optional command-palette metadata. |

Rex handles shortcut syntax and conflicts with bindings outside this extension. Calling `setup()`
again removes only bindings targeting the extension's former actions. Removed entries can no longer
run their executors, but their palette actions may remain until a full config reload because Rex
doesn't expose action unregistration.

## Collectors and pickers

A collector is a Lua script that receives `ctx` as a chunk argument:

```lua
local ctx = ...
```

It returns a dense array of `{ value = string, label = string, description = optional_string }`.
Values cannot contain NUL bytes. Labels must be non-empty and have no NUL bytes; display control
characters are sanitized. Labels are only for display, and selected values are never reconstructed
from them.

- Without a collector, the executor runs with an empty selection.
- An empty array prints "no items found" and closes the floater without executing.
- One item runs directly when `skip_single = true` (the default).
- Otherwise, the configured picker opens.
- Cancelling closes the floater without executing. Invalid collector output is an error, not an
  empty selection.

### fzf

fzf is the default picker. Its options are:

```lua
picker = {
  backend = "fzf",
  multiple = false,
  skip_single = true,
  title = "Projects",
}
```

This is a field in a definition, not a separate setup call. Set `multiple = true` to allow several
selected values. fzf is only needed when the picker actually opens.

Type to filter, use Space or Tab to toggle a selection, Enter to confirm, and Esc to cancel.
Ctrl+Space inserts a space; Ctrl+X clears the selection. Single-selection mode also lets you toggle
one item. The picker ignores `FZF_DEFAULT_OPTS` and `FZF_DEFAULT_OPTS_FILE` so custom bindings can't
break selection handling.

### Television

Set `picker.backend = "tv"` to use Television 0.15.9. TV definitions require a Lua `picker.preview`
script and support one selection only. Set `skip_single = false` if you want the picker to open even
for a single item.

The bundled Rex tab picker uses Television. Each row is a tab, labeled `session / tab`, with its pane
count and remembered pane. It marks the invoking tab and excludes this extension's own floaters.
After selection, it focuses the tab's remembered pane. Tabs or remembered panes that close during
selection are ignored; Esc leaves the current tab alone.

Switching to another tab or session asks the Rex app that owns the invoking pane to run
`session.select` with the target session and window. This requires Remote Control in Rex Settings
under Rex Server. If it's disabled, the picker reports how to enable it rather than changing only
server state.

The right-side preview shows all tiled splits in their tab layout. It preserves terminal text
colors and styles from Rex's HTML snapshots, with placeholders for non-terminal blocks. Each pane
is limited to its current screen height, and the combined preview fits Television's preview area.
Terminal captures are never written to disk.

## Executors and script context

Lua scripts receive `(ctx, values)` as chunk arguments. Collectors only need `ctx`; executors use
the selected values:

```lua
local ctx, values = ...
return ctx.exec({ "lazygit" }, { cwd = assert(values[1]) })
```

`ctx` provides `name`, `directory`, `cwd`, `origin`, and `exec(argv, options)`. `origin` records the
invoking pane's `session_id`, `window_id`, `block_id`, and `client_id`, plus the original
`zoomed_block_id` (an empty string if unzoomed) and the Rex server's instance ID as `server_id`.

Use `ctx.exec` for interactive
programs: it connects their input and output to the floater's terminal. Options include `cwd`,
`env`, and `timeout`. For captured output or piped input, use Rex's ordinary `rex.exec` instead.

Executors receive selected values in order:

- Command arrays append values as separate arguments after the configured arguments.
- `.sh` and `.bash` scripts run with `/bin/sh` and `/bin/bash`, with values as positional arguments.
- `.lua` scripts receive the values array as their second chunk argument. Return nothing for
  success, an exit status from `0` to `255`, or the result of `ctx.exec`.

Return from Lua scripts instead of calling `rex.stop()`, which exits immediately and bypasses
cleanup. Don't detach background work if it should stop when the floater closes. Scripts have your
privileges and Rex's full Lua interface; they aren't sandboxed.

## Lifecycle and actions

Each entry has one floater per Rex tab (called a `window` in the server API):

1. The first toggle creates the floater, captures the working directory, and runs collection
   followed by execution.
2. Toggling a visible floater hides it without stopping the picker or program. If it's the only
   visible pane left in its tab, Rex can't hide it, so the toggle closes it instead.
3. Toggling a hidden floater restores and focuses the same process. Collection doesn't run again.
4. Completion, cancellation, or failure closes the terminal, even while hidden. Fast failures don't
   leave a dead shell or wait for acknowledgement.

Each entry registers `floaters_<name>_toggle` and `floaters_<name>_close`. Use them from bindings,
the command palette, or the CLI:

```sh
rex do floaters_lazygit_toggle -s "$REX_SESSION" -b "$REX_BLOCK"
rex do floaters_lazygit_close  -s "$REX_SESSION" -b "$REX_BLOCK"
```

```lua
rex.bind("ctrl+space>g", "floaters_lazygit_toggle")
```

`close` terminates the terminal instead of just hiding it.

### Reloads, focus, and ownership

Definition and binding changes require `rex config reload`. Running floaters keep their process
and configuration snapshot. Scripts are read when their stage starts, so editing a file won't
restart a stage already in progress. Close and launch a fresh floater to apply all changes,
including new bounds.

The server restores focus to the latest pane used before the floater. Completion doesn't steal
focus from another pane or tab. Initial zoom is restored only when focus returns to that same
original pane. A hidden floater finishing won't activate its old tab.

Labels such as `rex-floaters:lazygit` identify owned floaters after config reloads. These labels are
reserved: don't rename owned terminals or give unrelated floating terminals those labels. Tiled
panes are never matched. Hide/show affects the whole floating layer, so if you split that layer,
its siblings hide and show together. Explicit close removes only the owned block.

## Lazygit repository discovery

Inside a Git checkout, including linked worktrees and nested directories, Lazygit opens immediately.
Outside a checkout, one discovered repository opens directly; multiple repositories open a picker.
The picker and Lazygit share one floater.

Discovery includes registered linked worktrees outside the starting directory. It stops after three
levels or 1,500 directories and skips common dependency and build directories. If Worktrunk is
installed, its local-only JSON listings are used where supported; failures or unsupported output
fall back to Git.

Collection doesn't create, switch, fetch, or modify worktrees. Lazygit's own configuration is
unchanged.

## Launcher overrides

| Environment variable | Purpose |
| --- | --- |
| `REX_FLOATERS_REX` | Choose the Rex executable. |
| `REX_FLOATERS_BIN_DIR` | Prepend a directory to PATH. |
| `REX_FLOATERS_FZF` | Choose the fzf executable. |
| `REX_FLOATERS_TV` | Choose the Television executable. |

`REX_HUNK_REX`, `REX_BIN_DIR`, and `REX_HUNK_FZF` are also accepted as fallbacks. Hunk isn't required.
