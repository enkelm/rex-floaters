# License and provenance

Licensed under the [MIT License](LICENSE), copyright 2026 Enkel Murati.

This repository extracts the existing floating Lazygit extension for Rex into an independently
installable package. Its Git/fzf helpers in `lib/` originated in the same Rex Hunk implementation;
they are included here so installing Hunk is not required. No source repository history, private
configuration, terminal captures, or screenshots are included.

Rex, Lazygit, Git, fzf, OpenSSL, and Worktrunk are separate tools and retain their own licenses.
No upstream binaries or Worktrunk extension source are bundled.

The npm package is marked `private` to prevent accidental npm publication, not to restrict MIT permissions.
