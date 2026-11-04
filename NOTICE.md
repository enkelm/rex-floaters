# License and provenance

Licensed under the [MIT License](LICENSE), copyright 2026 Enkel Murati.

Rex Floaters generalizes the independently extracted floating Lazygit extension for Rex into named,
scriptable floating terminals. Its Git/fzf helpers in `lib/` originated in the same Rex Hunk
implementation; they are included here so installing Hunk is not required. No source repository history,
private configuration, terminal captures, or screenshots are included.

Rex, Lazygit, btop, Git, fzf, Television, OpenSSL, and Worktrunk are separate tools and retain their own licenses.
No upstream binaries or Worktrunk extension source are bundled.

## Pluck

The bundled implementation in `floaters/pluck/` comes from the MIT-licensed
[rex-pluck](https://github.com/enkelm/rex-pluck) extension by Enkel Murati. Its token, snapshot,
rendering, and Unicode code is included here; Floaters handles registration and terminal lifecycle.

The hint-based interaction and yellow/cyan palette were inspired by
[Herdr Pluck](https://github.com/rmarganti/herdr-pluck) by rmarganti. Its source was inspected during
development. This implementation uses embedded Lua rather than the upstream Rust plugin; that
difference alone doesn't establish that all licensing obligations have been resolved.

The upstream `Cargo.toml` at commit `1a6302384098f21835e2964637d39dddc989bc1d` declares `license = "MIT"`:

https://github.com/rmarganti/herdr-pluck/blob/1a6302384098f21835e2964637d39dddc989bc1d/Cargo.toml

The rex-pluck extraction recorded that no top-level LICENSE file was present in the inspected
upstream checkout and the raw LICENSE URL returned 404. This declaration is provenance, not a
substitute for checking attribution and redistribution obligations. No upstream binary, Rust source,
screenshots, or demos are bundled. Upstream authors retain their rights and notice requirements.

## Unicode data

`floaters/pluck/collect/unicode.lua` and `tests/data/GraphemeBreakTest.txt` derive from the Unicode 17.0.0 UCD:
https://www.unicode.org/Public/17.0.0/ucd/

The property sources are UnicodeData.txt, DerivedCoreProperties.txt,
auxiliary/GraphemeBreakProperty.txt, and emoji/emoji-data.txt. Grapheme vectors come from
auxiliary/GraphemeBreakTest.txt. Their Unicode License v3 copyright and permission notice is retained
in [LICENSE.unicode](LICENSE.unicode), separate from the code's MIT license.

`scripts/update-unicode.py` regenerates the vendored data. It isn't called during installation,
normal tests, or runtime.

The npm package is marked `private` to prevent accidental npm publication, not to restrict MIT permissions.
