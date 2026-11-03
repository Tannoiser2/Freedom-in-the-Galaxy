#!/usr/bin/env python3
"""Technical extraction of the six equal cells of each generated sprite sheet."""
import json,subprocess,sys
from pathlib import Path
from PIL import Image
from troop_catalog import ROOT,ENVIRONMENTS
OUT=ROOT/'assets_reborn/truppe'
IMPERIAL=['milizia','pattuglia','linea','veterano','elite_esercito','elite_flotta']
def main():
    OUT.mkdir(parents=True,exist_ok=True)
    jobs=json.loads((Path(sys.argv[1]) if len(sys.argv)>1 else ROOT/'reborn/produzione/truppe-illustrazioni.json').read_text())
    for job in jobs:
        if not job['path']:continue
        key=job['key']
        columns=job.get('columns',1 if job.get('target') else 3);rows=job.get('rows',1 if job.get('target') else 2)
        if job.get('targets'):names=job['targets']
        elif job.get('target'):names=[job['target']]
        elif key.startswith('imperiali-terra'):names=['imp_'+v for v in IMPERIAL]
        elif key.startswith('imperiali-orbita'):names=['imp_'+v+'_orbita' for v in IMPERIAL]
        elif key.startswith('imperiali-speciali'):names=['imp_suicida','imp_suicida_orbita','imp_resolution_orbita','imp_peacemaker_orbita','imp_stabilizzatore_orbita','imp_trasporto_riserva']
        elif key.startswith('ribelli-orbita'):names=['rib_orbita_'+v for v in ['r10','r21','r23','r43','r44','speciale']]
        else:names=['rib_'+env+'_'+key.split('-')[1] for env in ENVIRONMENTS]
        assert len(names)==columns*rows, f'Layout non coerente: {key}'
        width,height=map(int,subprocess.check_output(['identify','-format','%w %h',job['path']],text=True).split())
        cw,ch=width//columns,height//rows
        assert width%columns==0 and height%rows==0
        for i,name in enumerate(names):
            # A padded bounding box removes only sheet gutters, keeping the full subject.
            with Image.open(job['path']) as sheet:
                if job.get('targets'):
                    assert sheet.getchannel('A').getextrema()[0]==0, f'Sfondo non trasparente: {key}'
                alpha=sheet.getchannel('A').crop((i%columns*cw,i//columns*ch,(i%columns+1)*cw,(i//columns+1)*ch))
                x0,y0,x1,y1=alpha.point(lambda a:255 if a>128 else 0).getbbox()
            x0=max(0,x0-24);y0=max(0,y0-24);x1=min(cw,x1+24);y1=min(ch,y1+24)
            subprocess.run(['convert',job['path'],'-crop',f'{x1-x0}x{y1-y0}+{i%columns*cw+x0}+{i//columns*ch+y0}','+repage','-resize','1024x1024>','-quality','93',str(OUT/(name+'.webp'))],check=True)
    print('Sprite cells exported, without repainting or recoloring')
if __name__=='__main__':main()
