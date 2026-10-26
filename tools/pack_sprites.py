"""Pack PNG frames by species, preserving their bytes and a checked index."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'pokepal.koplugin/assets'

def pack():
    index={};lines=['local S={index={']
    species_ids=sorted({int(p.name.split('-')[0]) for p in ROOT.glob('*-*.png')})
    assert species_ids and species_ids==list(range(1,max(species_ids)+1)), 'Incomplete species roster'
    for species in species_ids:
        frames=sorted(ROOT.glob(f'{species}-*.png'))
        assert frames,f'Missing frames for {species}'
        data=bytearray();offsets={}
        for frame in frames:
            content=frame.read_bytes()
            if content not in offsets:
                offsets[content]=len(data);data.extend(content)
            offset=offsets[content]
            index[frame.name]=[species,offset,len(content)]
            lines.append(f' ["{frame.name}"]={{{species},{offset},{len(content)}}},')
        path=ROOT/f'{species:03d}.bin';path.write_bytes(data)
        for frame in frames:
            _,offset,size=index[frame.name]
            assert data[offset:offset+size]==frame.read_bytes()
    lines+=['}}', '''function S.read(directory,name)
 local r=assert(S.index[name],"Unknown sprite: "..name)
 local f=assert(io.open(directory..string.format("/%03d.bin",r[1]),"rb"))
 assert(f:seek("set",r[2]));local data=f:read(r[3]);f:close()
 assert(data and #data==r[3],"Truncated sprite pack: "..name)
 return data
end
return S''']
    (ROOT/'sprites.lua').write_text('\n'.join(lines)+'\n')
    (ROOT/'sprite-index.json').write_text(json.dumps(index,sort_keys=True,separators=(',',':'))+'\n')
    print(f'Packed {len(index)} PNG frames into {len(species_ids)} species files (byte-for-byte checked).')

if __name__=='__main__':pack()
