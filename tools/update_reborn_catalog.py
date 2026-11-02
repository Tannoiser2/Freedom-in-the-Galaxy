#!/usr/bin/env python3
"""Refresh the REBORN manifest, character sheets and production report."""

import json
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/"assets_reborn"
REBORN=ROOT/"reborn"


def image_info(path: Path) -> dict:
    try:
        with Image.open(path) as im: size=f"{im.width}x{im.height}"
    except Exception: size=None
    return {"file":str(path.relative_to(ROOT)),"categoria":path.parent.name,"dimensioni":size,"stato":"generato"}


def main() -> None:
    # Preserve reviews and provenance: a catalog refresh must never erase approval.
    old_path=REBORN/"manifest.json"
    old={e['file']:e for e in json.loads(old_path.read_text())} if old_path.exists() else {}
    extra_path=REBORN/"produzione"/"metadati_nuovi_asset.json"
    extra=json.loads(extra_path.read_text()) if extra_path.exists() else {}
    entries=[]
    for p in sorted(ASSETS.rglob("*")):
        if p.suffix.lower() not in {".png",".jpg",".webp"}: continue
        info=image_info(p)
        entry={**old.get(info['file'],{}),**info}
        entry.update(extra.get(info['file'],{}))
        previous=old.get(info['file'],{}).get('stato')
        entry['stato']=previous if previous in {'approvato','da_rifare','da_approvare'} else 'da_approvare'
        if p.parent.name=='pianeti':
            entry.update(originale='data/galassia.json',scheda='reborn/schede/pianeti_pesati.md')
        entries.append(entry)
    (REBORN/"manifest.json").write_text(json.dumps(entries,ensure_ascii=False,indent=2)+"\n")
    cards=json.loads((ROOT/"data"/"carte.json").read_text())
    sheets=REBORN/"schede"; sheets.mkdir(parents=True,exist_ok=True)
    for p in cards["personaggi"]:
        key="pg_"+p["nome"].lower().replace("doctor ","doctor_").replace("professor ","prof_").replace("senator ","").replace("emperor ","").replace("-","_").replace(" ","_")
        key={"pg_senator_dermond":"pg_dermond","pg_emperor_coreguya":"pg_coreguya"}.get(key,key)
        stats=f"{p['combattimento']}/{p['resistenza']}/{p['intelligenza']}/{p['comando']}/{p['diplomazia']}/{p['navigazione']}"
        text=f"# {p['nome']}\n\n- Fazione: {p['fazione']}\n- Razza: {p['razza_en']}\n- Titolo: {p.get('titolo_it') or '—'}\n- Pianeti natali: {', '.join(p.get('pianeti_natali') or []) or '—'}\n- Statistiche C/R/I/L/D/N: {stats}\n- Abilità: {p.get('speciale_it') or '—'}\n- Figure master: `assets_reborn/figure_intere/{key}.png`\n- Ritratto: `assets_reborn/ritratti/{key}.png`\n- Pedina: `assets_reborn/pedine/{key}.png`\n- Meshy: `assets_reborn/meshy/{key}.png`\n"
        # Existing visual descriptions and prompts belong to the author.
        if not (sheets/f"{key}.md").exists():
            (sheets/f"{key}.md").write_text(text)
    counts={d.name:len([p for p in d.rglob("*") if p.suffix.lower() in {'.png','.jpg','.webp'}]) for d in ASSETS.iterdir() if d.is_dir()}
    report="# Freedom in the Galaxy — REBORN: catalogo grafico\n\n"
    report+="Pacchetto autonomo di produzione grafica. Le carte definitive restano volutamente fuori da questa fase.\n\n"
    report+="## Inventario\n\n"+"\n".join(f"- `{k}`: {v} file" for k,v in sorted(counts.items()))
    report+="\n\n## Anteprime di controllo\n\n- `reborn/anteprime/inventario_personaggi.png`\n- `reborn/anteprime/inventario_pianeti.png`\n- `reborn/anteprime/inventario_astronavi.png`\n- `reborn/anteprime/inventario_segreti.png`\n"
    # Keep the authored progress and limitations report; emit counts separately.
    (REBORN/"inventario_generato.md").write_text(report)
    print(f"Catalogued {len(entries)} images and {len(cards['personaggi'])} characters")


if __name__=="__main__": main()
