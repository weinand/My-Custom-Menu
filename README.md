# My Custom Menu

A lightweight macOS menu bar utility inspired by CustomMenu 3.

This project was motivated by the lack of Apple Silicon support for the utility program "CustomMenu 3". It was created as an experiment in vibe coding, and according to the project intent, not a single line of text was touched by the author after generation. The initial prompt was: "create a macOS menubar application similar to \"CustomMenu 3\"."

## What it does

- Adds a menu bar item with a configurable title.
- Lets you define custom entries:
  - Open files, folders, and apps
  - Open website URLs
- Provides an editor window to change menu entries and save them.
- Stores configuration in:

`~/Library/Application Support/My Custom Menu/menu.json`

Before each save, the previous config is backed up to:

`~/Library/Application Support/My Custom Menu/menu.backup.json`

## Build

```bash
swift build
```

To build a launchable macOS app bundle (`My Custom Menu.app`), use:

```bash
./build.sh
```

This creates `My Custom Menu.app` in `dist/`.

## Run

```bash
swift run
```

When running, click the `MCM` menu bar item and choose `Edit Menu...`.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
