"""Import Crystal maps through Violet City. Usage: python tools/import_story.py /path/to/pokecrystal"""
from pathlib import Path
from collections import Counter
import hashlib, io, json, re, subprocess, sys
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'pokepal.koplugin'
SOURCE = Path(sys.argv[1])
PIN = '5c877ef55197039c9676e8e3eec6d254b1c40fe8'
assert subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=SOURCE, text=True).strip() == PIN
OUT = ROOT / 'assets/story'
OUT.mkdir(parents=True, exist_ok=True)
hashes, images, tile_ids, maps, collisions = {}, {}, {}, {}, Counter()
names = ['PlayersHouse2F', 'PlayersHouse1F', 'NewBarkTown', 'ElmsLab', 'Route29',
         'CherrygroveCity', 'CherrygrovePokecenter1F', 'Route30', 'MrPokemonsHouse',
         'Route31','Route31VioletGate','VioletCity','VioletPokecenter1F','VioletGym',
         'SproutTower1F','SproutTower2F','SproutTower3F']

def read(path):
    data = subprocess.check_output(['git', 'show', f'{PIN}:{path}'], cwd=SOURCE)
    hashes[path] = hashlib.sha256(data).hexdigest()
    return data

def text(path):
    return read(path).decode('utf8')

def lua(value):
    if isinstance(value, str): return json.dumps(value, ensure_ascii=False)
    if isinstance(value, int): return str(value)
    if isinstance(value, list): return '{' + ','.join(lua(v) for v in value) + '}'
    return '{' + ','.join('['+lua(k)+']='+lua(v) for k,v in value.items()) + '}'

def add(name, im):
    stream = io.BytesIO()
    im.save(stream, format='PNG', optimize=True)
    images[name+'.png'] = stream.getvalue()

sizes = {k:(int(w)*2,int(h)*2) for k,w,h in re.findall(r'^\s*map_const\s+(\w+),\s*(\d+),\s*(\d+)', text('constants/map_constants.asm'), re.M)}
attrs = text('data/maps/attributes.asm')
constants = dict(re.findall(r'^\s*map_attributes\s+(\w+),\s*(\w+),', attrs, re.M))
tilesets = dict(re.findall(r'^\s*map\s+(\w+), TILESET_(\w+),', text('data/maps/maps.asm'), re.M))
blocks = text('data/maps/blocks.asm')
passable = {'FLOOR','TALL_GRASS','DOOR','CAVE','LADDER','STAIRCASE','WARP_CARPET_DOWN','WARP_CARPET_UP','WARP_CARPET_LEFT','WARP_CARPET_RIGHT'}
for name in names:
    width,height = sizes[constants[name]]
    tileset = tilesets[name].lower()
    sheet = Image.open(io.BytesIO(read(f'gfx/tilesets/{tileset}.png'))).convert('L')
    meta = read(f'data/tilesets/{tileset}_metatiles.bin')
    coll = [tuple(x.strip() for x in row.split(',')) for row in re.findall(r'^\s*tilecoll ([^;\n]+)', text(f'data/tilesets/{tileset}_collision.asm'), re.M)]
    blockpath = re.search(r'^'+name+r'_Blocks:.*?INCBIN "([^"]+)"', blocks, re.M|re.S).group(1)
    layout = read(blockpath)
    assert len(layout) == width*height//4
    tiles, walk = [], []
    for y in range(height):
        row=[]
        for x in range(width):
            block=layout[(y//2)*(width//2)+x//2]; quadrant=(y%2)*2+x%2
            kind=coll[block][quadrant];collisions[kind]+=1
            row.append('.' if kind in passable else {'COUNTER':'C','UP_WALL':'U','HOP_DOWN':'D','HOP_LEFT':'L','HOP_RIGHT':'R','HOP_DOWN_RIGHT':'b','HOP_DOWN_LEFT':'c'}.get(kind,'#'))
            im=Image.new('L',(16,16),255)
            for dy in range(2):
                for dx in range(2):
                    tile=meta[block*16+(y%2*2+dy)*4+x%2*2+dx]
                    if tile>=128:tile-=32
                    tx,ty=tile%16*8,tile//16*8
                    assert ty+8<=sheet.height
                    im.paste(sheet.crop((tx,ty,tx+8,ty+8)),(dx*8,dy*8))
            key=im.tobytes()
            if key not in tile_ids:
                tile_ids[key]=len(tile_ids)+1;add('tile-'+str(tile_ids[key]),im)
            tiles.append(tile_ids[key])
        walk.append(''.join(row))
    script=text('maps/'+name+'.asm')
    warps=[[int(x),int(y),dest,int(index)] for x,y,dest,index in re.findall(r'^\s*warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)',script,re.M)]
    section=re.search(r'^\s*map_attributes '+name+r',.*?(?=^\s*map_attributes|\Z)',attrs,re.M|re.S).group()
    links=[[d,target,int(offset)] for d,target,offset in re.findall(r'connection (\w+), (\w+), \w+, (-?\d+)',section)]
    title={'PlayersHouse2F':'Your room','PlayersHouse1F':'Home','ElmsLab':"Professor Elm's lab",'CherrygrovePokecenter1F':'Pokemon Centre','MrPokemonsHouse':"Mr. Pokemon's house",'VioletPokecenter1F':'Violet Pokemon Centre','Route31VioletGate':'Violet City gate','SproutTower1F':'Sprout Tower / 1F','SproutTower2F':'Sprout Tower / 2F','SproutTower3F':'Sprout Tower / 3F'}.get(name,re.sub(r'([a-z])([A-Z0-9])',r'\1 \2',name))
    maps[name]={'name':title,'width':width,'height':height,'tiles':tiles,'walk':walk,'warps':warps,'links':links}

# Keep source character art separate from the existing Fern Town packs.
for name in ('chris','mom','elm','oak','rival','gentleman','gramps','nurse','teacher','sage','falkner','youngster','bug_catcher','gym_guide','officer'):
    sheet=Image.open(io.BytesIO(read(f'gfx/sprites/{name}.png'))).convert('RGBA')
    for direction,row in [('down',0),('up',1),('left',2),('right',2)]:
        im=sheet.crop((0,row*16,16,row*16+16))
        # Keep enclosed white eyes and clothes, as in the existing classic importer.
        for x in range(16):
            for y in (0,15):
                if im.getpixel((x,y))==(255,255,255,255):ImageDraw.floodfill(im,(x,y),(255,255,255,0))
        for y in range(16):
            for x in (0,15):
                if im.getpixel((x,y))==(255,255,255,255):ImageDraw.floodfill(im,(x,y),(255,255,255,0))
        if direction=='right':im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        add(name+'-'+direction,im)

index,blob={},bytearray()
for name,data in sorted(images.items()):
    index[name]=[1,len(blob),len(data)];blob.extend(data)
(OUT/'001.bin').write_bytes(blob)
reader=(ROOT/'assets/sprites.lua').read_text(encoding='utf8').split('function S.read',1)[1]
(OUT/'sprites.lua').write_text('local S={index='+lua(index)+'}\nfunction S.read'+reader,encoding='utf8')
species={name:i+1 for i,name in enumerate(re.findall(r'^\s*const\s+(\w+)',text('constants/pokemon_constants.asm'),re.M))}
parties=text('data/trainers/parties.asm');teams={}
for trainer in ('JOEY','MIKEY','DON','WADE','CHOW','NICO','EDMOND','JIN','TROY','NEAL','LI','ABE','ROD','FALKNER'):
    party=re.search(r'db "'+trainer+r'@",[^\n]+\n(.*?)db -1',parties,re.S).group(1)
    teams[trainer.lower()]=[species[name] for name in re.findall(r'^\s*db\s+\d+,\s*(\w+)',party,re.M)]
    assert 1<=len(teams[trainer.lower()])<=6
(ROOT/'story_maps.lua').write_text('-- Generated by tools/import_story.py; coordinates are zero-based.\nreturn '+lua({'maps':maps,'constants':{constants[n]:n for n in names},'teams':teams})+'\n',encoding='utf8')
(OUT/'index.json').write_text(json.dumps(index,sort_keys=True)+'\n',encoding='utf8')
(OUT/'sources.json').write_text(json.dumps({'crystal':PIN,'sha256':hashes,'collision_counts':dict(collisions)},indent=2)+'\n',encoding='utf8')
assert len(maps)==17 and all(len(m['tiles'])==m['width']*m['height'] for m in maps.values())
print(json.dumps({'maps':len(maps),'images':len(images),'bytes':len(blob),'collisions':dict(collisions)},indent=2))
