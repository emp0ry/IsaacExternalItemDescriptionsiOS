#!/usr/bin/env python3
"""Copy attributed bitmap fonts and preserve original EID render metadata."""
from pathlib import Path
import json
import re
import shutil
import sys
import subprocess
import xml.etree.ElementTree as ET
from eid_context import table

def main():
    source, output = map(Path, sys.argv[1:])
    font_output = output / 'fonts'
    font_output.mkdir(parents=True, exist_ok=True)
    for file in (source / 'resources/font').glob('eid_*'):
        if file.suffix in ('.fnt', '.png'):
            shutil.copy2(file, font_output / file.name)
    text = (source / 'features/eid_data.lua').read_text(encoding='utf-8-sig')
    icons = json.loads((output / 'eid_inline_icons.json').read_text())
    pattern = r'^\s*\["([^"]+)"\]\s*=\s*\{\s*"([^"]+)"\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\d+)([^}\r\n]*)'
    for token, animation, frame, width, height, tail in re.findall(pattern, text, re.M):
        offsets = re.findall(r'^\s*,\s*(-?\d+)(?:\s*,\s*(-?\d+))?', tail)
        x, y = offsets[0] if offsets else ('-1', '0')
        icons[token] = dict(animation=animation, frame=int(frame), width=int(width), height=int(height),
                            x=int(x), y=int(y or 0), sheet='players' if 'EID.PlayerSprite' in tail else
                            'transform' if 'EID.IconSprite' in tail else 'inline')
    for token in ('Damage', 'Speed', 'Tears', 'Range', 'Shotspeed', 'Luck', 'AngelChance', 'DevilChance', 'Tearsize'):
        if token + 'REP' in icons:
            icons[token] = dict(icons[token + 'REP'])
    shortcuts = [pair for pair in table(text, 'TextReplacementPairs').values()
                 if isinstance(pair, list) and len(pair) == 2 and all(isinstance(part, str) for part in pair)]
    # Original's configurable keyboard/controller shortcut has no Lua callback
    # inside iOS. Its documented fallback is the Select button icon.
    shortcuts.append(['{{CONFIG_BoC_Toggle}}', '{{ButtonSelect}}'])
    # Reviewed upstream translation typos: preserve the prose, normalize only
    # invalid icon names to the corresponding canonical EID atlas tokens.
    compatibility_aliases = {'Verwirrung':'Confusion', 'Magnetisieren':'Magnetize',
        'Brennen':'Burning', 'Furcht':'Fear', 'Vergiftung':'Poison',
        'HeiligerMantel':'HolyMantle', 'Bom':'Bomb',
        'Blood Donation Machine':'BloodDonationMachine', 'WhitePoop':'HolyPoop'}
    for alias, canonical in compatibility_aliases.items():
        if canonical not in icons:
            raise ValueError('Missing canonical EID icon: ' + canonical)
        shortcuts.append(['{{' + alias + '}}', '{{' + canonical + '}}'])
    colors = {}
    for name, values in re.findall(r'\["([^"\n]+)"\]\s*=\s*KColor\(([^)]+)\)', text):
        try:
            colors[name] = [float(v.strip()) for v in values.split(',')]
        except ValueError:
            continue
    animations = {}
    for kind, filename in (('inline', 'eid_inline_icons'), ('transform', 'eid_transform_icons'),
                           ('pocket', 'eid_cardspills'), ('players', 'eid_player_icons')):
        for extension in ('.png', '.anm2'):
            shutil.copy2(source / 'resources/gfx' / (filename + extension), output / (filename + extension))
        tree = ET.parse(source / 'resources/gfx' / (filename + '.anm2'))
        definitions = {}
        for animation in tree.findall('./Animations/Animation'):
            layers = {}
            for layer in animation.findall('./LayerAnimations/LayerAnimation'):
                layers[layer.attrib['LayerId']] = [dict(f.attrib) for f in layer.findall('Frame')]
            definitions[animation.attrib['Name']] = dict(layers=layers, root=[dict(f.attrib) for f in animation.findall('./RootAnimation/Frame')])
        animations[kind] = dict(file=filename + '.png', definitions=definitions)
    languages = {}
    for path in (source / 'descriptions/ab+').glob('*.lua'):
        content = path.read_text(encoding='utf-8-sig')
        code = re.search(r'local\s+languageCode\s*=\s*"([^"]+)"', content)
        if not code:
            continue
        match = re.search(r'\.fonts\s*=\s*\{\s*\{([^}]+)\}', content)
        row = dict(font='default', line_height=11, width=130)
        if match:
            entry = match.group(1)
            name = re.search(r'name\s*=\s*"([^"]+)"', entry)
            if name:
                row['font'] = name.group(1)
            for field, key in (('lineHeight', 'line_height'), ('textboxWidth', 'width')):
                value = re.search(field + r'\s*=\s*(\d+)', entry)
                if value:
                    row[key] = int(value.group(1))
        languages[code.group(1)] = row
    commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    result = dict(source_commit=commit, icons=icons, colors=colors, shortcuts=shortcuts,
                  compatibility_aliases=compatibility_aliases,
                  animations=animations, languages=languages)
    (output / 'original-renderer.json').write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')))
    print('Original renderer: bitmap fonts, glyph metrics, ANM2 geometry, icon advances, colors and language defaults staged')

if __name__ == '__main__':
    main()
