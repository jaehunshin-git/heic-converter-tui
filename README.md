# HEIC Converter TUI

> A macOS-first batch HEIC converter: configure with arrow keys, automate with the CLI.

`heic-converter-tui` converts `.heic` photos in a directory to JPEG or PNG. Run it
without arguments for an interactive terminal UI driven by arrow keys and Enter,
or provide options for scripts and other non-interactive environments.

Photos never leave your computer, source files are never modified, and converted
files are written to a separate output directory. The package is available on
[PyPI](https://pypi.org/project/heic-converter-tui/). For Korean documentation,
see [README.ko.md](README.ko.md).

## ✨ Features

| Feature | Description |
| --- | --- |
| Localized arrow-key TUI | Choose Korean or English first, then set input and output paths, format, quality, metadata policy, and conflict policy step by step. |
| Automation-ready CLI | Use the same capabilities through command-line options in scripts and non-interactive environments. |
| JPEG and PNG output | Configure JPEG quality or PNG compression level. |
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
| CLI | Typer, Rich |
| TUI | Questionary |
| Imaging | Pillow, pillow-heif |
| Testing & Build | Pytest, Ruff, Hatchling, uv |

## 📁 Project structure

```text
heic-converter/
├── src/heic_converter/
│   ├── cli.py              # CLI validation, conversion execution, and summary
│   ├── core.py             # File discovery, path planning, conversion, atomic writes
│   └── tui.py              # Arrow-key interactive configuration UI
├── tests/                  # CLI, TUI, image conversion, and file-handling tests
├── pyproject.toml          # Package metadata and dependencies
└── uv.lock                 # Locked development dependencies
```

## 🚀 Getting started

### Requirements

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
| `strip` | Does not write metadata to the output image. |

The converter applies image orientation to pixels and, when metadata is written,
normalizes the output EXIF orientation value to `1`. JPEG does not support alpha,
so transparent pixels are composited on white; PNG keeps alpha channels.

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
- Single-file input

### Exit codes

| Code | Meaning |
| --- | --- |
| `0` | Every input was processed successfully. |
| `1` | One or more files could not be read, converted, or saved. |
| `2` | An argument, path, or option is invalid, or no `.heic` files were found. |
| `130` | The interactive UI was interrupted with `Ctrl+C` or cancelled. |
