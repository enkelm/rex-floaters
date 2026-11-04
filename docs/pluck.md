# Copy with Pluck

Pluck copies URLs, paths, filenames, and other tokens from Rex panes without using the mouse.
It's a bundled floater, so the usual `require("rex-floaters").setup()` installs it. No separate
extension or picker program is needed.

## Use it

1. Focus a terminal in the tab you want to copy from.
2. Press `cmd+shift+y`, or choose Pluck's toggle action in the command palette.
3. Find your token. Yellow text is copyable; black letters on cyan are its hint.
4. Type the full hint. Pluck copies the original text and closes. No Enter is needed.

| Key | Action |
| --- | --- |
| Hint letters | Select a token once its full hint is entered. |
| Esc or Ctrl+C | Cancel without changing the clipboard. |
| Backspace or Ctrl+U | Clear a partial hint. |
| Floater shortcut | Hide or show the same frozen picker. Close and reopen to refresh it. |

Hints replace the beginning of the displayed token, not the copied text. Repeated values share a
hint across all panes. More than 26 unique values use two-letter hints; more than 676 use three.
Pasted text never selects a hint. A clipped or covered hint can't be selected.

Pluck recognizes URLs (including SSH/Git URLs), paths, filenames, Git status and diff paths,
upstream branch names, Kubernetes resources, UUIDs, SHAs, hex values, IPv4 addresses, and long
numbers. Sentence punctuation is excluded, and Git status paths can contain spaces. Pluck only
copies text; it doesn't open links or execute tokens.

Copying uses the connected Rex client's OSC 52 clipboard support, not `pbcopy` on the server.
`cat` and `stty` must be available on the server machine.

## Configuration

Pluck uses the same definition format as other floaters. For example, to keep only Pluck and change
its shortcut:

```lua
require("rex-floaters").setup{
  entries = {
    {
      name = "pluck",
      title = "Pluck",
      binding = "ctrl+shift+y",
      zoom = true,
      execute = "pluck/execute.lua",
    },
  },
}
```

`entries` replaces the bundled list. Include your other definitions if you want to keep them.
`zoom = true` makes the picker fill the tab. To manage the shortcut yourself, omit `binding` and use
`rex.bind("ctrl+shift+y", "floaters_pluck_toggle")` after setup. The close action is
`floaters_pluck_close`.

## What gets captured

Pluck freezes the latest screens of visible terminal panes in the current tab, including visible
floaters. Other tabs, detached panes, minimized floaters, and Pluck itself are excluded. If a source
pane was already zoomed, only that pane is captured. Unzoom before opening Pluck to copy across
neighboring panes.

Floating panes cover content beneath them. Fully covered panes aren't captured; non-terminal
panes remain blank, opaque areas. Split proportions and floating positions are approximated on the
picker's character grid. Text keeps its hard breaks and wraps, but uses Pluck's colors and
separators rather than the original syntax colors or images.

Resizing clips the frozen text instead of reflowing it and clears partial input. Arrow and page
keys don't scroll the snapshot. Rex doesn't expose the client's scroll position, so scrolling up
in a source pane doesn't change the capture. Tokens cut off above the latest screen aren't offered
as complete copy targets. Unicode widths are approximate and may differ with unusual fonts.

## Safety and limits

Source programs keep running. Pluck doesn't move, detach, close, or send input to them. On exit,
Floaters restores focus using Rex's focus history, without overriding a deliberate switch to
another pane or tab. An original zoom is restored when focus returns to that same pane.

Captures stay in memory, never in temporary files or process arguments. Terminal controls are
stripped, not replayed. Pinned captures are read from the tail, with limits of 4 MiB per pane,
64 panes, and one million captured screen cells per tab. Copied tokens are limited to 64 KiB.
Unsupported or expired captures fail rather than silently using another pane or tab.

The label `rex-floaters:pluck` is reserved for the bundled picker, just like the labels of other
owned floaters. Don't assign it to unrelated terminals.

## Code layout

`floaters/pluck/init.lua` is the floater definition, and `execute.lua` is its small entry point.
The implementation lives in two directories:

- `collect/` verifies the source tab, captures visible panes, and builds the snapshot and copy targets.
  It also holds the text and Unicode helpers used to interpret that snapshot.
- `executor/` handles the hint UI, terminal input, clipboard output, and error reporting.

The collection module passes its snapshot and tokens directly to the executor. It doesn't use the
generic list-and-picker collector protocol, since Pluck draws hints over the captured panes.

## Check cold-start performance

```sh
sh scripts/test.sh --bench-pluck
```

This uses the integration-test tools and disposable servers. It times the shipping launcher through
the first complete frame at 120×40 and 240×80, including mixed Unicode and 1,000 rows of colored
scrollback. Each of the three samples per case starts a fresh Rex/Lua process, with no preloaded
Pluck modules or retained picker.
The benchmark cancels without writing a clipboard.

The median must be below 750 ms. On a slower test machine, set `REX_FLOATERS_COLD_BUDGET_MS` to choose
another budget. Timing checks are opt-in, not part of the ordinary unit or integration suite.
