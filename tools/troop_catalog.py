"""Presentation metadata derived from the game's military units, never new rules."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
ENVIRONMENTS=['urbano','sotterraneo','selvaggio','liquido','aereo','fuoco']
REBEL_CLASSES={'r10':'Milizia','r21':'Linea leggera','r23':'Linea','r43':'Veterana','r44':'Élite'}
IMPERIAL_ART={'milizia':'milizia','pattuglia':'pattuglia','linea':'linea','veterano':'veterano','elite_esercito':'elite_esercito','elite_flotta':'elite_flotta','suicida':'pattuglia','resolution':'elite_flotta','peacemaker':'elite_flotta','stabilizzatore':'elite_flotta'}
def catalog():
    rules=json.loads((ROOT/'data/regole_avanzate.json').read_text())['unita']
    records=[]
    for cat,d in rules.items():
        for env in ENVIRONMENTS if d['fz']==0 else ['tutti']:
            key=(f'rib_{env}_{d["ped"]}' if d['fz']==0 else d['ped'])
            if d['fz']==0:
                ground_class='milizia' if cat=='r10' else 'elite' if cat=='r44' else 'linea'
                ground=f'rib_{env}_{ground_class}'
                space=f'rib_orbita_{cat}'
                title=REBEL_CLASSES[cat];faction='ribelli'
            else:
                ground='imp_'+IMPERIAL_ART[cat];space=ground+'_orbita'
                title=d['nome'];faction='imperiali'
            # The three strategic vessels have no ground combat component.
            if d['f']==0:ground=space
            records.append(dict(key=key,cat=cat,environ=env,fazione=faction,nome=title,
                terra=d['f'],spazio=d['s'],elite=d.get('elite',False),mobile=d['mobile'],
                costo=d['costo'],ground=ground+'.webp',orbit=space+'.webp',rules=d))
    return records
