"""Import pinned Pokemon data and front-facing action sprites. Build-time only.

Usage: python tools/import_kanto.py /path/to/download-cache
Keeps upstream credits and a SHA-256 for every downloaded sheet.
"""
import concurrent.futures
import csv
import hashlib
import io
import json
from pathlib import Path
import sys
import time
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / 'pokepal.koplugin'
PMD = '4702f10d888d19e804c5986a91170dfc92ae01b8'
DATA = '2bf639e5572812a67d2b94903fdcb9d095f5aeb2'
CACHE = Path(sys.argv[1]).resolve()
CACHE.mkdir(parents=True, exist_ok=True)

def fetch(repo, revision, path):
    url = f'https://raw.githubusercontent.com/{repo}/{revision}/{path}'
    dest = CACHE / repo.replace('/', '-') / revision / path
    if not dest.exists():
        for attempt in range(3):
            try:
                data = urllib.request.urlopen(url, timeout=45).read()
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(data)
                break
            except urllib.error.HTTPError as e:
                if e.code == 404: raise
                if attempt == 2: raise
                time.sleep(attempt + 1)
            except OSError:
                if attempt == 2: raise
                time.sleep(attempt + 1)
    return dest.read_bytes(), url

def table(name):
    data, _ = fetch('PokeAPI/pokeapi', DATA, f'data/v2/csv/{name}.csv')
    return list(csv.DictReader(io.StringIO(data.decode('utf-8'))))

def species_data():
    species = {int(r['id']):r for r in table('pokemon_species') if int(r['id']) <= 160}
    names = {int(r['pokemon_species_id']):r['name'] for r in table('pokemon_species_names') if r['local_language_id']=='9' and int(r['pokemon_species_id']) <= 160}
    names[29]='Nidoran F';names[32]='Nidoran M';names[83]="Farfetch'd"
    types = {r['id']:r['identifier'].title() for r in table('types')}
    by_type = {id:[] for id in species}
    for r in table('pokemon_types'):
        id=int(r['pokemon_id'])
        if id in by_type: by_type[id].append(types[r['type_id']])
    children = {}
    for id,r in species.items():
        if r['evolves_from_species_id']:
            parent=int(r['evolves_from_species_id'])
            if parent in species: children.setdefault(parent,[]).append(id)
    levels = {}
    for r in table('pokemon_evolution'):
        child=int(r['evolved_species_id'])
        if child in species and r['minimum_level'] and r.get('version_group_id') in ('1','3'):
            levels.setdefault(child,int(r['minimum_level']))
    # Preserve the existing game's progression for current players.
    legacy={1:60,2:180,4:300,5:700,7:60,8:180,25:120,133:120,152:300,153:620,155:260,156:700,158:340,159:580}
    rows=['-- Generated from pinned PokeAPI data by tools/import_kanto.py.','return {']
    for id in range(1,161):
        kids=children.get(id,[])
        xp=legacy.get(id,(levels.get(kids[0],20)-1)*20 if kids else 0)
        fields=json.dumps(names[id],ensure_ascii=True)
        if kids: fields+=f',{kids[0]},{xp}'
        fields+=',types='+json.dumps(' / '.join(by_type[id]))
        rows.append(f' [{id}]={{{fields}}},')
    rows.append('}')
    (ROOT/'species.lua').write_text('\n'.join(rows)+'\n',encoding='utf-8')
    return names

def complete_motion(frames, eating=False):
    """Add PokePal motion where an upstream pose is absent or still."""
    result=[]
    for step in range(4):
        source=frames[step%len(frames)]
        box=source.getchannel('A').getbbox()
        body=source.crop(box);w,h=body.size
        squeeze=(0,1,2,1)[step]
        body=body.resize((w,max(1,h-squeeze)),Image.Resampling.NEAREST)
        tile=Image.new('LA',(96,96),(255,0))
        tile.paste(body,(box[0],box[3]-body.height))
        if eating:
            # A berry approaches, then two bite marks appear before the crumbs.
            x=max(4,box[0]-8)+step*2;y=min(78,box[1]+h//2)
            draw=ImageDraw.Draw(tile)
            if step<3:
                draw.rectangle((x+1,y,x+5,y+6),fill=(0,255))
                draw.rectangle((x,y+1,x+6,y+4),fill=(0,255))
                draw.rectangle((x+2,y+1,x+4,y+4),fill=(170,255))
                draw.rectangle((x+3,y-2,x+5,y-1),fill=(85,255))
                if step>=1:draw.rectangle((x+4,y,x+6,y+2),fill=(255,0))
                if step==2:draw.rectangle((x+2,y+3,x+6,y+5),fill=(255,0))
            else:
                draw.point((x,y+5),fill=(0,255));draw.point((x+4,y+8),fill=(85,255))
        result.append(tile)
    assert len({f.tobytes() for f in result})>1
    return result

def import_species(id):
    base=f'sprite/{id:04d}/'
    xml,xml_url=fetch('PMDCollab/SpriteCollab',PMD,base+'AnimData.xml')
    credits,_=fetch('PMDCollab/SpriteCollab',PMD,base+'credits.txt')
    (ROOT/'assets'/'credits').mkdir(exist_ok=True)
    (ROOT/'assets'/'credits'/f'{id:03d}.txt').write_bytes(credits)
    animations={a.findtext('Name'):a for a in ET.fromstring(xml).findall('Anims/Anim')}
    records=[]; poses={}
    for pose in ('Idle','Sleep','Walk','Attack','Eat'):
        missing=pose not in animations
        actual='Idle' if missing and pose=='Eat' else pose
        if actual not in animations: raise ValueError(f'Missing pose {id} {pose}')
        visited=set()
        while animations[actual].findtext('CopyOf'):
            if actual in visited: raise ValueError(f'Animation alias cycle {id} {pose}')
            visited.add(actual);actual=animations[actual].findtext('CopyOf')
        a=animations[actual]
        data,url=fetch('PMDCollab/SpriteCollab',PMD,base+actual+'-Anim.png')
        sheet=Image.open(io.BytesIO(data)).convert('RGBA')
        w,h=int(a.findtext('FrameWidth')),int(a.findtext('FrameHeight'))
        assert sheet.width%w==0 and sheet.height%h==0
        count=sheet.width//w
        frames=[sheet.crop((i*w,0,(i+1)*w,h)) for i in range(count)]
        mask=Image.new('L',(w,h))
        for fr in frames: mask=ImageChops.lighter(mask,fr.getchannel('A'))
        box=mask.getbbox()
        if not box: raise ValueError(f'Empty animation {id} {pose}')
        bw,bh=box[2]-box[0],box[3]-box[1]
        scale=80/max(bw,bh);size=(max(1,round(bw*scale)),max(1,round(bh*scale)))
        selected=list(range(count)) if count<=4 else [round(i*(count-1)/3) for i in range(4)]
        converted=[]
        for index in selected:
            fr=frames[index].crop(box).resize(size,Image.Resampling.NEAREST)
            gray=fr.convert('L').point(lambda v:min(255,((v+42)//85)*85))
            tile=Image.new('LA',(96,96),(255,0))
            tile.paste(Image.merge('LA',(gray,fr.getchannel('A'))),((96-size[0])//2,90-size[1]))
            converted.append(tile)
        generated=None
        if missing:
            converted=complete_motion(converted,eating=True)
            generated='PokePal eating motion and berry, derived from Idle'
        elif len({x.tobytes() for x in converted})==1:
            converted=complete_motion(converted)
            generated='PokePal breathing motion, derived from a still source pose'
        motion=len({x.tobytes() for x in converted})>1
        for frame,tile in enumerate(converted,1):
            tile.save(ROOT/'assets'/f'{id}-{pose.lower()}-{frame}.png',optimize=True)
            if pose=='Idle': tile.save(ROOT/'assets'/f'{id}-{frame}.png',optimize=True)
        poses[pose.lower()]=len(converted)
        records.append({'species':id,'pose':pose,'sheet_pose':actual,'source':url,'source_sha256':hashlib.sha256(data).hexdigest(),'metadata':xml_url,'frames':selected,'original_frames':count,'count':len(converted),'motion':motion,'generated':generated,'direction':'front','credits':f'credits/{id:03d}.txt'})
    if not all(p in poses for p in ('idle','sleep','walk','attack','eat')): raise ValueError(f'Missing poses {id}: {poses}')
    return id,poses,records

if __name__=='__main__':
    species_data()
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        for result in pool.map(import_species,range(1,161)):
            results.append(result)
            if result[0]%10==0: print(f'Imported {result[0]}/160',flush=True)
    rows=['return {'];normal=['return {'];records=[];sources=[]
    for id,poses,items in results:
        rows.append(f' [{id}]={{'+','.join(f'{p}={n}' for p,n in poses.items())+'},')
        normal.append(f' [{id}]={poses["idle"]},');records+=items
        item=next(i for i in items if i['pose']=='Idle')
        sources.append({'id':id,'source':item['source'],'source_sha256':item['source_sha256'],'original_frames':item['original_frames'],'sampled':item['frames'],'count':item['count'],'generated':item['generated']})
    (ROOT/'assets'/'poses.lua').write_text('\n'.join(rows+['}'])+'\n')
    (ROOT/'assets'/'frames.lua').write_text('\n'.join(normal+['}'])+'\n')
    (ROOT/'assets'/'pose-sources.json').write_text(json.dumps(records,indent=2)+'\n')
    (ROOT/'assets'/'sources.json').write_text(json.dumps(sources,indent=2)+'\n')
    for path in ('credit_names.txt','LICENSE.md'):
        data,_=fetch('PMDCollab/SpriteCollab',PMD,path)
        (ROOT/('SPRITE-PMDCollab-'+path)).write_bytes(data)
    print(f'{len(results)} species; {len(records)} action poses; {sum(i["count"] for i in records)} frames')
    from pack_sprites import pack
    pack()
    for frame in (ROOT/'assets').glob('*.png'):
        frame.unlink()
