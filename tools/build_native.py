"""Build PokePal's standalone host with Zig 0.13.0 (no installed KOReader).

python tools/build_native.py --zig /path/to/zig --deps /path/to/cache
Use --headless for the host-platform rendering/smoke-test executable.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess

ROOT=Path(__file__).resolve().parents[1]
SOURCES={
 'FBInk':('https://github.com/NiLuJe/FBInk.git','886f25f13368859ad8a899b88d04c26e19cda32e'),
 'lua':('https://github.com/lua/lua.git','6e22fedb74cf0c9b6656e9fce8b7331db847c605'),
}

def run(*args,**kwargs): subprocess.run(list(map(str,args)),check=True,**kwargs)

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--zig',default='zig');p.add_argument('--deps',type=Path,required=True);p.add_argument('--headless',action='store_true')
 args=p.parse_args();deps=args.deps.resolve();deps.mkdir(parents=True,exist_ok=True)
 for name,(url,revision) in SOURCES.items():
  path=deps/name
  if not path.exists():run('git','clone',url,path)
  if (path/'.git').exists():
   actual=subprocess.check_output(['git','rev-parse','HEAD'],cwd=path,text=True).strip()
   if actual!=revision:run('git','checkout',revision,cwd=path)
  else:
   assert (path/'POKEPAL_REVISION.txt').read_text().strip()==revision,'Wrong dependency source revision'
 if (deps/'FBInk/.git').exists():run('git','submodule','update','--init','stb',cwd=deps/'FBInk')
 fb=deps/'FBInk';lua=deps/'lua'
 out=ROOT/'native'/'build';out.mkdir(exist_ok=True)
 binary=out/(('pokepal-headless.exe' if os.name=='nt' else 'pokepal-headless') if args.headless else 'pokepal')
 flags=['-O2','-s','-ffunction-sections','-fdata-sections','-std=gnu11','-Wno-unknown-warning-option','-Wno-unknown-pragmas','-I'+str(lua),'-I'+str(fb),'-I'+str(fb/'stb')]
 source=[ROOT/'native'/'main.c']+[f for f in sorted(lua.glob('*.c')) if f.name not in ('lua.c','luac.c','onelua.c','ltests.c')]
 if args.headless:flags+=['-DHEADLESS']
 else:
  flags+=['-target','arm-linux-musleabi','-mcpu=cortex_a8','-static','-Wl,--gc-sections','-D_GNU_SOURCE','-DLUA_USE_POSIX','-DFBINK_FOR_KINDLE','-DFBINK_MINIMAL','-DFBINK_WITH_DRAW','-DFBINK_WITH_IMAGE','-DFBINK_VERSION="PokePal-886f25f"']
  source += [fb/'fbink.c',fb/'cutef8'/'utf8.c',fb/'cutef8'/'dfa.c',fb/'qimagescale'/'qimagescale.c']
 run(args.zig,'cc',*flags,*source,'-lm','-o',binary)
 stage=out/'extension';stage.mkdir(exist_ok=True)
 shutil.copytree(ROOT/'pokepal.koplugin',stage/'game',dirs_exist_ok=True)
 shutil.copytree(ROOT/'native'/'fonts',stage/'fonts',dirs_exist_ok=True)
 shutil.copytree(ROOT/'native'/'kual',stage,dirs_exist_ok=True)
 shutil.copy2(ROOT/'native'/'runtime.lua',stage/'runtime.lua')
 shutil.copy2(binary,stage/(('pokepal-headless.exe' if os.name=='nt' else 'pokepal-headless') if args.headless else 'pokepal'))
 (stage/'data').mkdir(exist_ok=True)
 print(binary)

if __name__=='__main__':main()
