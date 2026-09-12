from pathlib import Path
from PIL import Image, ImageDraw
import xml.etree.ElementTree as ET
import json
import re
import shutil

root = Path(__file__).resolve().parent.parent
assets = root / 'assets/icon'
apple_master = Image.open(assets / 'Apple_Full_Icon.png').convert('RGB')
android_master = Image.open(assets / 'Android_Full_Icon.png').convert('RGB')
assert apple_master.size == (1024, 1024)
assert android_master.size == (512, 512)
assert apple_master.getpixel((0, 0)) == (255, 92, 92)
assert android_master.getpixel((0, 0)) == (255, 92, 92)
catalog = root / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for entry in json.loads((catalog / 'Contents.json').read_text())['images']:
    size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
    target = catalog / entry['filename']
    if size == 1024:
        shutil.copyfile(assets / 'Apple_Full_Icon.png', target)
    else:
        apple_master.resize((size, size), Image.Resampling.LANCZOS).save(target)
for density, size in [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)]:
    android_master.resize((size, size), Image.Resampling.LANCZOS).save(root / f'android/app/src/main/res/mipmap-{density}/ic_launcher.png')
store = root / 'store'
store.mkdir(exist_ok=True)
shutil.copyfile(assets / 'Android_Full_Icon.png', store / 'google-play-icon.png')
apple_master.resize((32, 32), Image.Resampling.LANCZOS).save(root / 'web/favicon.png')
for size in (192, 512):
    apple_master.resize((size, size), Image.Resampling.LANCZOS).save(root / f'web/icons/Icon-{size}.png')
    apple_master.resize((size, size), Image.Resampling.LANCZOS).save(root / f'web/icons/Icon-maskable-{size}.png')

def vector(source, target):
    svg = ET.parse(source).getroot()
    layers = []
    for node in svg:
        tag = node.tag.split('}')[-1]
        if tag == 'path':
            path = node.attrib['d']
        elif tag == 'rect':
            x, y, w, h, r = [float(node.get(key, '0')) for key in ('x', 'y', 'width', 'height', 'rx')]
            path = f'M{x+r},{y} H{x+w-r} A{r},{r} 0 0 1 {x+w},{y+r} V{y+h-r} A{r},{r} 0 0 1 {x+w-r},{y+h} H{x+r} A{r},{r} 0 0 1 {x},{y+h-r} V{y+r} A{r},{r} 0 0 1 {x+r},{y} Z'
        else:
            raise ValueError(tag)
        color = {'white': '#FFFFFF', 'black': '#000000'}.get(node.get('fill'), node.get('fill'))
        item = f'<path android:fillColor="{color}" android:pathData="{path}" />'
        if node.get('transform'):
            angle, px, py = re.findall(r'[-\d.]+', node.get('transform'))
            item = f'<group android:rotation="{angle}" android:pivotX="{px}" android:pivotY="{py}">{item}</group>'
        layers.append(item)
    target.write_text('<?xml version="1.0" encoding="utf-8"?>\n<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">\n<group android:scaleX="0.8" android:scaleY="0.8" android:pivotX="512" android:pivotY="512">\n' + '\n'.join(layers) + '\n</group></vector>\n')

res = root / 'android/app/src/main/res'
vector(assets / 'Android_Adaptive_Foreground_1024.svg', res / 'drawable/sometime_foreground.xml')
vector(assets / 'Android Monochrome_1024.svg', res / 'drawable/sometime_monochrome.xml')
for file in res.glob('values*/colors.xml'):
    file.write_text(
        file.read_text()
        .replace('#ABD1B5', '#FF5C5C')
        .replace('#FC8777', '#FF5C5C')
    )
for name in ('sometime_foreground.png', 'sometime_monochrome.png', 'sometime_background.png'):
    path = res / 'drawable-nodpi' / name
    if path.exists():
        path.unlink()

sheet = Image.new('RGB', (800, 800), 'white')
draw = ImageDraw.Draw(sheet)
for i in range(1, 17):
    image = Image.open(root / f'assets/gradients/image-mesh-gradient({i}).webp').convert('RGB').resize((200, 175))
    x, y = ((i - 1) % 4) * 200, ((i - 1) // 4) * 200
    sheet.paste(image, (x, y))
    draw.text((x + 5, y + 179), str(i), fill='black')
sheet.save(root / '.tools/gradient-contact-sheet.png')
