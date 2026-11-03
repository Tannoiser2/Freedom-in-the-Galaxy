#!/usr/bin/env python3
"""Technical extraction of the six equal cells of each generated sprite sheet."""
import json,subprocess
from PIL import Image
from troop_catalog import ROOT,ENVIRONMENTS
OUT=ROOT/'assets_reborn/truppe'
IMPERIAL=['milizia','pattuglia','linea','veterano','elite_esercito','elite_flotta']
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    jobs=json.loads((ROOT/'reborn/produzione/truppe-illustrazioni.json').read_text())
    for job in jobs:
        if not job['path']:continue
        key=job['key']
        if key=='imperiali-terra':names=['imp_'+v for v in IMPERIAL]
        elif key=='imperiali-orbita':names=['imp_'+v+'_orbita' for v in IMPERIAL]
        elif key=='ribelli-orbita':names=['rib_orbita_'+v for v in ['r10','r21','r23','r43','r44','speciale']]
        else:names=['rib_'+env+'_'+key.split('-')[1] for env in ENVIRONMENTS]
        width,height=map(int,subprocess.check_output(['identify','-format','%w %h',job['path']],text=True).split())
        cw,ch=width//3,height//2
        assert width%3==0 and height%2==0
        for i,name in enumerate(names):
            # A padded bounding box removes only sheet gutters, keeping the full subject.
            with Image.open(job['path']) as sheet:
                alpha=sheet.getchannel('A').crop((i%3*cw,i//3*ch,(i%3+1)*cw,(i//3+1)*ch))
                x0,y0,x1,y1=alpha.point(lambda a:255 if a>128 else 0).getbbox()
            x0=max(0,x0-24);y0=max(0,y0-24);x1=min(cw,x1+24);y1=min(ch,y1+24)
            subprocess.run(['convert',job['path'],'-crop',f'{x1-x0}x{y1-y0}+{i%3*cw+x0}+{i//3*ch+y0}','+repage','-quality','93',str(OUT/(name+'.webp'))],check=True)
    print('Sprite cells exported, without repainting or recoloring')
if __name__=='__main__':main()
