"""외부 이미지 없이 앱 아이콘 크기별 PNG를 생성합니다."""

from pathlib import Path

from PIL import Image, ImageDraw


def main() -> None:
    import sys

    destination = Path(sys.argv[1])
    destination.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = size * scale
            canvas = Image.new("RGBA", (pixels, pixels))
            draw = ImageDraw.Draw(canvas)
            draw.rounded_rectangle(
                (0, 0, pixels - 1, pixels - 1),
                radius=pixels * 0.22,
                fill="#245bd1",
            )
            draw.rounded_rectangle(
                (pixels * 0.19, pixels * 0.22, pixels * 0.81, pixels * 0.76),
                radius=pixels * 0.07,
                fill="#ffffff",
            )
            draw.ellipse(
                (pixels * 0.59, pixels * 0.30, pixels * 0.71, pixels * 0.42),
                fill="#f2b84b",
            )
            draw.polygon(
                [
                    (pixels * 0.26, pixels * 0.66),
                    (pixels * 0.43, pixels * 0.43),
                    (pixels * 0.57, pixels * 0.60),
                    (pixels * 0.66, pixels * 0.50),
                    (pixels * 0.76, pixels * 0.66),
                ],
                fill="#245bd1",
            )
            suffix = "@2x" if scale == 2 else ""
            canvas.save(destination / f"icon_{size}x{size}{suffix}.png")


if __name__ == "__main__":
    main()
