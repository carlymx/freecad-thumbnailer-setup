# freecad-thumbnailer-setup

> **English** · [Español](README_ES.md)

![File manager showing FreeCAD (.FCStd) thumbnails](media/Screenshot_01.jpg)

*FreeCAD `.FCStd` files showing their embedded thumbnail in the file manager.*

Single-file bash installer that adds **thumbnails for FreeCAD `.FCStd` files** to your file manager (Nemo, Nautilus, Dolphin, Thunar, Caja, PCManFM) and turns on FreeCAD's *“Save thumbnail …”* option so the preview travels inside every model file.

- 🖼️ Preview the model directly in the file manager instead of a generic icon
- 📦 One self-contained script: `bash` + `python3`, no extra dependencies to install first
- 🧰 Interactive menu, status panel, dry-run, diagnostics, demo file
- ↩️ Every settings change is recorded so `--uninstall` can restore the previous state
- 🐧 Debian/Ubuntu (Mint…), Fedora/Bazzite (rpm-ostree), Arch and openSUSE

## Prologue

For a long time I wanted something very simple, and something FreeCAD itself never gave me: to see what a `.FCStd` file actually looks like **right there in the file manager**, without having to open it in FreeCAD first. I knew there were ways to do it, but every method I found was a bit tedious — copy a script here, edit a configuration file there, remember to repeat it on each machine. I did it a couple of times, ended up giving up, and went back to guessing which cube was which by the file name.

One day I decided to change the approach: instead of following a long recipe by hand, I asked an agentic AI to walk through it with me. I used [OpenCode](https://opencode.ai) through its terminal version, described what I wanted — *"I want to see my FreeCAD thumbnails in my file manager, and I want to be able to undo it later"* — and let it guide me through every installation step: detecting the system and the file manager, installing the thumbnailer, turning on FreeCAD's own option, verifying that it really worked.

What began as a single request kept growing as we tested it, found rough edges and fixed them, one conversation after another, until that request took shape as the script you now find in this repository.

I hope it saves you the trouble it saved me.

---

## Table of contents

- [Prologue](#prologue)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Options](#options)
- [What it changes](#what-it-changes)
- [How it works](#how-it-works)
- [Supported file managers](#supported-file-managers)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
- [Repository layout](#repository-layout)
- [Development](#development)
- [Credits & license](#credits--license)

## Quick start

```bash
git clone https://github.com/carlymx/freecad-thumbnailer-setup.git
cd freecad-thumbnailer-setup
chmod +x freecad-thumbnailer-setup.sh
./freecad-thumbnailer-setup.sh
```

Running it with no arguments opens the status panel and a three-option menu:

```
== freecad-thumbnailer-setup 2.1 — panel de inicio
  SO               : Linux Mint 22.3 — compatible (debian, gestor apt)
  FreeCAD          : flatpak org.freecad.FreeCAD 1.1.3
  Explorador(es)   : nemo (xdg: nemo.desktop, sesion: X-Cinnamon)
  Modulo (MOD)     : instalado (user, 4/4)
  Previsualizacion : nemo show-image-thumbnails='local-only'; FreeCAD SaveThumbnail=activo
  Modo instalacion : user

  1 Instalar      (ficheros, ajustes de FreeCAD/explorador y verificacion)
  2 Desinstalar   (quita el modulo y restaura los ajustes previos)
  q Salir

  Seleccion:
```

## Usage

| Command | What it does |
| --- | --- |
| `./freecad-thumbnailer-setup.sh` | Status panel + interactive menu (needs a terminal) |
| `./freecad-thumbnailer-setup.sh --user` | Install for your user only, no sudo |
| `./freecad-thumbnailer-setup.sh --system` | Install system-wide (asks for your sudo password) |
| `./freecad-thumbnailer-setup.sh --dry-run` | Print every action without changing anything |
| `./freecad-thumbnailer-setup.sh --status` | Full diagnostics, read-only |
| `./freecad-thumbnailer-setup.sh --test` | Only verify the thumbnail generator |
| `./freecad-thumbnailer-setup.sh --demo` | Create a test `.FCStd` on the desktop |
| `./freecad-thumbnailer-setup.sh --uninstall` | Remove everything and restore previous settings |
| `./freecad-thumbnailer-setup.sh --help` | Option summary |

Without a terminal (pipe, cron) and without arguments it installs directly, so it never hangs waiting for input.

## Options

| Option | Effect |
| --- | --- |
| `--yes`, `-y` | Never prompt (accept optional packages) |
| `--force` | Continue even if the OS or file manager is unsupported |
| `--user` / `--system` / `--auto` | Installation mode (default: auto) |
| `--dry-run` | Simulate: print instead of executing |
| `--full-cache` | Also wipe already generated thumbnails |
| `--keep-cache` | Leave the thumbnail cache alone |
| `--no-deps` | Do not offer optional packages (`tumbler`, `kde-fcstd-thumbnailer`) |
| `--no-config` | Do not touch FreeCAD / file-manager settings |
| `--no-test` | Skip the final verification |
| `--no-restart` | Do not restart the file manager |

Options can be combined, e.g. `./freecad-thumbnailer-setup.sh --user --no-restart`.

## What it changes

**Files** (user mode; with `--system` they go to `/usr`):

```
~/.local/bin/freecad-thumbnailer.py                       thumbnail generator
~/.local/share/thumbnailers/FreeCAD.thumbnailer           freedesktop thumbnailer entry
~/.local/share/mime/packages/org.freecadweb.FreeCAD.xml   MIME type for .FCStd
~/.local/share/icons/hicolor/48x48/apps/freecad.png       fallback icon
```

**Settings** (recorded first, so `--uninstall` can undo them):

- `show-image-thumbnails` / `thumbnail-limit` in Nemo, Nautilus and Caja
- `/misc-thumbnail-mode` in Thunar (requires `tumbler`)
- `[PreviewSettings] Plugins=` in `dolphinrc` (or `kde-fcstd-thumbnailer`)
- thumbnailer schemas (`disable` / `disable-all`) for cinnamon/gnome/mate
- `SaveThumbnail=1` in FreeCAD `user.cfg` (a `.bak-thumbnailer` copy is kept)

**State and log**: `~/.local/state/freecad-thumbnailer-setup/{state,setup.log}`.

Nothing is written outside those paths, and every mutation is skipped in `--dry-run`.

## How it works

1. **Generator** – `freecad-thumbnailer.py` reads the embedded `thumbnails/Thumbnail.png` from the `.FCStd` (it is a zip). If the file has none, it falls back to the FreeCAD icon, or asks `FreeCADCmd` (PATH, flatpak or snap) to render one.
2. **Registration** – writes the `application/x-extension-fcstd` MIME type and publishes `FreeCAD.thumbnailer`, which the desktop picks up from `~/.local/share/thumbnailers` (that directory is scanned first by cinnamon-desktop, tumbler, and friends).
3. **Enable** – turns previewing on in the detected file manager and sets `SaveThumbnail` in FreeCAD, so future saves embed the preview.
4. **Clean & verify** – clears `~/.cache/thumbnails/fail`, restarts the file manager and proves it works by generating a sample thumbnail and querying the desktop thumbnail factory.

## Supported file managers

| File manager | Desktop | Notes |
| --- | --- | --- |
| Nemo | Cinnamon | natively, via `cinnamon-desktop` |
| Nautilus | GNOME | natively |
| Caja | MATE | natively |
| Thunar | XFCE | needs the `tumbler` package (offered during install) |
| Dolphin | KDE | Plasma ≥ 6.6, or `kde-fcstd-thumbnailer` (offered) |
| PCManFM / PCManFM-Qt | LXDE / LXQt | via standard freedesktop thumbnailers |

Supported distributions: Debian/Ubuntu (Mint, LMDE, Ubuntu, Pop!\_OS, elementary, Zorin), Fedora / Bazzite / Silverblue (immutable, uses `rpm-ostree`), Arch / Manjaro, openSUSE.

## Uninstall

```bash
./freecad-thumbnailer-setup.sh --uninstall
```

Removes the installed files, restores every recorded setting and FreeCAD config from the saved state, clears thumbnail failures and restarts the file manager. Combine with `--dry-run` to preview it.

## Troubleshooting

- **Start with** `./freecad-thumbnailer-setup.sh --status` — it prints what was detected and whether the module is installed.
- **No thumbnails at all**: *View > Icon view* and *Preferences > Preview = Local files only* (Nemo/Nautilus); Thunar: *Preferences > Show thumbnails*; Dolphin: *Configure Dolphin > General > Previews*.
- **Thumbnails stopped appearing**: `rm -rf ~/.cache/thumbnails/fail` and restart the file manager (`--full-cache` wipes everything).
- **FreeCAD does not embed a preview**: *Edit > Preferences > General > Document > “Save thumbnail …”*.
- **File copied from another machine**: re-save it in FreeCAD with `SaveThumbnail` enabled.
- **Look at the log**: `~/.local/state/freecad-thumbnailer-setup/setup.log`.

## Repository layout

```
freecad-thumbnailer-setup/
├── freecad-thumbnailer-setup.sh   # the whole tool (bash, self-contained)
├── README.md                      # this file (English)
├── README_ES.md                   # Spanish version
├── PLAN.md                        # roadmap, status and notes for maintainers/agents
├── LICENSE                        # MIT
├── .gitignore
└── media/
    └── Screenshot_01.jpg          # cover screenshot
```

## Development

Checks used before every change is considered done:

```bash
bash -n freecad-thumbnailer-setup.sh          # syntax
shellcheck -S style freecad-thumbnailer-setup.sh   # static analysis (0 findings expected)
./freecad-thumbnailer-setup.sh --status       # read-only diagnostics
./freecad-thumbnailer-setup.sh --dry-run      # prints every action, changes nothing
```

Conventions: `set -Eeuo pipefail`, no bare `cmd && cmd` statements (they abort under `errexit`), every mutating command goes through `run()` or an explicit `--dry-run` guard, user-facing messages are plain ASCII Spanish, and the `# >>> DOCUMENTACION` … `# <<< DOCUMENTACION` markers in the script header keep the full documentation out of `--help`.

## Credits & license

- Thumbnail format and the original generator idea: [andesfreedesign/FreeCAD-thumbnailer](https://github.com/andesfreedesign/FreeCAD-thumbnailer) (MIT).
- This setup script and documentation: [carlymx](https://github.com/carlymx), released under the [MIT License](LICENSE).
