"""방향키와 Enter로 설정을 수집하는 대화형 터미널 UI입니다."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, cast

from .core import ConflictMode, MetadataMode, OutputFormat

try:
    import questionary
except ModuleNotFoundError:  # 설치 전에도 다른 공개 API를 사용할 수 있게 합니다.
    questionary: Any | None = None


@dataclass(frozen=True)
class TuiConfig:
    """대화형 UI에서 확정한 변환 설정입니다."""

    input_path: Path
    output_path: Path
    output_format: OutputFormat
    jpeg_quality: int
    png_compression: int
    recursive: bool
    metadata: MetadataMode
    on_conflict: ConflictMode


def _questionary() -> Any:
    """질문 라이브러리를 반환하거나 설치 안내 오류를 발생시킵니다."""

    if questionary is None:
        message = "대화형 UI에는 questionary>=2.0.1 패키지가 필요합니다."
        raise RuntimeError(message)
    return questionary


def _input_directory_validator(value: str) -> bool | str:
    """입력값이 존재하는 디렉터리인지 확인합니다."""

    path = Path(value).expanduser()
    if not value.strip():
        return "입력 디렉터리 경로를 입력하세요."
    if not path.exists():
        return "입력 디렉터리를 찾을 수 없습니다."
    if not path.is_dir():
        return "입력 경로는 디렉터리여야 합니다."
    return True


def _output_directory_validator(value: str) -> bool | str:
    """출력값이 새 디렉터리이거나 기존 디렉터리인지 확인합니다."""

    path = Path(value).expanduser()
    if not value.strip():
        return "출력 디렉터리 경로를 입력하세요."
    if path.exists() and not path.is_dir():
        return "출력 경로에 이미 파일이 있습니다. 디렉터리 경로를 입력하세요."
    return True


def _ask_text(message: str, default: Path, validator: Any) -> str | None:
    """문자열 입력 질문을 표시합니다."""

    answer = _questionary().text(
        message,
        default=str(default),
        validate=validator,
        instruction="Enter로 다음 단계로 이동",
    ).ask()
    return cast(str | None, answer)


def _ask_select(message: str, choices: list[tuple[str, Any]], default: Any) -> Any:
    """방향키로 고르는 선택 질문을 표시합니다."""

    menu_choices = [_questionary().Choice(title, value=value) for title, value in choices]
    return _questionary().select(
        message,
        choices=menu_choices,
        default=default,
        instruction="↑/↓ 방향키로 이동 · Enter로 선택",
    ).ask()


def _metadata_choices() -> list[tuple[str, MetadataMode]]:
    """메타데이터 정책의 한국어 설명 선택지를 만듭니다."""

    return [
        ("안전하게 유지 (권장) — GPS 등 민감 정보는 제거", "safe"),
        ("원본 유지 — 가능한 메타데이터를 보존", "preserve"),
        ("모두 제거 — 메타데이터를 저장하지 않음", "strip"),
    ]


def _print_summary(config: TuiConfig) -> None:
    """시작 전 사용자가 검토할 수 있도록 설정을 출력합니다."""

    format_label = config.output_format.upper() if config.output_format else "미선택"
    detail = (
        f"JPEG 품질 {config.jpeg_quality}"
        if config.output_format == "jpeg"
        else f"PNG 압축 {config.png_compression}"
    )
    print("\n설정 요약")
    print(f"  입력 디렉터리: {config.input_path}")
    print(f"  출력 디렉터리: {config.output_path}")
    print(f"  출력 형식: {format_label} ({detail})")
    print(f"  하위 디렉터리 포함: {'예' if config.recursive else '아니요'}")
    print(f"  메타데이터: {config.metadata}")
    print(f"  파일 충돌 처리: {config.on_conflict}")


def collect_tui_config(
    input_path: Path = Path("./input"),
    output_path: Path = Path("./output"),
    output_format: OutputFormat | None = None,
    jpeg_quality: int = 90,
    png_compression: int = 6,
    recursive: bool = False,
    metadata: MetadataMode = "safe",
    on_conflict: ConflictMode = "rename",
) -> TuiConfig | None:
    """대화형 질문으로 변환 설정을 수집하고 취소되면 ``None``을 반환합니다."""

    try:
        print("\nHEIC 이미지 변환 설정")
        print("↑/↓ 방향키로 선택하고 Enter로 확정합니다. Ctrl+C로 언제든 취소합니다.\n")

        input_answer = _ask_text(
            "입력 디렉터리 경로", input_path, _input_directory_validator
        )
        if input_answer is None:
            return None

        output_answer = _ask_text(
            "출력 디렉터리 경로", output_path, _output_directory_validator
        )
        if output_answer is None:
            return None

        selected_format = _ask_select(
            "출력 형식",
            [("JPEG", "jpeg"), ("PNG", "png")],
            output_format or "jpeg",
        )
        if selected_format is None:
            return None
        format_value = cast(OutputFormat, selected_format)

        quality_value = jpeg_quality
        compression_value = png_compression
        if format_value == "jpeg":
            selected_quality = _ask_select(
                "JPEG 품질",
                [
                    ("최고 품질 (100)", 100),
                    ("매우 높음 (95)", 95),
                    ("높음 (90)", 90),
                    ("균형 (85)", 85),
                    ("작은 파일 (80)", 80),
                ],
                jpeg_quality if jpeg_quality in {100, 95, 90, 85, 80} else 90,
            )
            if selected_quality is None:
                return None
            quality_value = cast(int, selected_quality)
        else:
            selected_compression = _ask_select(
                "PNG 압축 수준",
                [
                    ("압축 없음 (0)", 0),
                    ("낮음 (3)", 3),
                    ("기본 (6)", 6),
                    ("최대 (9)", 9),
                ],
                png_compression if png_compression in {0, 3, 6, 9} else 6,
            )
            if selected_compression is None:
                return None
            compression_value = cast(int, selected_compression)

        recursive_value = _ask_select(
            "하위 디렉터리도 변환할까요?",
            [("예 — 하위 디렉터리 포함", True), ("아니요 — 현재 디렉터리만", False)],
            recursive,
        )
        if recursive_value is None:
            return None

        metadata_value = _ask_select("메타데이터 처리", _metadata_choices(), metadata)
        if metadata_value is None:
            return None

        conflict_value = _ask_select(
            "같은 이름의 출력 파일이 있을 때",
            [
                ("이름 변경 (권장) — 번호를 붙여 새 파일 생성", "rename"),
                ("건너뛰기 — 기존 파일 유지", "skip"),
                ("덮어쓰기 — 기존 파일 교체", "overwrite"),
                ("오류로 중단 — 충돌을 알림", "error"),
            ],
            on_conflict,
        )
        if conflict_value is None:
            return None

        config = TuiConfig(
            input_path=Path(input_answer).expanduser(),
            output_path=Path(output_answer).expanduser(),
            output_format=format_value,
            jpeg_quality=quality_value,
            png_compression=compression_value,
            recursive=cast(bool, recursive_value),
            metadata=cast(MetadataMode, metadata_value),
            on_conflict=cast(ConflictMode, conflict_value),
        )
        _print_summary(config)
        should_start = _ask_select(
            "이 설정으로 변환을 시작할까요?",
            [("시작", True), ("취소", False)],
            True,
        )
        if should_start is not True:
            return None
        return config
    except (KeyboardInterrupt, EOFError):
        return None
