# Atlante interattivo Reborn

L'atlante pubblicato è in `/reborn/atlante/`. Contiene i 51 pianeti e i 25 sistemi
che hanno pianeti; i 20 nodi di navigazione della mappa non sono sistemi solari.
Gli elenchi permettono di passare direttamente a un pianeta o a un intero sistema.
È una visualizzazione indipendente, non una partita e non un editor dei salvataggi.

## Contenuti e controlli

- Stella, orbite, rivoluzione dei pianeti, rotazione dei globi su se stessi.
- Piattaforme degli environ, collegate a punti della maschera del terreno.
- Due personaggi e pedine militari dimostrative; non rappresentano una situazione
  di gioco salvata. I personaggi sono sagome trasparenti, non mesh riggate.
- PDB: livelli 0/1/2 mostrano 1/2/3 basi. UP ruota in verde; DOWN ferma le basi e
  colora l'orbita in rosso. La rotazione del pianeta e la rivoluzione continuano.
  Le impostazioni del singolo mondo restano durante i cambi di vista.
- Clic sui nomi o sui globi per avvicinarsi; trascinamento e rotella/pinch per
  la camera; pausa globale, velocità, ripristino dell'inquadratura.
- Superficie naturale, mappa degli environ e lato notturno. Le piattaforme,
  il PDB e i nomi possono essere nascosti separatamente.

I raggi dei pianeti rispettano `2.3 * sqrt(somma(taglia)/9)`, con Kelta e Solvia
agli estremi già verificati. Stelle, distanze e periodi orbitali sono schematici.
Nella vista di sistema le unità diventano piccole: le etichette e il pulsante
di avvicinamento consentono di leggere il singolo pianeta.

## Adare e l'aspetto dell'Urbano

Adare contiene solo Urbano 4 e Selvaggio 5. Non ha territorio Liquido. La precedente
resa grigio-azzurra delle città era ambigua: la texture urbana ora contiene strade
e isolati ocra/bronzo, e l'atlante aggiunge volumi edificati sulla maschera urbana.
Il riflesso speculare da acqua è limitato ai territori Liquido. Anche la mappa
diagnostica mostra l'Urbano in ocra per non confonderlo con gli oceani. Le maschere
di produzione conservano i codici RGB originali: non sono cambiate le regole.

Le proporzioni continuano a essere misurate sulla sfera, non sui pixel UV.
Sui due mondi solo Liquido le isole scenografiche sono state richieste dall'utente
e non creano nuovi environ. Nei mondi misti gli oceani separano i continenti.

## Build e pubblicazione

```sh
python3 tools/generate_weighted_planets.py --ids 142
python3 tools/build_planet_atlas.py
python3 tools/build_adare_preview.py
python3 tools/prepare_reborn_preview.py
```

I builder dei materiali richiedono Pillow, NumPy e SciPy come gli altri strumenti
grafici. Il pacchetto dell'atlante generato è in `reborn/atlante/`: HTML, CSS, JS,
catalogo, immagini ottimizzate e Three.js 0.180.0 con licenza MIT conservata.
Non usa CDN, Firebase o credenziali. Carica solo i pianeti visibili e mantiene
una cache limitata dei materiali. I nomi dei file dei materiali includono hash
del contenuto. La pubblicazione copia i file preparati, senza dipendenze npm.

Per sviluppo servire il repository con un server HTTP; i moduli ES non vanno
aperti come file HTML isolati. La versione Adare autonoma rimane disponibile
separatamente per l'uso offline. In GitHub Pages il workflow `Pubblica` copia
l'atlante sotto `reborn/atlante/` insieme al sito del gioco.

## Verifiche

`python3 tests/atlas_browser.py` richiede Chromium e Playwright: percorre tutte
le 51 viste planetarie e le 25 viste di sistema attraverso gli elenchi reali,
verifica unità, geometria urbana, cache, rivoluzione, rotazione, forza e stato
PDB, zoom, modalità del materiale e layout mobile. I messaggi di errore JavaScript
e gli errori WebGL vengono trattati come fallimenti.

`python3 tools/check_weighted_planets.py` verifica quote sferiche, formati,
cuciture, poli e limiti delle emissioni per i 51 set di produzione. Non sono
stati modificati i dati di gioco in `data/`.
