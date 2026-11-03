#!/usr/bin/env python3
"""Compressed runtime copies; production assets remain outside the Godot import tree."""
import subprocess,shutil
from troop_catalog import ROOT,catalog
def main():
    target=ROOT/'assets/reborn/truppe'
    for folder in ['figure','pedine','carte']:(target/folder).mkdir(parents=True,exist_ok=True)
    for name in {c[k] for c in catalog() for k in ['ground','orbit']}:
        shutil.copyfile(ROOT/'assets_reborn/truppe'/name,target/'figure'/name)
    for c in catalog():
        for position in ['terra','orbita']:
            name=f'{c["key"]}-{position}'
            for source,folder,size in [(ROOT/'assets_reborn/truppe/pedine'/(name+'.png'),'pedine','256x256'),(ROOT/'reborn/truppe/png'/(name+'.png'),'carte','860x860')]:
                subprocess.run(['convert',str(source),'-resize',size,'-quality','89',str(target/folder/(name+'.webp'))],check=True)
    print('Runtime: reparti e flotte, 80 pedine e 80 schede truppa compresse')
if __name__=='__main__':main()
