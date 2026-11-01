"""Import Crystal maps through Goldenrod City. Usage: python tools/import_story.py /path/to/pokecrystal"""
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
         'SproutTower1F','SproutTower2F','SproutTower3F','Route32','Route32Pokecenter1F',
         'UnionCave1F','Route33','AzaleaTown','KurtsHouse','SlowpokeWellB1F',
         'AzaleaPokecenter1F','AzaleaGym','IlexForestAzaleaGate','IlexForest',
         'Route34IlexForestGate','Route34','GoldenrodCity','GoldenrodPokecenter1F','GoldenrodGym','RadioTower1F']

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
cut_blocks=text('data/collision/field_move_blocks.asm').split('.forest:',1)[1].split('db -1',1)[0]
cut_from,cut_to=[int(n,16) for n in re.search(r'db \$(\w+), \$(\w+), 0',cut_blocks).groups()]
for name in names:
    width,height = sizes[constants[name]]
    tileset = tilesets[name].lower()
    sheet = Image.open(io.BytesIO(read(f'gfx/tilesets/{tileset}.png'))).convert('L')
    meta = read(f'data/tilesets/{tileset}_metatiles.bin')
    coll = [tuple(x.strip() for x in row.split(',')) for row in re.findall(r'^\s*tilecoll ([^;\n]+)', text(f'data/tilesets/{tileset}_collision.asm'), re.M)]
    blockpath = re.search(r'^'+name+r'_Blocks:.*?INCBIN "([^"]+)"', blocks, re.M|re.S).group(1)
    layout = read(blockpath)
    assert len(layout) == width*height//4
    def tile_id(block,x,y):
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
        return tile_ids[key]
    tiles, walk, cleared = [], [], {}
    for y in range(height):
        row=[]
        for x in range(width):
            block=layout[(y//2)*(width//2)+x//2]; quadrant=(y%2)*2+x%2
            kind=coll[block][quadrant];collisions[kind]+=1
            row.append('G' if kind=='TALL_GRASS' else 'T' if kind=='CUT_TREE' and name=='IlexForest' else '.' if kind in passable else {'COUNTER':'C','UP_WALL':'U','HOP_DOWN':'D','HOP_LEFT':'L','HOP_RIGHT':'R','HOP_DOWN_RIGHT':'b','HOP_DOWN_LEFT':'c'}.get(kind,'#'))
            tiles.append(tile_id(block,x,y))
            if name=='IlexForest' and block==cut_from:
                cleared[y*width+x+1]=tile_id(cut_to,x,y)
        walk.append(''.join(row))
    script=text('maps/'+name+'.asm')
    warps=[[int(x),int(y),dest,int(index)] for x,y,dest,index in re.findall(r'^\s*warp_event\s+(\d+),\s*(\d+),\s*(\w+),\s*(\d+)',script,re.M)]
    section=re.search(r'^\s*map_attributes '+name+r',.*?(?=^\s*map_attributes|\Z)',attrs,re.M|re.S).group()
    links=[[d,target,int(offset)] for d,target,offset in re.findall(r'connection (\w+), (\w+), \w+, (-?\d+)',section)]
    title={'PlayersHouse2F':'Your room','PlayersHouse1F':'Home','ElmsLab':"Professor Elm's lab",'CherrygrovePokecenter1F':'Pokemon Centre','MrPokemonsHouse':"Mr. Pokemon's house",'VioletPokecenter1F':'Violet Pokemon Centre','Route31VioletGate':'Violet City gate','SproutTower1F':'Sprout Tower / 1F','SproutTower2F':'Sprout Tower / 2F','SproutTower3F':'Sprout Tower / 3F'}.get(name,re.sub(r'([a-z])([A-Z0-9])',r'\1 \2',name))
    title={'Route32Pokecenter1F':'Route 32 Pokemon Centre','UnionCave1F':'Union Cave / 1F',
           'KurtsHouse':"Kurt's house",'SlowpokeWellB1F':'Slowpoke Well / B1F',
           'AzaleaPokecenter1F':'Azalea Pokemon Centre','IlexForestAzaleaGate':'Ilex Forest gate',
           'Route34IlexForestGate':'Route 34 forest gate','GoldenrodPokecenter1F':'Goldenrod Pokemon Centre',
           'RadioTower1F':'Radio Tower / 1F'}.get(name,title)
    maps[name]={'name':title,'width':width,'height':height,'tiles':tiles,'walk':walk,'warps':warps,'links':links}
    if cleared:
        assert sum(row.count('T') for row in walk)==1 and len(cleared)==4
        maps[name]['cleared']=cleared

# Keep source character art separate from the existing Fern Town packs.
for name in ('chris','mom','elm','oak','rival','gentleman','gramps','nurse','teacher','sage','falkner','youngster','bug_catcher','gym_guide','officer',
             'scientist','fisher','lass','pokefan_m','super_nerd','rocket','rocket_girl','kurt','slowpoke','bugsy','twin',
             'bird','black_belt','whitney','beauty','cooltrainer_f','receptionist'):
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
for trainer in ('JOEY','MIKEY','DON','WADE','CHOW','NICO','EDMOND','JIN','TROY','NEAL','LI','ABE','ROD','FALKNER',
                'ROLAND','JUSTIN','RALPH','HENRY','LIZ','ALBERT','GORDON','PETER','LARRY','RUSSELL','DANIEL','BILL','RAY','BENNY','AL','JOSH','BUGSY',
                'WAYNE','TODD','SAMUEL','IAN','GINA','BRANDON','KEITH','CARRIE','BRIDGET','VICTORIA','SAMANTHA','WHITNEY'):
    party=re.search(r'db "'+trainer+r'@",[^\n]+\n(.*?)db -1',parties,re.S).group(1)
    teams[trainer.lower()]=[species[name] for name in re.findall(r'^\s*db\s+\d+,\s*(\w+)',party,re.M)]
    assert 1<=len(teams[trainer.lower()])<=6
def numbered_team(group,number):
    party=re.search(r'; '+group+r' \('+str(number)+r'\)\s*\n(.*?)db -1',parties,re.S).group(1)
    return [species[name] for name in re.findall(r'^\s*db\s+\d+,\s*(\w+)',party,re.M)]
for key,group,number in [('anthony','HIKER',5),('amy','TWINS',1),('may','TWINS',4),
                         ('rocket29','GRUNTM',29),('rocket1','GRUNTM',1),('rocket2','GRUNTM',2),('rocketf1','GRUNTF',1)]:
    teams[key]=numbered_team(group,number)
rivals={id:numbered_team('RIVAL1',n) for id,n in [(152,4),(155,5),(158,6)]}
teams['azalea_rival']=rivals[155]
wild={};catch_rates={};grass=text('data/wild/johto_grass.asm')
for name in names:
    match=re.search(r'def_grass_wildmons '+constants[name]+r'\s*\n(.*?)end_grass_wildmons',grass,re.S)
    if not match:continue
    section=match.group(1);rates=[int(n) for n in re.findall(r'(\d+) percent',section)]
    entries=re.findall(r'^\s*db\s+\d+,\s*(\w+)',section,re.M)
    assert len(rates)==3 and len(entries)==21
    wild[name]={'terrain':'grass' if name.startswith('Route') else 'floor','rates':rates,'mons':[[species[n] for n in entries[i:i+7]] for i in (0,7,14)]}
    for mon in entries:
        if species[mon] not in catch_rates:
            base=text('data/pokemon/base_stats/'+mon.lower()+'.asm')
            catch_rates[species[mon]]=int(re.search(r'db\s+(\d+)\s*; catch rate',base).group(1))
assert len(wild)==11
probabilities=text('data/wild/probabilities.asm').split('WaterMonProbTable:',1)[0]
wild_slots=[int(n) for n in re.findall(r'mon_prob\s+(\d+),',probabilities)]
assert len(wild_slots)==7 and wild_slots[-1]==100
(ROOT/'story_maps.lua').write_text('-- Generated by tools/import_story.py; coordinates are zero-based.\nreturn '+lua({'maps':maps,'constants':{constants[n]:n for n in names},'teams':teams,'rivals':rivals,'wild':wild,'wild_slots':wild_slots,'catch_rates':catch_rates})+'\n',encoding='utf8')
(OUT/'index.json').write_text(json.dumps(index,sort_keys=True)+'\n',encoding='utf8')
(OUT/'sources.json').write_text(json.dumps({'crystal':PIN,'sha256':hashes,'collision_counts':dict(collisions)},indent=2)+'\n',encoding='utf8')
assert len(maps)==34 and all(len(m['tiles'])==m['width']*m['height'] for m in maps.values())
print(json.dumps({'maps':len(maps),'images':len(images),'bytes':len(blob),'collisions':dict(collisions)},indent=2))
