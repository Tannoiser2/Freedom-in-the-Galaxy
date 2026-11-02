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

## Materiali di tutti i pianeti

Lo stile pittorico è quello predefinito per tutti i 51 pianeti. La libreria comprende 18 texture: tre varianti per ognuno dei sei ambienti. La [pagina di confronto](https://tannoiser2.github.io/Freedom-in-the-Galaxy/reborn/atlante/materiali.html) mostra tutte le varianti e collega un pianeta che usa ciascuna di esse.

Ogni ambiente riceve una variante stabile, conservata nel catalogo e condivisa dal globo e dalla sua base rotonda. Le tre varianti di ogni famiglia sono tutte usate. Le quattro prime prove (Solvia, Midest, Magro, Cieson) conservano i materiali approvati come variante 1. Il selettore “Precedente” permette il confronto con le vecchie superfici.

| Ambiente | Variante 1 | Variante 2 | Variante 3 |
|---|---|---|---|
| Urbano | Nuclei radiali | Conglomerati ramificati | Città a corridoio |
| Sotterraneo | Crepacci e altopiani | Caverne e doline | Faglie con lava |
| Selvaggio | Catene e foreste | Massicci e altopiani | Valli e dorsali |
| Liquido | Isolotti radi | Isole maggiori | Atolli e arcipelaghi |
| Aereo | Tempeste rosse | Vortici scuri | Fronti turbolenti |
| Fuoco | Fiumi di lava | Caldere vulcaniche | Rift incandescenti |

I dettagli urbani restano minuti, su fondo grigio con città e strade gialle luminose. Nessuna griglia geometrica è sovrapposta. Montagne, crepacci, nubi e isole hanno strutture leggibili dall’orbita. Le famiglie cromatiche sono condivise tra pianeti. La lava nei sotterranei è una variante artistica, non aggiunge un ambiente Fuoco; gli isolotti decorativi restano Liquido.

Le sei categorie vengono codificate senza perdita in due mappe RGB a 2048×1024. Conservano pixel per pixel le maschere originali, comprese quote e geografia; nessun dato in `data/` cambia. Sulle piattaforme l’immagine dell’ambiente compare solo sulla base rotonda, senza pannelli dietro le unità.

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

## Verifica della libreria

`python tests/planet_materials.py` controlla i 18 materiali, l’uso delle tre varianti in ciascuna famiglia e l’identità delle maschere su tutti i 51 pianeti. `python tests/atlas_browser.py` percorre i 51 pianeti e 25 sistemi, verifica le varianti sulle basi, le unità, i PDB e i limiti delle cache (4 pianeti e 8 materiali, oltre gli eventuali materiali ancora attivi). `python tests/materials_v3_browser.py` conserva il nome storico ma verifica anche le nuove varianti di lava, caverne, gas e isole, le luci notturne e la galleria su desktop e mobile.

Le sorgenti artistiche correnti e i prompt sono in `reborn/materiali_pittorici/`. Il builder genera copie con hash del contenuto per il sito e versioni più piccole per le basi. Le cartelle `painterly/v3`, `painterly/v4` ed `environs/` dell’atlante documentano le prove precedenti; il sito corrente usa la libreria indicata dal catalogo.
