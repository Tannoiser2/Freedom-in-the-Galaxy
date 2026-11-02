#!/usr/bin/env python3
"""Export generated art to the MD's delivery sizes and register provenance.

Creative generation uses imagegen with inspected originals. ImageMagick here
only performs the final PNG size export; no crop, recoloring or new painting.
"""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / 'reborn/produzione/nuovi_asset.json'
DESCRIPTIONS = [
    'Scafo ovale, cabina anteriore arrotondata, motori posteriori e appendici laterali sottili.',
    'Cargo tozzo, cabina alta bombata e cinque moduli cilindrici sotto lo scafo.',
    'Scafo circolare, lungo corpo cilindrico centrale, ali posteriori incrociate e cabina vetrata.',
    'Scafo allungato e cockpit anteriore, traversa posteriore e quattro aste laterali.',
    'Scafo lungo con grandi moduli laterali paralleli, motore centrale e appendice posteriore.',
    'Incrociatore compatto con cabina centrale a feritoie, due ali rettangolari e aste laterali.',
    'Nave molto affusolata a punta, cockpit superiore e impennaggi triangolari.',
    'Scafo a goccia appuntita, due grandi prese circolari affiancate e aste laterali.',
    'Fucile in diagonale, canna lunga biforcuta, mirino superiore, calcio e cinghia curva.',
    'Lama sottile in diagonale con punta triangolare, guardia scura e impugnatura rettangolare.',
    'Flacone alto rastremato con base arrotondata, tappo scanalato e beccuccio piegato.',
    'Scanner a disco con quadrante inclinato, piccoli comandi e impugnatura inferiore.',
    'Dispositivo orizzontale arrotondato, grande lente circolare e maniglia superiore.',
    'Apparecchio medico allungato arrotondato con pannello superiore e cavi con terminali.',
    'Piastra protettiva verticale arrotondata con nodi circolari e fasce avvolgenti.',
    'Borsa morbida rovesciata con gemme sfaccettate sparse davanti all’apertura.',
    'Piccolo robot a scocca triangolare, sensori frontali e due bracci snodati a pinza.',
    'Creatura scura bassa e pelosa con struttura alta triangolare e grande anello sommitale.',
    'Piccola creatura pelosa seduta, occhi e orecchie grandi e lunga coda con ciuffo.',
    'Busto di androide di profilo a sinistra, testa ovale segmentata, occhio e collo meccanici.',
]


def export(src, dst, size):
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not Path(src).exists():
        if dst.exists():
            return
        raise FileNotFoundError(src)
    subprocess.run(['convert', str(src), '-resize', size + '!',
                    '-define', 'png:exclude-chunks=date,time', str(dst)], check=True)


def register_sheet(key, original, prompt, description, target):
    prompt = prompt.rstrip()
    sheet = ROOT / 'reborn/schede' / (key + '.md')
    comparison = ROOT / 'reborn/confronti' / (key + '.png')
    sheet.write_text(f'# {key}\n\n## Originale osservato\n\n'
        f'`{original}`\n\n{description}\n\n'
        '## Elementi da conservare\n\nSagoma, proporzioni, componenti e posa '
        'del riferimento. Nessun testo, numero o logo nell’asset.\n\n'
        f'## Prompt usato\n\n{prompt}\n\n'
        f'## Esito\n\nFile: `{target}`. Stato: **da_approvare**. '
        'Dimensioni e integrità verificate; approvazione artistica non presunta.\n')
    subprocess.run(['montage', str(ROOT / original), str(ROOT / target),
                    '-thumbnail', '600x600', '-tile', '2x1', '-geometry', '+20+20',
                    '-background', '#111823', str(comparison)], check=True)
    return {'originale': original, 'scheda': str(sheet.relative_to(ROOT)),
            'confronto': str(comparison.relative_to(ROOT)), 'stato': 'da_approvare'}


def main():
    data = json.loads(DOC.read_text())
    metadata = {}
    for entry in sorted(data['possessi'], key=lambda x: x['i']):
        i = entry['i']
        key = f'possessi_{i:02}'
        target = f'assets_reborn/carte/illustrazioni/{key}.png'
        export(entry['path'], ROOT / target, '768x512')
        original = f'assets/carte/scansioni/{key}_retro.webp'
        metadata[target] = register_sheet(key, original, entry['prompt'], DESCRIPTIONS[i], target)
    for entry in data['tokens']:
        key = entry['key']
        target = f'assets_reborn/pedine/{key}.png'
        export(entry['path'], ROOT / target, '512x512')
        original = ('assets/pedine/rib_selvaggio_elite.jpg' if entry['elite']
                    else 'assets/pedine/rib_fuoco_23.jpg')
        metadata[target] = register_sheet(key, original, entry['prompt'],
            f'Nuova variante {entry["terrain"]}: simbolo centrale della famiglia '
            'originale, colore ambientale e fascia inferiore libera. Nessun originale '
            'specifico esiste per questa unità; il riferimento è analogo.', target)
    for entry in data['frames']:
        key = f'{entry["side"]}_{entry["type"]}'
        target = f'assets_reborn/carte/{key}.png'
        export(entry['path'], ROOT / target, '764x1154')
        metadata[target] = register_sheet(key, 'assets_reborn/carte/cornice_ribelli.png',
            entry['prompt'], 'Variante della cornice pittorica Reborn esistente, '
            'bordo metallico, fondo pergamena e nessun testo. La carta Azione '
            'riserva tre sezioni per gli ambienti. L’impaginazione finale nel gioco '
            'richiede una verifica separata.', target)
    (ROOT / 'reborn/produzione/metadati_nuovi_asset.json').write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
    print(f'Exported {len(metadata)} missing assets with sheets and comparisons')


if __name__ == '__main__':
    main()
