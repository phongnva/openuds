from PIL import Image, ImageChops

def trim(im):
    # Try to trim based on the corner pixel color
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im

def process():
    try:
        img = Image.open('d:/PhongNVA/OpenUDSv4.0/openuds/logo-fpt/fpt-logo.png').convert('RGBA')
        img = trim(img)
        
        # Save high quality versions
        # For the loading screen, we want it crisp and not too large
        small = img.copy()
        small.thumbnail((120, 60), Image.Resampling.LANCZOS)
        small.save('images/logo-uds-small.png')
        
        big = img.copy()
        big.thumbnail((512, 512), Image.Resampling.LANCZOS)
        big.save('images/logo-uds.png')
        big.save('images/logo-512.png')
        
        print(f"Processed. Small size: {small.size}, Big size: {big.size}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    process()
