"""Python 제품의 배포 설정과 안내 계약을 검증합니다."""

import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def test_pypi_description_and_sdist_use_dedicated_readme():
    config = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    project = config["project"]
    assert project["name"] == "heic-converter-tui"
    assert project["version"] == "0.3.0"
    assert project["scripts"] == {"heic-converter": "heic_converter.cli:run"}
    assert project["description"] and project["description"].isascii()
    assert project["readme"] == "README.pypi.md"
    assert project["urls"] == {
        "Homepage": "https://pypi.org/project/heic-converter-tui/",
        "Repository": "https://github.com/jaehunshin-git/heic-converter-tui",
        "Issues": "https://github.com/jaehunshin-git/heic-converter-tui/issues",
    }
    assert config["tool"]["hatch"]["build"]["targets"]["sdist"]["only-include"] == [
        "src",
        "tests",
        "pyproject.toml",
        "README.pypi.md",
        "LICENSE",
    ]
    assert config["tool"]["pytest"]["ini_options"]["testpaths"] == ["tests"]


def test_pypi_readme_uses_public_python_repository_without_app_links():
    readme = (ROOT / "README.pypi.md").read_text(encoding="utf-8")
    assert "https://pypi.org/project/heic-converter-tui/" in readme
    assert "https://github.com/jaehunshin-git/heiccy" not in readme
    assert "https://github.com/jaehunshin-git/heic-converter-tui" in readme
    assert "https://github.com/jaehunshin-git/heic-converter-tui/issues" in readme
    assert "](LICENSE)" not in readme
    assert "](docs/" not in readme
    assert ".dmg" not in readme.lower()
    assert ".app" not in readme.lower()
