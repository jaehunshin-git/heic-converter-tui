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

**HEIC Converter** is the standalone menu bar app targeting Apple Silicon and
macOS 15+. Its bundled Python runtime and codecs do not require a separate Python installation.
The automatic clipboard workflow in [issue #7](https://github.com/jaehunshin-git/heic-converter-tui/issues/7)
is currently being implemented in source and has not been released. This description
must not be treated as a capability of an existing release.

Photos are processed locally and source files remain unchanged. The CLI/TUI writes
converted files to a separate output directory. The app prepares temporary clipboard
results. The CLI/TUI package is available on [PyPI](https://pypi.org/project/heic-converter-tui/).
See [README.ko.md](README.ko.md) for Korean documentation.

## ✨ Features

| Feature | Description |
| --- | --- |
| Menu bar app (issue #7, unreleased) | Left-click shows an enable/disable toggle and the current clipboard file names, thumbnails, and status. Right-click opens Settings or Quit. Copy detection does not open the panel. |
| Automatic clipboard conversion (in implementation) | Convert supported HEIC inputs to JPEG/PNG, then paste with the usual Command-V. Preserve other items and publish only when every HEIC succeeds and the clipboard generation is still current. |
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

**Issue #7 is currently being implemented and is not released.** The following
workflow describes the source change contract, not verified behavior of an existing DMG.
The app targets **Apple Silicon arm64, macOS 15+** and bundles its worker runtime.
App/DMG distribution is being separated from PyPI distribution; this change keeps
`pyproject.toml` and the Python package version unchanged. Existing releases are
available through [GitHub Releases](https://github.com/jaehunshin-git/heic-converter-tui/releases).
For source builds, see [the build guide](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-build-release.md).

The minimal panel shows the automatic conversion toggle and only the current
clipboard's file names, thumbnails, and ready/converting/completed/failed status.
Left-click opens or hides it; right-click offers Settings and Quit. Settings live in
a separate window. The pointer to the menu bar icon and screen-edge placement remain.
Copy detection never opens the panel and no clipboard history is kept.
The panel closes when focus moves to another app or window. Click the menu bar icon to open it again.
The photo-in-clipboard icon is shared by the menu bar and panel. The panel height
fits up to three file rows and the footer; longer lists scroll. A manually enlarged
panel retains its height.
When the panel is hidden, a small notice below the menu bar icon shows the copied
HEIC count, conversion progress, and the final result without taking keyboard focus.
Success appears only after all results are published to the current clipboard.
Completion notices close after four seconds; failures close after six seconds.
Click a notice to open the current clipboard panel, or dismiss it with its close button.
The notice height fits its text and progress bar automatically.

Automatic conversion defaults to on for a fresh configuration; the toggle and
conversion options persist. An enabled startup also processes the current HEIC input,
and enabling the feature processes the current input. Clipboard polling is every
0.25 seconds. Supported input is a readable local regular `.heic` file represented
by a file URL, or raw `public.heic` image data. File extensions are case-insensitive.
File promises and representations that cannot be read and restored safely are rejected.
An access denial stops automatic reads and is shown as a status.

Video declarations, MOV/other movie file URLs, and Photos video asset metadata
take priority over accompanying JPEG/HEIC previews. Videos are shown as excluded
and their clipboard representations remain unchanged. Photos may supply a JPEG
poster rather than the original MOV file; preserving that clipboard does not export
the video. To obtain the original video file, use
[Photos' unmodified-original export](https://support.apple.com/ko-kr/guide/photos/pht6e157c5f/12.0/mac/27).
Unrecognized Photos asset metadata is preserved without automatic conversion.

Copy supported HEIC content, wait for completion, then use the usual **Command-V**
in the receiving app. Pasting before conversion completes may deliver the original.
Non-HEIC files and text retain their item order and preservable representations.
All HEIC conversions must succeed before publishing; a new copy, cancellation, or
turning the feature off prevents pending results from overwriting the clipboard.
Turning it off leaves already published results in place.

Converted items provide a temporary file URL and image representations for receiving
apps. Referenced files remain available while the published clipboard needs them;
results do not accumulate in a normal output folder. Normal quit restores the original
only if the clipboard is still the app's published generation, then cleans up temporary
files. Failed restoration retains referenced files. Synthetic items passed preservation
checks after process exit; preservation of actual Photos file URLs after normal quit
still needs validation. A separate clipboard restore tool lost the Photos URL after
exit while retaining the image and metadata. Source files are never modified.
Recovery after an abnormal exit is not guaranteed.

Defaults remain JPEG, JPEG quality 90, PNG compression 6, and metadata `safe`.
Previously saved conversion values are retained. Legacy `outputDirectory` and
`onConflict` settings are preserved but excluded from the automatic conversion UI.
The CLI/TUI retains its existing output paths, conflict policies, and controls.

Local checks covered Photos HEIC copy, synthetic original/edited/multiple photos,
and video-poster exclusion. Photos raw HEIC takes priority over its potentially
unavailable file URL. Offline ordinary files are rejected before opening them.
Finder pasted one and three converted files and six mixed files without duplicates.
KakaoTalk showed one and six files in its pre-send preview; no message was sent.
iCloud-only assets, Photos drag promises, and actual chat delivery remain unverified.
Receiving apps choose supported representations and may not paste every preserved item.
See [the clipboard contract and verification limits (Korean)](https://github.com/jaehunshin-git/heic-converter-tui/blob/main/docs/macos-auto-clipboard.md).
Local validation passed 136 Python tests, 93 Swift tests, Ruff, app/DMG smoke and
Python distribution checks on macOS 27.2. Apple Silicon macOS 15 and 26 also passed
tests, app builds, DMG installation checks and Python distribution validation for
commit `bdbde95` in [GitHub Actions](https://github.com/jaehunshin-git/heic-converter-tui/actions/runs/38128156256).

App packages use ad-hoc signing and are not notarized. DMG packaging does not bypass
Gatekeeper. Verify a released DMG's checksum, install the app into Applications, and
follow [Apple's launch instructions](https://support.apple.com/102445) if blocked.

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
