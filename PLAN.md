# PLAN — freecad-thumbnailer-setup

> Maintainer / agent-facing document: goal, current state, invariants, workflows and
> the definition of done. End-user documentation lives in [README.md](README.md) (EN)
> and [README_ES.md](README_ES.md) (ES).

## 1. Goal

Make `.FCStd` (FreeCAD) files show their own preview thumbnail in Linux file managers,
without requiring the user to understand MIME types, thumbnailer specs or desktop
settings — and make the whole thing trivially reversible.

Success = a user with Nemo/Nautilus/Dolphin/Thunar/Caja/PCManFM sees the model preview
after one command, and `--uninstall` leaves the system exactly as it was.

## 2. Current state

| Item | Value |
| --- | --- |
| Version | 2.1 (`SCRIPT_VERSION` in the script) |
| Author / copyright | carlymx |
| License | MIT (`LICENSE`) |
| Main artifact | `freecad-thumbnailer-setup.sh` — single self-contained bash file (~1 850 lines) |
| Language of user-facing output | Spanish, plain ASCII (comments/markers excepted) |
| Tested on | Linux Mint 22.3, Nemo 6.6.3, bash 5.2.21, python3 3.12.3, FreeCAD 1.1.3 (flatpak) |
| Static analysis | shellcheck `--severity style` → **0 findings** |
| Syntax | `bash -n` → clean |
| Last full review | 4 passes (static, logic/`set -e`, functional matrix, UX/hardening) → approved |

### Feature checklist (done)

- [x] Detection of OS (Debian/Ubuntu, Fedora/ostree, Arch, openSUSE) with clean exit `2` when unsupported
- [x] Detection of file manager (7 managers) with clean exit `3` when none, `--force` to override
- [x] Install / uninstall / dry-run / status / test / demo modes
- [x] Interactive panel + menu when run with no arguments on a TTY (`1` install, `2` uninstall, `q` quit)
- [x] Optional packages (`tumbler`, `kde-fcstd-thumbnailer`) only after explicit confirmation
- [x] Immutable/Bazzite path via `rpm-ostree` (never `dnf`), reboot notice
- [x] State file + rollback of every settings change; FreeCAD `user.cfg` backups
- [x] Verification (generator + MIME + desktop thumbnail factory)
- [x] Embedded full documentation in the script header (kept out of `--help`)

## 3. Architecture map

Entry point: `main()` — parses args, optional menu, then runs the phases in order.

| Phase | Functions | Notes |
| --- | --- | --- |
| Args | `parse_args`, `usage`, `need_cmd`, `confirm`, `run` | `run()` is the only generic mutation wrapper |
| 1. OS | `check_os` | `report=1` is silent/non-fatal (used by panel and `--status`) |
| 2. File manager | `check_filemanager`, `schema_exists`, `has_key` | fills `FM_*`, `FM_LIST`, `FM_OK` |
| 3. Optional deps | `pkg_installed`, `install_pkg`, `optional_deps` | `PKG_MGR` selected in `check_os` |
| 4. Fetch | `fetch` (curl/wget), `PY_SRC`, `MIME_XML_SRC` | upstream is only used for the fallback icon |
| 5. Mode/paths | `choose_mode` (`quiet` arg suppresses output) | sets `BIN_PATH`, `THUMB_ENTRY`, `ICON_PATH`, `MIME_XML`, `CACHE_HOME` |
| 6. Install | `install_files`, `write_thumbnailer_entry` | `Exec=` is quoted on purpose |
| 7. FreeCAD | `config_freecad` (embedded python) | refuses to write while FreeCAD is running |
| 8. Enable | `enable_thumbnails`, `enable_show_thumbs`, `set_show_thumbnails`, `enable_external_thumbnailers`, `enable_thunar`, `enable_dolphin`, `find_schema_by_keyword` | each change goes through `state_record` first |
| 9. Cache/restart | `clear_cache`, `restart_filemanagers` | both honour `--dry-run` |
| 10. Verify | `verify`, `create_test_fcstd`, `factory_generate` | needs `python3` (+ `pygobject` for the factory part) |
| Panel/menu | `detect_freecad`, `module_state`, `preview_state`, `show_panel`, `menu` | sets `MENU_ACTION` |
| Uninstall | `do_uninstall`, `restore_state`, `restore_freecad_cfg`, `remove_installed_files` | fully `--dry-run` aware |
| Diagnostics | `cmd_status`, `summary`, `on_error` (ERR trap) | log: `~/.local/state/freecad-thumbnailer-setup/setup.log` |

## 4. Invariants — do not break these

1. `set -Eeuo pipefail` is active. **Never** write a bare `cmd && cmd` statement or an
   unguarded command substitution whose status can be non-zero; the ERR trap would fire
   (noise) or the script would abort. Wrap in `if`, or append `|| true`.
2. **Every** mutating command must be behind `run()` or an explicit `[ "$DRY_RUN" = "1" ]`
   branch. `--dry-run` must not create, modify or delete anything (this was a real bug in
   the uninstall path — regression-tested).
3. Settings changes go through `state_record` *before* they are applied, so `--uninstall`
   can roll back. Do not write to a gsettings/xfconf key without recording it first.
4. Never hard-code `$HOME/...` for user data directories: use `XDG_DATA_HOME`,
   `XDG_CACHE_HOME`, `XDG_STATE_HOME` with the correct fallbacks.
5. Keep the `# >>> DOCUMENTACION … # <<< DOCUMENTACION` markers: `usage()` (awk) relies on
   them to exclude the full documentation from `--help`.
6. Do not print accents in user-facing messages (file encoding / terminal consistency);
   comments and Markdown may use them.
7. No network access except the optional fallback icon (`fetch`). No telemetry, no
   secrets, no writes outside the documented paths.
8. `sudo` must never be invoked without a TTY unless `sudo -n` already succeeds; otherwise
   fail early with a clear message (see `choose_mode`).
9. Detection functions used by the panel must run in *report* mode so an unsupported
   system still gets a readable panel instead of an exit.

## 5. Development workflow (definition of done)

```bash
cd freecad-thumbnailer-setup

# 1. static
bash -n freecad-thumbnailer-setup.sh
shellcheck -S style freecad-thumbnailer-setup.sh      # must be empty

# 2. read-only behaviour
./freecad-thumbnailer-setup.sh --help
./freecad-thumbnailer-setup.sh --status
./freecad-thumbnailer-setup.sh --dry-run

# 3. mutating behaviour (leave the module installed at the end)
./freecad-thumbnailer-setup.sh --yes --no-restart
./freecad-thumbnailer-setup.sh --test
./freecad-thumbnailer-setup.sh --dry-run --uninstall   # must NOT delete files
./freecad-thumbnailer-setup.sh --uninstall
./freecad-thumbnailer-setup.sh --yes --no-restart

# 4. interactive menu needs a pty
printf 'q\n'   | script -qec './freecad-thumbnailer-setup.sh' /dev/null   # exit 0
printf 'x\nq\n' | script -qec './freecad-thumbnailer-setup.sh' /dev/null  # re-prompts
printf ''      | script -qec './freecad-thumbnailer-setup.sh' /dev/null   # EOF -> exit 0
```

### Error-path suite (recreate in `/tmp/test-fcthumb.sh`)

Source the script (the `BASH_SOURCE` guard makes it safe) and call the checks in
subshells with `set +e` afterwards (the script enables `errexit` globally when sourced):

```bash
source ./freecad-thumbnailer-setup.sh ; set +e
( check_os )            # with `uname(){ echo Darwin; }`     -> must exit 2
( check_filemanager )   # with xdg-mime stubbed + no manager -> must exit 3
FORCE=1; check_filemanager                                        # -> must return 0
# unsupported distro: unshare -rm with a fake /etc/os-release bind-mounted -> exit 2
```

Clean-up before releasing: no `*.bak-thumbnailer` left in `$HOME/.config/FreeCAD`,
no test files on the desktop, `~/.local/state/.../setup.log` free of unexpected `error` lines.

## 6. Roadmap / ideas (not started)

- [ ] CI workflow (GitHub Actions) running `bash -n` + `shellcheck` on push
- [ ] Ship the error-path suite as `tests/run-tests.sh` and run it in CI
- [ ] Detect `.FCStd` files without an embedded thumbnail and offer to batch-render them
- [ ] Windows/macOS out of scope; Wayland-specific quirks not yet investigated
- [ ] Optional: localisation of the script's own messages (currently Spanish only)

## 7. Known limitations / risks

| Risk | Mitigation |
| --- | --- |
| Thunar / Dolphin / PCManFM branches cannot be executed on the reference machine (not installed) | Code-reviewed only; dry-run branches tested; `xfconf-query`/`dolphinrc` guarded |
| `--system` with a real sudo password cannot be exercised non-interactively | Clean early failure message; interactive path reviewed |
| Plasma < 6.6 needs `kde-fcstd-thumbnailer` (may not exist in the repos yet) | Warning printed, standard thumbnailer entry still installed |
| FreeCAD running ⇒ `SaveThumbnail` not modified | Explicit warning telling the user to re-run |
| Thumbnail cache is desktop-wide | Only `fail/` is cleared by default; full wipe requires `--full-cache` |

## 8. Changelog

- **2.1** — internal documentation refreshed; panel colours and hints (`MOD_MODE` vs `MODE`,
  missing FreeCAD, nothing installed); `need_cmd python3`; clean failure for `--system`
  without a TTY; `--dry-run --uninstall` fixed (was destructive); `Exec=` quoted in the
  thumbnailer entry; `mktemp` in `--status`; repo files (README, PLAN, LICENSE, .gitignore).
- **2.0** — restructured release: OS/file-manager compatibility checks with exit codes,
  `--force`, optional packages, Bazzite/`rpm-ostree` support, state rollback, diagnostics,
  panel + interactive menu, full header documentation, 4-pass review (0 shellcheck findings).
- **1.x** — initial single-purpose installer based on
  [andesfreedesign/FreeCAD-thumbnailer](https://github.com/andesfreedesign/FreeCAD-thumbnailer).
