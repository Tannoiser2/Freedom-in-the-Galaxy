# Pianeti basati sugli environ

Fonte: `data/galassia.json`, campi `ambienti[].tipo` e `ambienti[].taglia`.
Richiesta dell'utente: estensione dei terreni proporzionale al valore degli environ;
dimensione complessiva determinata dalla loro somma.

## Regola di superficie e dimensione

Per un pianeta, S = somma delle taglie degli ambienti; ogni ambiente copre taglia/S
della superficie. Si interpreta la dimensione come **area sferica**: il raggio è
sqrt(S/9), relativo ad Adare. È una convenzione grafica esplicita, non una nuova
regola del gioco o una misura astronomica. Nessun dato di gameplay viene cambiato.

Adare: S = 9, raggio relativo = 1, Urbano 4/9 = 44,4444%, Selvaggio 5/9 = 55,5556%.
I diversi environ dello stesso tipo restano separati nei calcoli e possono
essere aggregati per la legenda visiva. Non si aggiungono oceani o altri ambienti
assenti dai dati. La posizione delle zone è una proposta artistica, non è canonica.

## Generazione e materiali

`python3 tools/generate_weighted_planets.py` produce tutti i 51 pianeti;
`--ids 142` rigenera soltanto Adare. Richiede NumPy, SciPy e Pillow.
Il rumore deterministico è campionato in coordinate sferiche XYZ: nessuna cucitura
longitudinale. Il seed è l'ID del pianeta. Quantili pesati con l'area delle bande
di latitudine assegnano le percentuali; non si conta semplicemente il numero di
pixel della mappa equirettangolare, che sovrastimerebbe i poli.

Per ogni pianeta: texture colore 2048×1024, emissione, normale tangenziale, altezza,
maschera ambientale e disco trasparente 512×512. Le luci delle città sono limitate
all'Urbano, le emissioni di lava al Fuoco. Le mappe colore non contengono ombre
di illuminazione precalcolate: la stella viene valutata dal visualizzatore 3D.
Le mappe altezza e normale sono dettagli di materiale, non montagne geometriche.
Questa è una prima resa procedurale; lo stile pittorico può essere rifinito dopo
la valutazione del prototipo, senza cambiare la maschera di superficie.

Le quote richieste e misurate sono in `reborn/pianeti_superfici.json`.
Ogni texture è **da_approvare**. Nessuna approvazione artistica è stata inventata.

## Esempio 3D

- `reborn/anteprime/adare_3d.html`: visualizzatore WebGL autonomo, texture incorporate,
  rotazione, zoom, regolazione della stella, rilievo, modalità ambienti e notte.
- `reborn/modelli/adare.glb`: sfera UV con colore, normale ed emissione incorporate,
  importabile in Blender/Godot; la sua emissione è un materiale standard glTF,
  mentre il visualizzatore HTML attenua le luci urbane sul lato diurno.
- `python3 tools/build_adare_preview.py`: ricostruisce l'HTML dalle texture correnti.
- `blender --background --factory-startup --python tools/build_adare_model.py`:
  ricostruisce il modello.

Il concept illustrato separato (`reborn/anteprime/adare_concept.png`) suggerisce la
direzione artistica, ma non è il rendering delle texture procedurali né una prova
delle loro percentuali. L'anteprima `adare_3d.png` è invece catturata dal vero viewer.
