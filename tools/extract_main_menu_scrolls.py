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
	"new_game": (72.0, 154.0, 194.0, 504.0),
	"continue": (252.0, 224.0, 204.0, 432.0),
	"gallery": (438.0, 294.0, 176.0, 362.0),
	"settings": (598.0, 358.0, 170.0, 300.0),
	"quit": (756.0, 410.0, 170.0, 248.0),
}
BOTTOM_ALPHA_LIMITS = {
	"new_game": 0.84,
	"continue": 0.92,
	"gallery": 0.92,
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

	# Parchment body, including torn side strips.
	draw.polygon(
		[
			(width * 0.18, height * 0.15),
			(width * 0.82, height * 0.15),
			(width * 0.80, height * 0.91),
			(width * 0.16, height * 0.91),
		],
		fill=255,
	)
	# Top roll and the short curled lip on the right.
	draw.rounded_rectangle(
		(width * 0.18, height * 0.02, width * 0.82, height * 0.17),
		radius=max(8, int(height * 0.045)),
		fill=255,
	)
	draw.ellipse(
		(width * 0.76, height * 0.03, width * 0.94, height * 0.16),
		fill=255,
	)
	shape = np.array(mask, dtype=np.uint8)
	shape = cv2.GaussianBlur(shape, (5, 5), 0)
	return shape


def _extract_alpha(crop_bgr: np.ndarray, name: str) -> np.ndarray:
	height, width = crop_bgr.shape[:2]
	alpha = _shape_mask((width, height))
	b, g, r = cv2.split(crop_bgr)
	yy = np.arange(height)[:, None]
	lower_crop = yy > int(height * 0.70)
	leaf_like = lower_crop & (g > r + 8) & (g > b + 18)
	mushroom_like = lower_crop & (yy > int(height * 0.80)) & (r > g + 60) & (r > b + 60) & (r > 175)
	alpha[leaf_like | mushroom_like] = 0
	if name in BOTTOM_ALPHA_LIMITS:
		alpha[int(height * BOTTOM_ALPHA_LIMITS[name]) :, :] = 0
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
		alpha = _extract_alpha(crop_bgr, name)
		crop_rgba = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2RGBA)
		crop_rgba[:, :, 3] = alpha
		output = OUTPUT_DIR / f"main_menu_scroll_{name}.png"
		Image.fromarray(crop_rgba).save(output, optimize=True)
		print(f"Wrote {output} ({width}x{height})")


if __name__ == "__main__":
	main()
