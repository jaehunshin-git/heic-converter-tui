# HEIC Converter

[![PyPI](https://img.shields.io/pypi/v/heic-converter-tui?logo=pypi&logoColor=white)](https://pypi.org/project/heic-converter-tui/)
[![Downloads](https://api.pepy.tech/personalized-badge/heic-converter-tui?period=month&units=none&left_color=grey&right_color=blue&left_text=downloads%2Fmonth)](https://pepy.tech/projects/heic-converter-tui)
[![Python](https://img.shields.io/badge/Python-%E2%89%A53.11-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/LICENSE)
![macOS](https://img.shields.io/badge/Platform-macOS-000000?logo=apple&logoColor=white)
![Local processing](https://img.shields.io/badge/Processing-Local%20only-2E8B57)

> Convert locally from the macOS menu bar, configure with arrow keys, or automate with the CLI.

`heic-converter-tui` converts `.heic` photos in a directory to JPEG or PNG. Run it
without arguments for an interactive terminal UI driven by arrow keys and Enter,
or provide options for scripts and other non-interactive environments.

Version 0.3.0 also includes **HEIC Converter**, a standalone menu bar app for
Apple Silicon Macs running macOS 15 or later. The app bundles its Python runtime
and image codecs, so using the app does not require installing Python.

Photos never leave your computer, source files are never modified, and converted
files are written to a separate output directory. The package is available on
[PyPI](https://pypi.org/project/heic-converter-tui/). For Korean documentation,
see [README.ko.md](README.ko.md).

## ✨ Features

| Feature | Description |
| --- | --- |
| Menu bar app | Open a glass drop panel below the menu bar icon; keep it visible across focus changes and hide it without interrupting conversion or clipboard detection. |
| File queue | Drop one or more HEIC files, choose Convert now or Add to queue, and inspect per-file results. Dropping never starts conversion automatically. |
| Finder clipboard | Detect copied local file URLs in the background, or paste with the button or Command-V. Detection is optional and remembers your preference. |
| Localized arrow-key TUI | Choose Korean or English first, then set input and output paths, format, quality, metadata policy, and conflict policy step by step. |
| Automation-ready CLI | Use the same capabilities through command-line options in scripts and non-interactive environments. |
| JPEG and PNG output | Configure JPEG quality or PNG compression level. |
| HDR color preservation | On macOS 15 or later, convert Apple HDR gain maps into 16-bit HDR PNG output. |
| Safe metadata by default | Remove GPS and XMP while retaining other EXIF capture data and ICC profiles where possible. |
| Reliable file handling | Write to a temporary file before committing the result; a failed file does not stop the remaining conversions. |
| Recursive conversion | Use `--recursive` to include subdirectories while preserving the relative directory layout. |
| Conflict policies | Rename, skip, overwrite, or report an error when an output file already exists. |

## 🧭 Design principles

- **Local processing:** Photos are converted on your computer and are never sent to a network service.
- **Safe defaults:** The default metadata policy is `safe`, which removes location data; the default conflict policy is `rename`, which avoids overwriting existing files.
- **Consistent output:** Image orientation is applied to pixels and, when metadata is written, the output EXIF orientation value is normalized.
- **Automation-friendly:** The interactive UI and non-interactive command use the same conversion behavior and exit codes.

## 🛠 Technology stack

| Category | Technology |
| --- | --- |
| Runtime | Python 3.11+ |
| macOS app | SwiftUI, AppKit NSPanel, bundled JSONL worker |
| CLI | Typer, Rich |
| TUI | Questionary |
| Imaging | Pillow, pillow-heif, macOS ImageIO through PyObjC |
| Testing & Build | Pytest, Ruff, Hatchling, uv |

## 📁 Project structure

```text
heic-converter/
├── src/heic_converter/
│   ├── cli.py              # CLI options, progress, and summary
│   ├── core.py             # File discovery, path planning, conversion, atomic writes
│   ├── service.py          # Shared batch service and explicit file-list input
│   ├── worker.py           # Versioned JSONL requests and events
│   └── tui.py              # Arrow-key interactive configuration UI
├── macos/                  # Swift Package app and tests
├── packaging/macos/        # Pinned worker build, signing, and DMG validation
├── docs/                   # Korean build and verification documentation
├── tests/                  # CLI, TUI, image conversion, and file-handling tests
├── pyproject.toml          # Package metadata and dependencies
└── uv.lock                 # Locked development dependencies
```

## 🚀 Getting started

### Standalone macOS app

The app targets **Apple Silicon arm64, macOS 15+**. Intel and Universal2 builds
are outside the initial scope. A released app is distributed as a DMG with a
SHA-256 checksum through [GitHub Releases](https://github.com/jaehunshin-git/heic-converter-tui/releases).
For a checkout awaiting release, build the app with the
[build instructions](docs/macos-build-release.md).

1. Verify the downloaded DMG against its SHA-256 checksum.
2. Open the DMG and drag **HEIC Converter.app** to **Applications**.
3. Launch the app and click its menu bar icon to show the drop panel.

The panel opens directly below its menu bar icon and stays within the current
screen's available area. The compact panel defaults to 420 × 560 points, with a
380 × 560 minimum. Settings start collapsed, with the small JPEG/PNG selector,
quality or PNG compression, and right-aligned destination on one line below the
header. Long paths shorten from the beginning to show the end. Expanded settings
use native pickers for format, quality or compression, metadata, and conflict
policies. Metadata and conflict fields sit side by side; the destination has a
Change button.
Hover over the JPEG quality selector for the encoder explanation. Your latest
conversion settings and destination are restored after restarting the app. Native blur and translucent cards use a stronger background for
readability. **Reduce transparency** and increased contrast prioritize readability.
Buttons share rounded corners; one clipboard button states “클립보드 감지 켜짐”
or “클립보드 감지 꺼짐” and turns blue when enabled. Quit is red. The neutral close button retains keyboard focus
feedback; conversion and secondary actions occupy separate rows. Main buttons
respond to hovering and pressing, respecting Reduce motion; disabled buttons stay
static. The conversion button uses slightly larger text and an icon. The file list
has an icon, compact Retry and Clear buttons, and a smaller empty state.

The initial app uses **ad-hoc signing** and is not notarized. If macOS blocks
the first launch, use **System Settings → Privacy & Security → Open Anyway**
after attempting to launch this app. Follow
[Apple's instructions](https://support.apple.com/102445).
DMG packaging does not bypass Gatekeeper.

The drop zone explicitly invites dragging HEIC files and centers a compact Paste
button. It shows hover, drag target, loading, accepted, and rejected feedback.
Drop local `.heic` files, review the options, then choose **Convert now** or
**Add to queue**. Queue items wait until you start conversion. Finder copies
add accepted new files to the queue and reveal the panel below the menu bar icon
without taking focus or starting conversion. Duplicate or rejected inputs, startup
and re-enabled clipboard content do not trigger this reveal. Direct pastes add
files to the queue without revealing the panel.
An already open panel stays open, and the reveal respects Reduce motion.
Closing the panel keeps the app, detection, and any current job running.
Quit from the panel to stop the app.

The default destination is `~/Pictures/HEIC Converter`, created on the first
conversion. The defaults are JPEG, High quality (90), PNG compression 6, metadata
`safe`, and conflict policy `rename`. App output is collected in the selected
folder; the CLI continues to preserve directory layout. Settings and the saved
destination persist, while the file list and clipboard history are never saved.
Existing user-selected destinations are preserved; only the known QA setting
`/private/tmp/heic-converter-ui-check/converted` resets to the new default, without
moving or deleting files. Home paths appear with `~` in the app.
Click file rows to select multiple items; checkmarks and highlighting show the
selection. Use Select all or Deselect, then Remove selected, or use Remove all to
clear every removable item. Individual × buttons remain available. Scheduled and
converting items cannot be selected or removed by any of these actions. Removal
only changes the list: source and converted files remain on disk.
Removing an item allows that input to be added again; completed items otherwise
remain deduplicated until cleared. Duplicate notices clear when their related
files leave the lists; other input errors remain. Cancel finishes the current file and returns
unstarted files to the queue. New arrivals and option changes do not change an
already scheduled job.

The macOS app offers four JPEG quality presets: **Low (60)**, **Medium (80)**,
**High (90, default)**, and **Raw (100)**. Raw means maximum JPEG quality;
the numbers are encoder quality settings, not percentages. JPEG remains lossy,
and this option produces neither a RAW file nor lossless output. Existing saved
numeric quality values remain unchanged until you choose a preset; the app displays the nearest preset. PNG displays **Small (9)**,
**Balanced (6, default)**, **Fast (3)**, and **None (0)** in that order. These preserve the same pixels while
trading compression time for file size; native HDR PNG ignores this setting.
Saved numeric values and scheduled job settings are preserved. The TUI and CLI
retain their existing controls.

Selected and queued files have small previews decoded asynchronously with bounded
in-memory caching. Unavailable previews use a fallback icon; previews do not alter
source files or conversion.

Only local case-insensitive `.heic` files are accepted. Folders, symlinks,
unreadable files, `.heif`, clipboard bitmap images, and Photos file promises are
excluded with a reason. Photos guidance appears in the drop zone tooltip and
rejection messages, rather than as a persistent drop zone note. For Photos, export the unmodified HEIC original to Finder,
then drop or copy that file. Direct Photos drops are tracked in
[issue #4](https://github.com/jaehunshin-git/heic-converter-tui/issues/4); app naming
and icon work is tracked separately in
[issue #5](https://github.com/jaehunshin-git/heic-converter-tui/issues/5).
Clipboard detection uses a 0.75-second poll and skips
existing clipboard content on startup or re-enable. A denied access status stops
automatic reading; use file drops or direct paste instead. The app does not modify
the clipboard or source files. Manual copying of converted results and moving
results to Trash are planned in
[issue #6](https://github.com/jaehunshin-git/heic-converter-tui/issues/6).

### CLI/TUI requirements

- Python 3.11 or later
- macOS is the primary supported platform
- `uv` or `pipx`

The installation command installs the required Pillow and pillow-heif runtime
dependencies.

### Install

With `uv`:

```bash
uv tool install heic-converter-tui
```

Or with `pipx`:

```bash
pipx install heic-converter-tui
```

The distribution name is `heic-converter-tui`; the installed command is
`heic-converter`.

```bash
heic-converter --help
```

### Run the TUI

Run the command without arguments in a real terminal:

```bash
heic-converter
```

Choose `한국어` or `English` first. The rest of the UI, including validation
messages, choices, the summary, and cancellation notices, follows that choice.
Use the `↑` and `↓` arrow keys to move between choices, press Enter to confirm,
and type paths directly.

```text
HEIC Converter TUI

? Language / 언어 English

HEIC conversion settings

? Input directory path ./input
? Output directory path ./output
? Output format JPEG
? JPEG quality High (90)
? Include subdirectories? No — current directory only
? Metadata handling Keep safely (recommended) — remove sensitive data such as GPS
? When an output file has the same name Rename (recommended) — create a numbered filename

Configuration summary
  Input directory: input
  Output directory: output
  Output format: JPEG (JPEG quality 90)
  Include subdirectories: No
  Metadata: Keep safely
  File conflict handling: Rename

? Start conversion with these settings? Start
```

Press `Ctrl+C` or choose `Cancel` at the last prompt to exit without converting;
the command returns exit code `130`.

### Run from the command line

Specify an output format when running from a script or non-interactive environment.

```bash
# Convert HEIC files directly inside input to JPEG.
heic-converter --input ./input --output ./output --format jpeg

# Convert HEIC files in photos to PNG.
heic-converter --input ./photos --output ./converted --format png

# Include subdirectories and create a new name if output files already exist.
heic-converter \
  --input ./photos \
  --output ./converted \
  --format jpeg \
  --recursive \
  --on-conflict rename
```

Omitting `--format` outside a TTY produces a usage error.

### Upgrade or uninstall

For an installation made with `uv`:

```bash
uv tool upgrade heic-converter-tui
uv tool uninstall heic-converter-tui
```

For an installation made with `pipx`:

```bash
pipx upgrade heic-converter-tui
pipx uninstall heic-converter-tui
```

### Install and verify from source

To install a source checkout as a tool, run one of these commands from the
repository root:

```bash
uv tool install .
```

```bash
pipx install .
```

To install development dependencies and run the checks:

```bash
uv sync --group dev
uv run pytest
uv run ruff check .
uv build
uvx --from twine twine check dist/*
```

## 📚 Behavior and options

### Command format

```text
heic-converter --input INPUT --output OUTPUT --format {jpeg,png} [OPTIONS]
```

`--input` and `--output` are directory paths. They default to `./input` and
`./output`, respectively. They cannot refer to the same directory, and single-file
input is not supported.

| Option | Description | Default |
| --- | --- | --- |
| `-i, --input PATH` | Input HEIC directory | `./input` |
| `-o, --output PATH` | Output directory | `./output` |
| `-f, --format {jpeg,png}` | Output format | Required outside the TUI |
| `--jpeg-quality N` | JPEG quality, from 1 to 100 | `90` |
| `--png-compression N` | PNG compression level, from 0 to 9 | `6` |
| `--recursive` | Search subdirectories | Off |
| `--metadata {safe,preserve,strip}` | Metadata policy | `safe` |
| `--on-conflict {rename,skip,overwrite,error}` | Output conflict policy | `rename` |

JPEG output uses the `.jpeg` extension, while PNG output uses `.png`.
The TUI offers practical quality and compression presets; the CLI accepts any valid
value within the ranges above.

### Metadata and image handling

| Policy | Behavior |
| --- | --- |
| `safe` | Removes GPS and XMP while retaining other EXIF data and ICC profiles where possible. |
| `preserve` | Retains EXIF, XMP, and ICC profiles where supported by the conversion libraries. |
| `strip` | Removes EXIF and XMP. HDR PNG retains its ICC profile or CICP color signaling required for correct rendering. |

The converter applies image orientation to pixels and, when metadata is written,
normalizes the output EXIF orientation value to `1`. JPEG does not support alpha,
so transparent pixels are composited on white; PNG keeps alpha channels.

On macOS 15 or later, HEIC images with an Apple HDR gain map are converted to
16-bit HDR PNG with an HDR color profile. This preserves the source image's HDR
brightness and color appearance on compatible displays. Other environments
save the base SDR image, which may look different from the HEIC on an HDR
display. JPEG output is SDR. App results report whether HDR was applied and the
reason for SDR fallback. HDR preservation depends on the source gain map and
available ImageIO APIs; it is not guaranteed for every HEIC. PNG compression
level applies to the Pillow SDR path; the native HDR encoder controls its own
compression.

### File discovery and conflict handling

- Only files with a case-insensitive `.heic` extension are processed; `.heif` is not supported.
- By default, only files directly in the input directory are considered. `--recursive` includes subdirectories and preserves their relative layout in the output directory.
- If the output directory is inside the input directory, its tree is excluded from discovery.
- `rename` deterministically chooses an available filename such as `photo.jpeg`, `photo-2.jpeg`, or `photo-3.jpeg`.
- `skip` leaves the existing output file untouched and skips that input.
- `overwrite` replaces an existing output file.
- `error` records the conflicting file as a failure and continues with the next input.
- Files are first completed in a temporary file inside the output directory, so incomplete output files are not exposed.

### Supported scope

The converter processes one primary still image from each HEIC file and produces
JPEG or PNG. It does not support:

- PDF or HWP/HWPX conversion
- OCR or text extraction
- Live Photo video processing
- Extracting auxiliary images, sequences, or video instead of the primary still image
- Single-file input through the CLI (the app accepts explicit file lists)

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Every input was processed successfully. |
| `1` | One or more files could not be read, converted, or saved. |
| `2` | An argument, path, or option is invalid, or no `.heic` files were found. |
| `130` | The interactive UI was interrupted with `Ctrl+C` or cancelled. |

## License

This project is distributed under the [MIT License](LICENSE).
Bundled third-party components retain their own licenses, including the codec
notices shipped with pillow-heif. See the app's
`Contents/Resources/Licenses` for the Python runtime and library notices.
