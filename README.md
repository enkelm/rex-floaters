# Rex Floaters

**v0.2.0** · [MIT](LICENSE)

Named floating terminals for Rex, configured in Lua. Give each floater a command or script,
optionally collect choices first, and let the configured picker pass the selection to its executor.
The shortcut shows or hides the running floater; exiting its executor closes it.

Lazygit and a Television-based Rex tab picker are bundled definitions, not special cases in the
floater implementation. The tab picker is unbound by default. A collector-free btop definition is
also included. No Node, npm, Hunk, or standalone Lua runtime.

## Requirements

Use a Rex **server and CLI supporting API revision 9**, including `session.set_layer_state`.
This version was tested with Rex `0.0.1793420730-g6d0d9a`. Updating the app alone does not update an
already-running server. Compare `rex version` with `rex server status`; restart your server yourself
when it is safe to do so. The extension never restarts it.

The general runner needs Rex and standard Unix tools (`sh`, `find`, and `pwd`). Additional tools
are only needed by definitions that use them:

- **Lazygit:** `lazygit`, Git, and `realpath`; fzf when choosing between repositories. Worktrunk is optional.
- **btop:** `btop`.
- **Rex tab picker:** Television `tv` 0.15.9. Its preview uses the Rex API and does not require fzf.
  Navigating the originating Rex app to another tab/session requires **Remote Control** in Rex Settings
  under Rex Server; Rex rejects external client actions while that security setting is off.
- **Other collectors:** fzf by default, or the configured picker backend. Zero or one item does not
  require fzf when `skip_single=true`.

Programs must be available on the PATH set by your login shell on the Rex server's machine.
An interactive shell alias is not an executable. macOS is the validated platform; Linux and native
Windows have not been validated.

## Install

Place this checkout beside Rex's active `init.lua`, named **`rex-floaters`**:

```text
~/.config/rex/
├── init.lua
└── rex-floaters/
    └── init.lua
```

Add this to Rex's configuration, keeping your existing configuration:

```lua
require("rex-floaters").setup()
```

Then check and reload:

```sh
rex config check
rex config reload
```

`setup()` discovers the bundled definitions in `rex-floaters/floaters/`:

| Floater | Default shortcut | Behavior |
| --- | --- | --- |
| `lazygit` | `cmd+shift+g` | Open in the invoking terminal's directory; choose a repository when needed. |
| `btop` | None | Run btop directly. Available from the command palette. |
| `rex` | None | Choose a tab across Rex sessions; preview all tiled splits with their terminal colors on the right. |

Importing alone registers nothing. Rex loads modules beside the active config file. If `init.lua`
is a symlink, install beside the link, not its target. Respect `XDG_CONFIG_HOME` or `REX_CONFIG`
when locating that directory. For a checkout elsewhere, prepend `"/path/to/modules/?/init.lua;"`
to `package.path` before requiring it.

The `rex` definition is deliberately unbound. If you want a suggested shortcut, add
`rex.bind("ctrl+shift+r", "floaters_rex_toggle")` after `setup()` once you have checked that the
chord does not conflict with your existing Rex bindings.

### Migrating from rex-lazygit

This is a breaking rename, not an additional extension to load alongside the old one:

1. Close existing Lazygit popups and save any local checkout edits.
2. Rename the installed checkout directory from `rex-lazygit` to `rex-floaters`.
3. Replace `require("rex-lazygit").setup{...}` with the new setup call.
4. Move custom bindings into definitions or named `entries`, as shown below. `bindings.open` is removed.
5. Update manual action references from `lazygit_open` to `floaters_lazygit_toggle`.
6. Check and reload Rex's config.

Existing old-style popups are not adopted: the old reserved `Lazygit` label differs from the new
namespaced labels. Earlier versions are recorded in [CHANGELOG.md](CHANGELOG.md).

## Keep your definitions in their own directory

Point setup at a directory outside the extension checkout so updates do not overwrite your scripts:

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

Each immediate child directory containing `init.lua` is one definition, discovered in sorted order.
The directory name is its stable identifier: lowercase letters, digits, and underscores, starting
with a letter. An explicit `name` in that file must match. Definitions are trusted Lua files returning
tables. These metadata files run during config loading; collector/executor scripts do not.

`directory` defaults to the bundled `floaters/` directory. A custom directory **replaces**, rather
than merges with, the bundled directory. You can copy the btop definition directly. The bundled
Lazygit collector imports this checkout's Git helpers; if copying it elsewhere, update those imports
to absolute paths into your extension checkout as well.

### A command without collection

```lua
-- btop/init.lua
return {
  title = "System monitor",
  binding = "cmd+shift+b",
  execute = { "btop" },
  bounds = { 0.1, 0.1, 0.8, 0.8 },
}
```

No collector, fzf, or argument protocol is needed. A command is an argv array, not a shell string.
For shell syntax use an explicit command such as `{ "sh", "-c", "date; read answer" }`.

### Collection followed by execution

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

Script paths resolve relative to the definition's directory, **not** the invoking terminal's cwd.
The terminal and executor start in that invoking cwd. `directory` itself must be absolute or start
with `~/`. Paths with spaces, quotes, and newlines are passed as arguments, never pasted into a shell.

## Define an array in setup instead

If you prefer one config file, `entries` is a dense array of named definitions. Providing it disables
directory scanning. Relative script paths then resolve against `directory`.

```lua
require("rex-floaters").setup{
  entries = {
    { name = "btop", title = "System monitor", binding = "cmd+shift+b", execute = { "btop" } },
    { name = "lazygit", title = "Lazygit", binding = "cmd+shift+g",
      collect = "lazygit/collect.lua", execute = "lazygit/execute.lua" },
  },
}
```

The inline Lazygit entry uses the bundled scripts through paths relative to the default directory.
For Lazygit without repository discovery, use `execute = { "lazygit" }` instead.

`entries = {}` registers nothing. Unknown fields, sparse arrays, duplicate names/chords, unreadable
script paths, and invalid values are rejected before registration. Inputs are copied. Bounds are
`{x, y, width, height}` fractions, must be four finite numbers, have positive dimensions, and fit
inside the normalized `0..1` window.

### Definition fields

| Field | Meaning |
| --- | --- |
| `name` | Required for inline entries; otherwise taken from the containing directory. |
| `title` | Display text; defaults to the name. Does not determine popup ownership. |
| `binding` | Optional Rex key chord or sequence, e.g. `ctrl+space>g`; `false` leaves it unbound. |
| `execute` | Required: argv array, or path to a `.lua`, `.sh`, or `.bash` script. |
| `collect` | Optional path to a Lua collector. |
| `picker` | Optional `{ backend="fzf", multiple=false, skip_single=true, title=... }`; TV requires `preview="preview.lua"` and supports one selection. |
| `bounds` | Overrides setup's default bounds for this entry. |
| `category`, `description`, `keywords` | Optional command-palette metadata. |

Setup accepts only `directory`, `entries`, and `bounds`. A new setup call starts from defaults rather
than patching the previous configuration. Repeated setup removes only bindings targeting its former
actions. Rex owns shortcut syntax and conflict resolution with bindings outside this extension.
Removed entries cannot run stale executors, but their palette actions may remain until a full config
reload because Rex does not expose action unregistration.

## Collector and executor contracts

A Lua script receives `(ctx, values)` as chunk arguments; a collector only needs `ctx`:

```lua
local ctx, values = ...
```

`ctx` contains `name`, `directory`, `cwd`, and `exec(argv, options)`. The runner's `ctx.exec` gives
interactive programs the popup's terminal, unlike a plain `rex.exec` that captures their streams.
Use options such as `cwd`, `env`, and `timeout`; input/output always attach to the terminal.
For captured output or piped input, use Rex's ordinary `rex.exec` directly.

A collector returns a dense array of `{ value=string, label=string, description=optional_string }`.
Values cannot contain NUL bytes. Labels must be non-empty and have no NUL bytes. Display control
characters are sanitized. Labels are presentation only; values are never reconstructed from them.

- No collector: execute with an empty selection.
- Empty array: print “no items found” and close without executing.
- One item and `skip_single=true`: execute directly without opening a picker.
- Otherwise: open the configured picker (`fzf` by default). `multiple=true` allows several selected values with fzf; TV definitions reject multiple selection.
- Esc/cancellation: close without executing. Invalid collector output is an error, not an empty selection.

The default fzf picker keys are: type to filter; Space/Tab toggle; Enter confirms; Esc cancels;
Ctrl+Space inserts a space; Ctrl+X clears selection. Even single-selection mode supports toggling
one selected item. The fzf picker ignores `FZF_DEFAULT_OPTS` and `FZF_DEFAULT_OPTS_FILE` so custom
bindings cannot corrupt its protocol.

Definitions can set `picker.backend = "tv"` to use Television 0.15.9 instead. TV definitions need a
Lua `picker.preview` script and support one selected item. The bundled Rex tab picker creates one row
per tab, labeled `session / tab` with its pane count and remembered pane. It marks the invoking tab,
excludes this extension's own floater terminals, and focuses the tab's remembered pane after selection.
For another tab or session, it asks the Rex app that owns the invoking pane (not an arbitrary connected
client) to run `session.select` with both the target session and window. Rex requires Remote Control for
that handoff. If it is disabled, selection fails with an actionable settings message instead of silently
changing only server state. A tab or remembered pane that closes during selection is ignored. Escape
cancels without focusing another tab.

The right-side preview composes every pane in the tab's tiled split geometry. Terminal text colors and
styles are preserved from Rex's HTML terminal snapshot; non-terminal blocks receive placeholders.
Each pane is limited to its current screen height, the composite is bounded by the Television preview
area, and terminal captures are never written to disk.

Executors receive selected values in order:

- Command arrays: values are appended as separate argv arguments after configured arguments.
- `.sh` / `.bash`: launched with `/bin/sh` / `/bin/bash`, with values as positional arguments.
- `.lua`: receives the values array as its second chunk argument. Return nothing for success, an
  exit status `0..255`, or the result of `ctx.exec`.

For example, a Lua executor can choose a different working directory:

```lua
local ctx, values = ...
return ctx.exec({ "lazygit" }, { cwd = assert(values[1]) })
```

Do not call `rex.stop()` in Lua collectors/executors: it exits immediately and bypasses runner cleanup.
Return instead. Do not detach background work if it should terminate with the popup. Scripts have the
user's privileges and Rex's full Lua interface; they are not sandboxed.

## Lifecycle and programmatic control

There is one floater per entry per Rex tab (a `window` in the server interface):

1. First toggle creates the popup, captures cwd, and runs collection then execution.
2. Toggling a visible popup minimizes it without stopping the picker/executor.
3. Toggling a minimized popup restores the same process and focuses it. Collection is not rerun.
4. Executor completion, cancellation, or failure closes the terminal, including while minimized.
   Fast failures do not leave a dead shell or wait for acknowledgement.

Each entry registers two named actions, usable from keys, the palette, or CLI:

```sh
rex do floaters_lazygit_toggle -s "$REX_SESSION" -b "$REX_BLOCK"
rex do floaters_lazygit_close  -s "$REX_SESSION" -b "$REX_BLOCK"
```

`close` terminates the owned terminal, not merely its visibility. You can manage shortcuts yourself:

```lua
rex.bind("ctrl+space>g", "floaters_lazygit_toggle")
```

Live namespaced labels (`rex-floaters:<name>`) identify popups after config reloads. These labels are
reserved; don't rename owned terminals or give unrelated floating terminals those labels. Tiled panes
are never matched. Hide/show operates on the whole floating layer; if you split that layer, its
siblings hide/show together. Explicit close removes only the owned block.

The server's focus history restores the latest pane used before the popup. Completion does not
steal focus from another pane or tab. Initial zoom is restored only when focus returns to that same
original pane. A hidden popup finishing does not restore or activate its old window.

Definition/binding changes require `rex config reload`. Existing running popups keep their process
and configuration snapshot. Scripts are read when their stage starts; editing a file does not restart
or rerun a stage already in progress. Close and launch a fresh popup to apply all changes reliably.
Showing an existing popup never reruns collection or execution. New bounds apply on fresh launch.

## Lazygit behavior

Inside a Git checkout, including linked worktrees and nested directories, Lazygit opens immediately.
Use Lazygit's own worktree controls to switch. Outside a checkout, multiple distinct repositories
produce a picker; one repository uses its checkout directly. The picker and Lazygit share one popup.

Discovery includes registered linked worktrees outside the starting directory, stops after three
levels or 1,500 directories, and skips common dependency/build directories. Optional Worktrunk supplies
local-only JSON listings; unsupported output or failures fall back to Git. Collection does not create,
switch, fetch, or modify worktrees. Lazygit's own configuration is unchanged.

## Troubleshooting and development

- **Module not found:** name the installed checkout `rex-floaters` beside the active config.
- **API revision error:** compare CLI and running server versions; update/restart when safe.
- **Program missing:** install it on the server machine and check its login-shell PATH.
- **Different bounds or script code ignored:** close the old popup and launch a fresh one.
- **No picker in a multi-worktree repo:** intentional; Lazygit handles worktrees inside checkouts.
- **Custom directory does not include Lazygit:** custom directories replace bundled discovery.

Launcher overrides: `REX_FLOATERS_REX` chooses the Rex executable, `REX_FLOATERS_BIN_DIR` prepends a PATH
directory, `REX_FLOATERS_FZF` chooses fzf, and `REX_FLOATERS_TV` chooses Television. The old
`REX_HUNK_REX`, `REX_BIN_DIR`, and `REX_HUNK_FZF` are still accepted as fallbacks; Hunk is not required.

There is no build step. Development checks need LuaJIT, ShellCheck, and Python 3:

```sh
sh scripts/test.sh --unit
sh scripts/check.sh
sh scripts/test.sh
# To test with a different Rex executable:
REX_FLOATERS_REX=/absolute/path/to/rex sh scripts/test.sh
```

Full tests create disposable servers, repositories, synthetic executables, and real PTYs. They never
reload/restart your server or mutate your working repositories. Python only transports test PTYs;
assertions are Lua. A deliberately failing Node executable checks runtime independence. Hosted CI
runs registration tests and lint; full integration needs a compatible Rex installation, fzf, and
Television 0.15.9 for its TV-specific PTY checks.
See [VALIDATION.md](VALIDATION.md) for evidence and limits.

Implementation map: `init.lua` registers/toggles; `lib/config.lua` discovers and validates;
`launch.sh`, `cli.lua`, `lib/runner.lua` own execution; `lib/picker.lua` owns fzf and Television;
`dismiss.lua` restores the view; `floaters/` holds bundled definitions.

To uninstall, close the floaters, remove setup and manual bindings from your config, reload Rex,
then remove the checkout. Your scripts, repositories, and upstream tool configurations are unchanged.

## License

[MIT](LICENSE). See [NOTICE.md](NOTICE.md) for provenance and third-party tools.
