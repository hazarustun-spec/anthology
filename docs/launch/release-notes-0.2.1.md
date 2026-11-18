Bug-fix release.

- **Installer:** the one-line `curl … | sh` command stopped with `APP: unbound variable` on Macs set to a UTF-8 language (most Macs). Fixed.
- **Connections heal themselves:** if the helper Anthology installs for your AI tools gets deleted (for example by a cleaner app), Claude Code and the others failed with "no such file or directory" until you pressed Connect again. Anthology now puts it back the next time it opens.

### Install or update

```sh
curl -fsSL https://raw.githubusercontent.com/hazarustun-spec/anthology/main/install.sh | sh
```

Requires macOS 26 (Tahoe) or newer. Signed with Developer ID and notarized by Apple.
