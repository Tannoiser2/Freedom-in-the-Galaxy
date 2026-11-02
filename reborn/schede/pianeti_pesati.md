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

La mappa e i dati fissano gli estremi della scala: **Kelta 352**, Selvaggio 2,
è il più piccolo; **Solvia 432**, Urbano 4 + Sotterraneo 3 + Selvaggio 5 = 12,
è il più grande. In unità di scena i raggi sono 1,08423 e 2,65581, con Adare a 2,3.
Il rapporto dei diametri Solvia/Kelta è sqrt(6), circa 2,449. L'anello orbitale
non determina più la dimensione del pianeta nella vista Godot.

Ogni mondo ha un profilo artistico riproducibile: geografia, variante di Selvaggio,
palette, roccia, montagne, densità urbana, luci e colore dell'acqua. Le sei famiglie
del Selvaggio comprendono foreste temperate, taiga blu, savane, foreste ramate,
giungle turchesi e brughiere fredde; ulteriori parametri cambiano per ogni ID.
Nei pianeti misti con Liquido, canali oceanici separano 6–8 continenti principali.
Su richiesta esplicita, Mrane e Horon hanno isole scenografiche pari a circa il
5% del globo: sono dettagli del territorio Liquido, senza aggiungere nuovi environ.
Le percentuali degli environ continuano a descrivere i territori di gioco,
non la frazione di pixel d'acqua dentro ogni territorio Liquido.

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
  Il file di consegna carica ora buffer di pixel direttamente in WebGL, senza
  URL data:image, decoder di immagini o richieste di rete. Le mappe di anteprima
  sono 1024×512 per portabilità; le mappe di produzione restano 2048×1024.
- `reborn/modelli/adare.glb`: sfera UV con colore, normale ed emissione incorporate,
  importabile in Blender/Godot; la sua emissione è un materiale standard glTF,
  mentre il visualizzatore HTML attenua le luci urbane sul lato diurno.
- `python3 tools/build_adare_preview.py`: ricostruisce l'HTML dalle texture correnti.
- `blender --background --factory-startup --python tools/build_adare_model.py`:
  ricostruisce il modello.

Il concept illustrato separato (`reborn/anteprime/adare_concept.png`) suggerisce la
direzione artistica, ma non è il rendering delle texture procedurali né una prova
delle loro percentuali. L'anteprima `adare_3d.png` è invece catturata dal vero viewer.

## Piattaforme, unità e PDB

`tools/render_adare_units.py` produce un vero render Blender con due piattaforme,
linee ancorate a regioni verificate della maschera, tre gruppi di pedine militari,
Zina Adora e Adam Starlight. I personaggi sono figure sagomate trasparenti in uno
spazio 3D, come gli Sprite3D attuali: non sono mesh tridimensionali riggate.
Lo schieramento è dimostrativo, non un salvataggio di una partita reale.

`adare_unita_3d.png` include il PDB operativo; `adare_unita_pdb_down.png` mostra
gli stessi angoli orbitali in DOWN, con orbita rossa. Il componente Godot
`scripts/ui/difesa_planetaria3d.gd` legge forza `bdp` e stato `su` esistenti:
forza 0/1/2 = 1/2/3 basi, UP verde e rotazione 0,22 rad/s, DOWN rosso e fermo,
ripresa dalla posizione conservata. Le basi sono indicatori della forza totale,
non unità di combattimento aggiuntive. La forza e la parola DOWN restano visibili
per non affidare l'informazione solo al colore.

Check di visibilità: a larghezza 960 px le figure occupano circa 105–106 px in
altezza; le pedine 56–72 px. Queste misure includono il margine trasparente delle
immagini. È stato controllato visivamente che etichette e collegamenti non siano
nascosti dai bordi. Per nomi completi e dettagli dei volti è disponibile il render
ravvicinato. Il check non sostituisce una prova d'uso con giocatori.
