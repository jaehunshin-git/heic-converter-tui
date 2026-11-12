# heic-converter-tui

English | [한국어](README.ko.md)

Convert directories of HEIC images to JPEG or PNG with a Python command-line
interface or an arrow-key TUI. Processing happens locally, and source files are
not modified.

The distribution name is **heic-converter-tui** and the installed command is
**heic-converter**. Package information is available on
[PyPI](https://pypi.org/project/heic-converter-tui/).

Source code and development documentation are available in the
[GitHub repository](https://github.com/jaehunshin-git/heic-converter-tui).
Report package issues in its
[issue tracker](https://github.com/jaehunshin-git/heic-converter-tui/issues).

## Features

- Convert directories of case-insensitive `.heic` files to JPEG or PNG.
- Use an interactive TUI in Korean or English, or use the CLI in scripts.
- Set JPEG quality, PNG compression, metadata handling, recursion, and output
  conflict behavior.
- Preserve relative output paths when recursively converting a directory tree.
- Apply image orientation, preserve PNG transparency, and composite JPEG alpha
  onto white.
- Preserve supported Apple HDR gain maps as 16-bit PNG on macOS 15 or later.

## Supported environment

- Python 3.11 or later.
- macOS is the primary supported platform. Other operating systems are not
  currently validated.
- CI validates macOS 15 with Python 3.11 and macOS 26 with Python 3.12.12.
  Python 3.11 is the minimum package requirement.
- Pillow and pillow-heif are installed as package dependencies. On macOS,
  PyObjC provides access to native ImageIO APIs.
- HDR PNG requires macOS 15 or later, supported ImageIO APIs, and a supported
  source gain map with EXIF orientation 1. Rotated inputs and other unsupported
  inputs or environments use the SDR base image; JPEG is SDR.
- The TUI requires an interactive terminal. Non-interactive use must specify
  `--format`.

The TUI offers Korean and English. CLI help, conversion progress, and error
messages are currently in Korean. Selecting English in the TUI does not
translate every message.

## Installation

Install with `uv`:

```bash
uv tool install heic-converter-tui
```

Or install with `pipx`:

```bash
pipx install heic-converter-tui
```

Check the installed command:

```bash
heic-converter --help
```

## Usage

### Interactive TUI

Run without arguments in a real terminal:

```bash
heic-converter
```

Choose a language, input and output directories, output format, quality or
compression, recursion, metadata policy, and conflict policy. Use the arrow
keys and Enter to select options, type paths directly, and review the summary
before starting. Press Ctrl+C or choose Cancel to exit with code 130.

### CLI

```bash
# Convert HEIC files directly inside input to JPEG.
heic-converter --input ./input --output ./output --format jpeg

# Convert a directory tree to PNG while preserving relative paths.
heic-converter --input ./photos --output ./converted --format png --recursive

# Customize JPEG quality, remove metadata, and rename on conflicts.
heic-converter --input ./photos --output ./converted --format jpeg \
  --jpeg-quality 95 --metadata strip --on-conflict rename
```

Input and output must be different directories. Single-file CLI input is not
supported. Files with a `.heif` extension, video, image sequences, and
auxiliary-image extraction are outside the supported scope. If the output
directory is inside the input directory, it is excluded from discovery.

| Option | Values or purpose | Default |
| --- | --- | --- |
| `-i, --input PATH` | Input directory | `./input` |
| `-o, --output PATH` | Output directory | `./output` |
| `-f, --format FORMAT` | `jpeg`, `png` | Required outside the TUI |
| `--jpeg-quality N` | `1`–`100` | `90` |
| `--png-compression N` | `0`–`9` | `6` |
| `--recursive` | Include subdirectories | Off |
| `--metadata POLICY` | `safe`, `preserve`, `strip` | `safe` |
| `--on-conflict POLICY` | `rename`, `skip`, `overwrite`, `error` | `rename` |

The `safe` metadata policy removes GPS and XMP while retaining other EXIF data
and ICC profiles where possible. `preserve` retains supported metadata, and
`strip` removes EXIF and XMP. HDR PNG retains the color information required for
rendering. PNG compression settings apply to the Pillow SDR path; the native HDR
encoder controls its own compression.

Output files use `.jpeg` or `.png`. The default `rename` policy chooses an
available numbered name; `skip` leaves existing files unchanged, `overwrite`
replaces them, and `error` records a failure and continues. Results are first
completed in a temporary file in the output directory so incomplete files are
not exposed.

| Exit code | Meaning |
| --- | --- |
| `0` | All inputs were processed successfully. |
| `1` | One or more files could not be read, converted, or saved. |
| `2` | Arguments, paths, or options are invalid, or no HEIC files were found. |
| `130` | Interactive cancellation or interruption. |

## Development

Install the locked development dependencies, run the checks, and validate the
built wheel and sdist:

```bash
uv sync --locked --group dev
uv run --locked ruff check src tests scripts
uv run --locked pytest
uv build --out-dir dist/python
uv run --locked python scripts/validate_python_dist.py dist/python
```

Tests use temporary synthetic images. Keep personal files in `input/` and
`output/` out of Git and distribution files.

The package uses Pillow, pillow-heif, Typer, Rich, and questionary. On macOS,
PyObjC Quartz provides the native HDR path. Hatchling builds the package.

```text
src/heic_converter/  CLI, TUI, conversion core, and JSONL worker
tests/              Regression tests
scripts/            Distribution validation tools
docs/               Development and protocol documentation
pyproject.toml      Package metadata and build configuration
uv.lock             Locked dependencies
```

## Documentation

Development documentation is in Korean:

- [Build and release guide](docs/build.md)
- [Worker JSONL contract](docs/worker-protocol.md)
- [Commit message hooks](docs/commit-message-hooks.md)
- [Product repository split](docs/decisions/2026-10-18-product-repository-split.md)
- [Public repository policy](docs/decisions/2026-10-18-python-repository-public.md)
- [Dedicated PyPI description](README.pypi.md)

## License

This package is distributed under the MIT License. Third-party dependencies,
including codecs distributed with pillow-heif, retain their own licenses and
notices.
