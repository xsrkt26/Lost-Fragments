import cv2
import numpy as np
import os
import sys

def process_image(img_path, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    # Read image with alpha channel if exists, else add it
    img = cv2.imread(img_path, cv2.IMREAD_UNCHANGED)
    if img is None:
        print(f"Failed to load {img_path}")
        return

    if img.shape[2] == 3:
        # Convert BGR to BGRA
        img = cv2.cvtColor(img, cv2.COLOR_BGR2BGRA)

    # Create a mask for the paper. The background is a very dark blue/black.
    # Let's sample a few pixels from the corners to find the background color.
    bg_color_1 = img[10, 10]
    bg_color_2 = img[-10, -10]
    
    # We'll use a threshold to separate dark background from lighter paper.
    # Convert to grayscale for thresholding
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # The background is very dark. Papers are lighter.
    # Let's use Otsu's thresholding or a fixed threshold (e.g. 50 out of 255)
    _, thresh = cv2.threshold(gray, 40, 255, cv2.THRESH_BINARY)
    
    # Use morphological operations to close small gaps in the mask
    kernel = np.ones((5,5), np.uint8)
    mask = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)

    # Find contours
    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Sort contours by area, descending
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    
    # We expect 5 main panels based on the image description:
    # 1. Dreamcatcher (Left Top)
    # 2. Grid (Right Top)
    # 3. Portrait (Left Bottom)
    # 4. Stats (Middle Bottom)
    # 5. Ornaments (Right Bottom)
    
    count = 0
    for i, c in enumerate(contours):
        area = cv2.contourArea(c)
        # Filter out small noise
        if area < 5000: 
            continue
            
        x, y, w, h = cv2.boundingRect(c)
        
        # Add slight padding
        pad = 5
        x1 = max(0, x - pad)
        y1 = max(0, y - pad)
        x2 = min(img.shape[1], x + w + pad)
        y2 = min(img.shape[0], y + h + pad)
        
        # Crop the region
        cropped = img[y1:y2, x1:x2].copy()
        
        # Apply transparency to the background of the cropped region
        # using the threshold mask
        crop_mask = mask[y1:y2, x1:x2]
        
        # Make the fully transparent background
        # Actually, for rough edges, the threshold mask might be too harsh. 
        # Let's try to just make the exact background color transparent with some tolerance.
        # Background is roughly [B, G, R] = [33, 24, 12] or similar dark blue
        # Let's find median background color from the full image mask=0
        
        # Instead of strict masking which might leave jagged edges, 
        # let's just save the bounding boxes first. If the user wants transparent 
        # we can refine it. The "paper cut" style often looks good even if a tiny bit of 
        # dark blue remains.
        
        # Apply alpha mask
        cropped[:, :, 3] = crop_mask
        
        # Determine name based on relative position
        cx, cy = x + w/2, y + h/2
        height, width = img.shape[:2]
        
        name = f"panel_{i}"
        if cy < height / 2: # Top half
            if cx < width / 2: name = "dreamcatcher_panel"
            else: name = "grid_panel"
        else: # Bottom half
            if cx < width / 3: name = "portrait_panel"
            elif cx < width * 2/3: name = "stats_panel"
            else: name = "ornaments_panel"
            
        out_path = os.path.join(output_dir, f"{name}.png")
        cv2.imwrite(out_path, cropped)
        print(f"Saved {name} (Area: {area}, Pos: {x},{y} Size: {w}x{h}) to {out_path}")
        count += 1
        
    print(f"Total panels extracted: {count}")

if __name__ == "__main__":
    process_image(sys.argv[1], sys.argv[2])
