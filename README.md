# Freedom in the Galaxy — versione digitale

Versione digitale in Godot 4.7 di **Freedom in the Galaxy: The Star Rebellions, 5764 AD** (SPI, 1979; Howard Barasch e John H. Butterfield). Una manciata di eroi ribelli prova a sollevare i pianeti contro l'Impero galattico.

## Cosa c'è

- **Regole complete dello Star System Game** (Sezioni 1-16): movimento a piedi, in astronave e delle truppe; rilevamento dei BDP e attacco dei BDP alle truppe; reazione nemica; combattimento militare con comandanti e ambienti; ricerca; combattimento fra personaggi (corpo a corpo e scontro a fuoco, cattura, sganciamento, ferite e guarigione); missioni con le 30 carte Azione e tutti i loro eventi; pescate bonus; possessi; ribellione e controllo dei pianeti; punti vittoria e vittorie immediate.
- **Province Game** (Sezioni 17-28): Fase delle Operazioni in sette segmenti, caselle d'Orbita, Deriva e Deriva 2, iperbalzi con la tabella originale, intercettazione e attacchi radenti dei BDP, combattimento spaziale (BDP in difesa, attacco ai BDP, assalto deciso, comandanti spaziali), rilevamento con le flotte in orbita e attacchi delle squadriglie, Punti Forza e acquisti (unità d'élite, squadre suicide, BDP), trasporto delle unità 1-0, movimento di superficie, effetto domino, sovrani (missione E), pianeti natali e regalità, riparazioni delle astronavi.
- **Galactic Game** (Sezioni 29-38): stadio galattico con i 29 Eventi galattici, tasse e manutenzione imperiali, Incarichi strategici, base segreta ribelle e tracciato delle risorse, 16 Segreti planetari, Atrocità (BDP di livello 2, Resolution, Peacemaker, Planet Stabilizer), missioni H (Rubare risorse) e Q (Interrogare prigioniero), segreti nemici, schieramento della campagna (automatico o manuale per l'Impero) e vittoria a 26 Punti Vittoria.
- **Cinque scenari**: *La fuga verso Egrix* e *La polveriera di Varu* (Star System Game), *La porta di servizio dell'Impero* e *Orlog sotto assedio* (Province Game), *La campagna galattica* (Galactic Game, 20 turni).
- **IA per entrambe le parti**: si gioca con i Ribelli o con l'Impero, in due sullo stesso schermo oppure si guarda l'IA contro se stessa.
- **Carte ricomposte in italiano** (personaggi con il ritratto originale, possessi, missioni, carte Azione); il clic destro mostra la scansione originale.
- **Mappa 2D** con le «Planet Track» come sulla mappa SPI, le caselle d'Orbita e di Deriva e le pedine originali; **vista della galassia** sulla mappa originale (zoom, spostamento, clic su una stella per aprire il sistema; si apre da sola sul sistema della decisione in corso); **vista 3D** del sistema stellare con le pedine in piedi sulle piattaforme degli ambienti e gli anelli d'orbita.
- **Firebase**: partite online Ribelli contro Impero (stanze con codice di 4 lettere) e salvataggi riprendibili da qualsiasi dispositivo; sul dispositivo la partita si salva comunque da sola.
- **Creature** della Galactic Guide con le loro regole speciali e la Tabella dei Locali infuriati.

Prossima fase: la versione **Reborn** con grafica nuova.

## Struttura

- `data/` — dati estratti dal modulo Tabletop Simulator e dalle regole:
  - `galassia.json`: 25 sistemi, 51 pianeti con ambienti, razze, risorse, Coup, sovrani, creature, rotte
  - `carte.json`: 140 carte con testo inglese e traduzione italiana, codici degli eventi Azione
  - `tabelle.json`: rilevamento, combattimenti, ricerca, squadre, locali infuriati, punti vittoria
  - `creature.json`, `possessi_effetti.json`, `scenari.json`
  - `regole_avanzate.json`: costi e forze delle unità, sovrani, Segreti planetari, tasse, basi possibili, punti vittoria del Province Game
- `scripts/core/` — motore (`motore.gd`, `missioni.gd`, `combattimento.gd`), Province Game (`avanzato.gd`), Galactic Game (`galattico.gd`), dati, IA
- `scripts/ui/` — menu, schermata di gioco, mappa 2D, vista della galassia, tavolo 3D, carte, regole
- `scripts/net/` — Firebase (radice `fitg/rooms` nel progetto condiviso)
- `assets/` — pedine originali, mappa della galassia, scansioni delle carte, font (Saira Condensed, Exo 2: licenza OFL)
- `tests/` — partite automatiche (`sim.gd`), verifica dei salvataggi (`ripresa.gd`), fotografie dell'interfaccia (`foto.gd`)
- `tools/` — controllo dei glifi dei font, pubblicazione sulla ludoteca Cloudflare

## Prove

```
godot --headless --path . -s tests/sim.gd -- 20        # 40 partite IA contro IA (Star System)
godot --headless --path . -s tests/sim.gd -- 10 backdoor,orlog,galattica [seme]
godot --headless --path . -s tests/ripresa.gd           # salvataggi: ripresa identica in tutti gli scenari
python3 tools/controlla_glifi.py                         # nessun carattere mancante nei font
```

## Pubblicazione

Solo su richiesta: Actions » Pubblica » Run workflow (oppure un commit con `[pubblica]` nel messaggio). Il workflow esporta la versione web e la pubblica sulla ludoteca privata Cloudflare (`fitg`) e, finché il repository è pubblico, su GitHub Pages.

## Note sulle regole

- Nello stesso ambiente ogni tipo di missione può essere assegnato a un solo Gruppo di Missione (altri personaggi possono unirsi al gruppo): evita che una sola lettera completi più volte la stessa missione.
- Le ferite in combattimento vengono distribuite automaticamente cercando di non far morire nessuno.
- Province e Galactic Game: le unità d'élite imperiali annullano lo spostamento degli ambienti speciali e aggiungono la loro forza alla squadra; un sovrano neutrale richiede due lettere E.
- Galactic Game, semplificazioni: lo schieramento automatico dell'Impero segue una regola fissa (una Milizia per pianeta, BDP sulle capitali, truppe dove la Lealtà è peggiore); dopo il quattordicesimo turno il mini-mazzo degli Incarichi strategici è di sei carte a caso; i Segreti Casino Galactica, Complesso di clonazione, Mondo della droga, IPOC e Mondo mutante sono descritti ma senza effetti automatici; gli eventi galattici 101, 111, 114 e 118 sono solo descritti; l'Impresa in Astronave (J) non è ancora disponibile; il Mondo iperdimensionale dà una pescata bonus in più invece di una seconda missione.
- Nel Galactic Game l'IA ribelle non compra truppe dalla base finché non controlla un pianeta (scoperta la base senza pianeti ribelli l'Impero vince subito).
