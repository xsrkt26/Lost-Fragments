from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


BASE_MENU_SIZE = (1280.0, 720.0)
SOURCE_IMAGE = Path("assets/ui/main_menu/main_menu_background.png")
OUTPUT_DIR = Path("assets/ui/main_menu")

# Rects are authored in the same 1280x720 design space used by main_menu.gd.
# They include a small margin around each scroll so the hover scale has enough
# painted edge to grow from.
SCROLL_RECTS = {
	"new_game": (66.0, 148.0, 210.0, 520.0),
	"continue": (244.0, 218.0, 218.0, 446.0),
	"gallery": (428.0, 288.0, 194.0, 376.0),
	"settings": (590.0, 348.0, 184.0, 316.0),
	"quit": (748.0, 400.0, 184.0, 264.0),
}


def _scaled_rect(rect: tuple[float, float, float, float], image_size: tuple[int, int]) -> tuple[int, int, int, int]:
	scale_x = image_size[0] / BASE_MENU_SIZE[0]
	scale_y = image_size[1] / BASE_MENU_SIZE[1]
	x, y, width, height = rect
	left = max(0, int(round(x * scale_x)))
	top = max(0, int(round(y * scale_y)))
	right = min(image_size[0], int(round((x + width) * scale_x)))
	bottom = min(image_size[1], int(round((y + height) * scale_y)))
	return left, top, right - left, bottom - top


def _shape_mask(size: tuple[int, int]) -> np.ndarray:
	width, height = size
	mask = Image.new("L", size, 0)
	draw = ImageDraw.Draw(mask)

	# Parchment body, including the irregular torn side strips. The mask is
	# intentionally generous: small background overlaps are less noticeable than
	# missing paper edges when the button scales on hover.
	draw.polygon(
		[
			(width * 0.14, height * 0.13),
			(width * 0.86, height * 0.13),
			(width * 0.88, height * 0.29),
			(width * 0.83, height * 0.47),
			(width * 0.87, height * 0.68),
			(width * 0.79, height * 0.97),
			(width * 0.18, height * 0.97),
			(width * 0.11, height * 0.72),
			(width * 0.17, height * 0.52),
			(width * 0.12, height * 0.33),
		],
		fill=255,
	)
	# Top roll and the short curled lip on the right.
	draw.rounded_rectangle(
		(width * 0.14, height * 0.01, width * 0.86, height * 0.19),
		radius=max(8, int(height * 0.045)),
		fill=255,
	)
	draw.ellipse(
		(width * 0.75, height * 0.025, width * 0.95, height * 0.18),
		fill=255,
	)
	shape = np.array(mask, dtype=np.uint8)
	shape = cv2.GaussianBlur(shape, (5, 5), 0)
	return shape


def _extract_alpha(crop_bgr: np.ndarray) -> np.ndarray:
	height, width = crop_bgr.shape[:2]
	alpha = _shape_mask((width, height))
	close_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
	open_kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
	alpha = cv2.morphologyEx(alpha, cv2.MORPH_CLOSE, close_kernel)
	alpha = cv2.morphologyEx(alpha, cv2.MORPH_OPEN, open_kernel)
	alpha = cv2.GaussianBlur(alpha, (3, 3), 0)
	return alpha


def main() -> None:
	source = cv2.imread(str(SOURCE_IMAGE), cv2.IMREAD_COLOR)
	if source is None:
		raise FileNotFoundError(SOURCE_IMAGE)

	image_size = (source.shape[1], source.shape[0])
	for name, rect in SCROLL_RECTS.items():
		x, y, width, height = _scaled_rect(rect, image_size)
		crop_bgr = source[y : y + height, x : x + width]
		alpha = _extract_alpha(crop_bgr)
		crop_rgba = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGBA)
		crop_rgba[:, :, 3] = alpha
		output = OUTPUT_DIR / f"main_menu_scroll_{name}.png"
		Image.fromarray(crop_rgba).save(output, optimize=True)
		print(f"Wrote {output} ({width}x{height})")


if __name__ == "__main__":
	main()
