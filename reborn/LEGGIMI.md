# Freedom in the Galaxy — REBORN: catalogo grafico

Pacchetto autonomo di produzione grafica. Le carte definitive restano volutamente fuori da questa fase.

## Completamento del 2 novembre 2026

Creati i 35 asset prima assenti: cinque pedine (`rib_fuoco_43` e le élite
sotterraneo/liquido/aereo/fuoco), dieci cornici e retro per possessi, missioni,
azioni, eventi e strategiche, e venti illustrazioni dei possessi. Ogni nuovo asset
ha prompt, scheda e confronto con il riferimento; tutti sono **da_approvare**.
La produzione usa i disegni delle carte originali, che per i possessi sono nei
file denominati `_retro.webp`. L'esportazione PNG rispetta le dimensioni dell'MD.

Rigenerati i 51 pianeti con terreno proporzionale alla taglia degli environ.
Ogni pianeta dispone di colore, maschera ambienti, altezza, normale, emissione
e disco. La dimensione totale è interpretata come superficie: raggio relativo
sqrt(somma taglie / 9). La fonte dati e il gameplay non vengono modificati.
Quote richieste/misurate: `pianeti_superfici.json`; metodo e limiti:
`schede/pianeti_pesati.md`.

### Adare in 3D

- Aprire `anteprime/adare_3d.html` in un browser WebGL: è autonomo, con texture
  incorporate e senza dipendenze remote. Rotazione, zoom, luce, rilievo, ambienti
  e notte sono disponibili. Screenshot del vero viewer: `anteprime/adare_3d.png`.
- Importare `modelli/adare.glb` in Blender o Godot: contiene sfera e tre mappe.
- `anteprime/adare_concept.png` è un riferimento artistico generato separatamente,
  non il rendering del materiale procedurale: non usarlo per verificare le quote.

### Verifiche e riproduzione

`python3 tools/check_weighted_planets.py` verifica le quote contro i dati originali,
le cuciture, i poli, i formati e le emissioni per tutti i 51 pianeti.
Il massimo errore misurato è 0,00012 punti percentuali. Verificati i 35 nuovi
asset nei formati richiesti, il GLB con texture incorporate e l'avvio del viewer
in Chromium/WebGL senza errori JavaScript. Il viewer è un esempio separato;
non è integrato nel gioco e non è stato pubblicato.

Per rigenerare le texture: `python3 tools/generate_weighted_planets.py`.
Per ricostruire il viewer: `python3 tools/build_adare_preview.py`.
Per il GLB: `blender --background --factory-startup --python tools/build_adare_model.py`.
I generatori planetari richiedono NumPy, SciPy e Pillow; l'esportazione dei nuovi
disegni usa ImageMagick. I prompt e le fonti sono in `produzione/nuovi_asset.json`.
`tools/update_reborn_catalog.py` ora conserva approvazioni e schede esistenti e
scrive i conteggi in `inventario_generato.md` senza cancellare questo resoconto.

### Cosa resta

- Approvazione artistica e controllo di leggibilità in gioco dei nuovi asset.
- Le criticità degli asset preesistenti restano separate: fogli Meshy con
  profilo schiacciato/retro specchiato, astronavi fuori formato e schede storiche
  incomplete. Non sono stati dichiarati corretti né approvati da questo blocco.
- Verifica d'impaginazione e successiva integrazione delle carte nel gioco.
- Raffinamento artistico del materiale planetario dopo la valutazione di Adare.

## Inventario aggiornato

1001 immagini registrate nel manifest, tutte da approvare. I conteggi per
cartella sono riportati in `inventario_generato.md`. L'inventario seguente è quello
storico precedente al completamento.

## Inventario

- `astronavi`: 20 file
- `carte`: 4 file
- `carte_sorgenti`: 280 file
- `figure_intere`: 32 file
- `interfaccia`: 2 file
- `mappa`: 1 file
- `meshy`: 32 file
- `pedine`: 212 file
- `pianeti`: 102 file
- `ritratti`: 32 file
- `stelle`: 45 file

## Anteprime di controllo

- `reborn/anteprime/inventario_personaggi.png`
- `reborn/anteprime/inventario_pianeti.png`
- `reborn/anteprime/inventario_astronavi.png`
- `reborn/anteprime/inventario_segreti.png`
