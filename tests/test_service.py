"""명시 파일 작업의 검증·집계·경합·취소 계약을 검증합니다."""

from threading import Event

import pytest
from PIL import Image

from heic_converter.core import convert_image
from heic_converter.service import (
    ConversionOptions,
    ValidationError,
    prepare_files,
    run_batch,
)


def test_file_list_filters_invalid_inputs_and_deduplicates(tmp_path, heic_factory):
    first = heic_factory(tmp_path / "사진 10.HEIC")
    second = heic_factory(tmp_path / "사진 2.heic")
    link = tmp_path / "링크.heic"
    link.symlink_to(first)
    unsupported = tmp_path / "other.heif"
    unsupported.write_bytes(b"x")
    job = prepare_files(
        [first, second, first, link, unsupported, tmp_path, tmp_path / "missing.heic"],
        tmp_path / "결과 폴더", ConversionOptions(),
    )
    assert job.files == (second, first)
    assert len(job.rejected) == 5
    assert not job.output_directory.exists()


@pytest.mark.parametrize(("policy", "counts", "outputs"), [
    ("rename", (2, 0, 0), {"same.jpeg", "same-2.jpeg"}),
    ("skip", (1, 1, 0), {"same.jpeg"}),
    ("error", (1, 0, 1), {"same.jpeg"}),
    ("overwrite", (2, 0, 0), {"same.jpeg"}),
])
def test_same_name_in_different_folders_uses_shared_policy(tmp_path, heic_factory, policy, counts, outputs):
    sources = []
    for name in ("one", "two"):
        folder = tmp_path / name
        folder.mkdir()
        sources.append(heic_factory(folder / "same.heic"))
    job = prepare_files(sources, tmp_path / "out", ConversionOptions(on_conflict=policy))
    result = run_batch(job)
    assert (result.succeeded, result.skipped, result.failed) == counts
    assert {p.name for p in job.output_directory.iterdir()} == outputs
    for source in sources:
        assert source.is_file()


def test_cancel_finishes_current_atomic_save_and_keeps_remaining(tmp_path, heic_factory):
    sources = [heic_factory(tmp_path / f"{i}.heic") for i in range(3)]
    cancellation = Event()
    events = []

    def convert_and_cancel(*args, **kwargs):
        cancellation.set()
        return convert_image(*args, **kwargs)

    job = prepare_files(sources, tmp_path / "out", ConversionOptions())
    result = run_batch(job, cancel=cancellation, converter=convert_and_cancel,
                       emit=lambda event, fields: events.append((event, fields)))
    assert result.cancelled and result.exit_code == 130
    assert result.succeeded == 1 and result.remaining == tuple(sources[1:])
    assert [event for event, _ in events] == ["file_started", "file_succeeded", "cancelled"]
    with Image.open(tmp_path / "out" / "0.jpeg") as image:
        image.verify()
    assert len(list(job.output_directory.iterdir())) == 1


def test_deleted_input_and_corruption_do_not_abort_other_files(tmp_path, heic_factory):
    files = [heic_factory(tmp_path / "1.heic"), tmp_path / "2.heic", heic_factory(tmp_path / "3.heic")]
    files[1].write_bytes(b"corrupt")
    job = prepare_files(files, tmp_path / "out", ConversionOptions())
    files[0].unlink()
    events = []
    result = run_batch(job, emit=lambda event, fields: events.append((event, fields)))
    assert result.succeeded == 1 and result.failed == 2 and result.exit_code == 1
    assert [fields["error_code"] for event, fields in events if event == "file_failed"] == [
        "input_missing", "conversion_failed",
    ]


def test_permission_errors_are_distinguished(tmp_path, heic_factory, monkeypatch):
    from heic_converter import service
    source = heic_factory(tmp_path / "photo.heic")
    job = prepare_files([source], tmp_path / "out", ConversionOptions())
    events = []
    monkeypatch.setattr(service.os, "access", lambda *_: False)
    result = run_batch(job, emit=lambda event, fields: events.append((event, fields)))
    assert result.failed == 1
    assert events[1][1]["error_code"] == "input_permission"
    monkeypatch.setattr(service.os, "access", lambda *_: True)

    def deny_output(*_args, **_kwargs):
        raise PermissionError("출력 폴더 쓰기 권한 없음")

    events.clear()
    run_batch(job, converter=deny_output, emit=lambda event, fields: events.append((event, fields)))
    assert events[1][1]["error_code"] == "output_permission"


def test_conflict_retry_replans_after_atomic_race(tmp_path, heic_factory):
    source = heic_factory(tmp_path / "photo.heic")
    job = prepare_files([source], tmp_path / "out", ConversionOptions())
    raced = False

    def converter(source, target, **options):
        nonlocal raced
        if not raced:
            raced = True
            target.parent.mkdir()
            target.write_bytes(b"another process")
        return convert_image(source, target, **options)

    assert run_batch(job, converter=converter).succeeded == 1
    assert (job.output_directory / "photo.jpeg").read_bytes() == b"another process"
    assert (job.output_directory / "photo-2.jpeg").is_file()


@pytest.mark.parametrize("options", [
    {"jpeg_quality": True}, {"png_compression": "6"}, {"metadata": "invalid"},
    {"output_format": "heif"}, {"on_conflict": "invalid"},
])
def test_options_reject_invalid_types_and_values(options):
    with pytest.raises(ValidationError):
        ConversionOptions(**options)


def test_directory_alias_resolves_to_same_real_input(tmp_path, heic_factory):
    folder = tmp_path / "real"
    folder.mkdir()
    source = heic_factory(folder / "photo.heic")
    alias = tmp_path / "alias"
    alias.symlink_to(folder, target_is_directory=True)
    job = prepare_files([alias / source.name, source], tmp_path / "out", ConversionOptions())
    assert job.files == (source,)
    assert len(job.rejected) == 1 and "이미 입력" in job.rejected[0].reason
    assert run_batch(job).succeeded == 1
