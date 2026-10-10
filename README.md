# FileTree

A lightweight, purely native macOS GUI file tree explorer built with Swift and SwiftUI.

## How to Build

Run the build script to compile the GUI app and the `ft` CLI into `build/`:

```bash
./build.sh
```

This compiles:
- `build/FileTree.app` (macOS GUI application bundle, containing `Contents/MacOS/FileTree` and `Contents/MacOS/ft`)
- `build/FileTree` (Standalone GUI binary)
- `build/ft` (Standalone CLI launcher binary)

## Installing to `/Applications`

To install the app so it appears in Spotlight (`Cmd + Space`), Launchpad, and the Dock:

```bash
cp -R build/FileTree.app /Applications/
```

## Command Line Usage (`ft`)

Once installed in `/Applications/FileTree.app`, the `ft` binary lives inside the app bundle at:
```text
/Applications/FileTree.app/Contents/MacOS/ft
```

You can make `ft` available globally across your terminal in either of two ways:

### Option A: Create a symlink (Recommended)

```bash
sudo ln -sf /Applications/FileTree.app/Contents/MacOS/ft /usr/local/bin/ft
```

Or to `~/.local/bin/ft` if you prefer a user-level directory without `sudo`.

### Option B: Add a shell alias

Add this to your `~/.zshrc` (or `~/.bashrc`):

```bash
alias ft="/Applications/FileTree.app/Contents/MacOS/ft"
```

---

### Usage

```bash
# Open FileTree with current directory
ft .

# Or open any specific path
ft ~/Documents
```

If running without installing to `/Applications`, you can also use `./build/ft .` directly.

## Uninstalling

```bash
rm -rf /Applications/FileTree.app
```

And remove any symlinks/aliases you created for `ft`.
