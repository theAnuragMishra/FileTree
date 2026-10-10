# FileTree

A lightweight, purely native macOS GUI file tree explorer built with Swift and SwiftUI.

## How to Build

Run the build script to compile the binary and generate the macOS app bundle into `build/`:

```bash
./build.sh
```

This compiles the native Swift binary to `build/FileTree` and packages the bundle into `build/FileTree.app`.

## How to Run

You can run the application directly from the terminal:

```bash
./build/FileTree
```

Or open the native macOS app bundle:

```bash
open build/FileTree.app
```

## Installing to `/Applications`

To install the app so it appears in Spotlight (`Cmd + Space`), Launchpad, and the Dock:

```bash
cp -R build/FileTree.app /Applications/
```

To remove or uninstall later:
```bash
rm -rf /Applications/FileTree.app
```
