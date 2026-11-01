# Freedom in the Galaxy — versione digitale

Versione digitale in Godot 4.7 di **Freedom in the Galaxy: The Star Rebellions, 5764 AD** (SPI, 1979; Howard Barasch e John H. Butterfield). Una manciata di eroi ribelli prova a sollevare i pianeti contro l'Impero galattico.

## Cosa c'è (fase 1: Star System Game)

- **Regole complete dello Star System Game** (Sezioni 1-16): movimento a piedi, in astronave e delle truppe; rilevamento dei BDP e attacco dei BDP alle truppe; reazione nemica; combattimento militare con comandanti e ambienti; ricerca; combattimento fra personaggi (corpo a corpo e scontro a fuoco, cattura, sganciamento, ferite e guarigione); missioni con le 30 carte Azione e tutti i loro eventi; pescate bonus; possessi; ribellione e controllo dei pianeti; punti vittoria e vittorie immediate.
- **Due scenari**: *La fuga verso Egrix* (Flight to Egrix) e *La polveriera di Varu* (The Varu Powderkeg).
- **IA per entrambe le parti**: si gioca con i Ribelli o con l'Impero, in due sullo stesso schermo oppure si guarda l'IA contro se stessa.
- **Carte ricomposte in italiano** (personaggi con il ritratto originale, possessi, missioni, carte Azione); il clic destro mostra la scansione originale.
- **Mappa 2D** con le «Planet Track» come sulla mappa SPI e le pedine originali; **vista 3D** del sistema stellare con le pedine in piedi sulle piattaforme degli ambienti.
- **Firebase**: partite online Ribelli contro Impero (stanze con codice di 4 lettere) e salvataggi riprendibili da qualsiasi dispositivo; sul dispositivo la partita si salva comunque da sola.
- **Creature** della Galactic Guide con le loro regole speciali e la Tabella dei Locali infuriati.

Prossime fasi: Province Game (iperbalzi, combattimento spaziale, effetto domino, sovrani) e Galactic Game (campagna completa). Poi la versione **Reborn** con grafica nuova.

## Struttura

- `data/` — dati estratti dal modulo Tabletop Simulator e dalle regole:
  - `galassia.json`: 25 sistemi, 51 pianeti con ambienti, razze, risorse, Coup, sovrani, creature, rotte
  - `carte.json`: 140 carte con testo inglese e traduzione italiana, codici degli eventi Azione
  - `tabelle.json`: rilevamento, combattimenti, ricerca, squadre, locali infuriati, punti vittoria
  - `creature.json`, `possessi_effetti.json`, `scenari.json`
- `scripts/core/` — motore (`motore.gd`, `missioni.gd`, `combattimento.gd`), dati, IA
- `scripts/ui/` — menu, schermata di gioco, mappa 2D, tavolo 3D, carte, regole
- `scripts/net/` — Firebase (radice `fitg/rooms` nel progetto condiviso)
- `assets/` — pedine originali, mappa della galassia, scansioni delle carte, font (Saira Condensed, Exo 2: licenza OFL)
- `tests/` — partite automatiche (`sim.gd`), verifica dei salvataggi (`ripresa.gd`), fotografie dell'interfaccia (`foto.gd`)
- `tools/` — controllo dei glifi dei font, pubblicazione sulla ludoteca Cloudflare

## Prove

```
godot --headless --path . -s tests/sim.gd -- 20        # 40 partite IA contro IA
godot --headless --path . -s tests/ripresa.gd           # salvataggi: ripresa identica
python3 tools/controlla_glifi.py                         # nessun carattere mancante nei font
```

## Pubblicazione

Solo su richiesta: Actions » Pubblica » Run workflow (oppure un commit con `[pubblica]` nel messaggio). Il workflow esporta la versione web e la pubblica sulla ludoteca privata Cloudflare (`fitg`) e, finché il repository è pubblico, su GitHub Pages.

## Note sulle regole

- Nello stesso ambiente ogni tipo di missione può essere assegnato a un solo Gruppo di Missione (altri personaggi possono unirsi al gruppo): evita che una sola lettera completi più volte la stessa missione.
- Le ferite in combattimento vengono distribuite automaticamente cercando di non far morire nessuno.
