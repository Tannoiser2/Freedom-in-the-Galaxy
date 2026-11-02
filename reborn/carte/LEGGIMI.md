# Raccolta delle 140 carte

`mazzi.html` completa la raccolta con 108 carte: 30 azione, 15 missione, 29 evento, 14 strategiche e 20 possessi. Ricerca e filtro per mazzo permettono di consultarle; ciascuna ha un PNG a 1200×2080. `prova-mazzi.html` confronta sei esempi, inclusi i testi più lunghi. Testi, lettere, statistiche e collegamenti tra province provengono integralmente da `data/carte.json`.

Le missioni riducono prima lo spazio decorativo per mantenere leggibili tutte le sezioni. Le azioni distinguono i tre ambienti con icone SVG; le strategiche mostrano la direzione tra province. I possessi usano le venti illustrazioni originali, con quattro statistiche solo per le astronavi. I due fondali generici di missioni ed eventi sono documentati in `assets/illustrazioni-mazzi.json`.

Ricostruzione degli altri mazzi: `python tools/build_other_cards.py`. Verifica integrale dei dati, impaginazione, cerchi, filtri e schermi mobili, ed esportazione: `python tests/other_cards.py`.

## Personaggi

32 carte: 20 ribelli e 12 imperiali, con valori e abilità esatti di `data/carte.json`. `index.html` mostra la raccolta completa, con ricerca per nome e filtro per fazione. Ogni carta ha il proprio PNG scaricabile; il parametro `?personaggio=slug` permette di aprirne una sola.

`prova-limiti.html` e `prova-limiti.png` confrontano Emperor Coreguya (nome più lungo, 16 caratteri) e Thysa Kymbo (abilità più lunga, 179 caratteri). La prova è verificata prima dell’esportazione di tutte le carte.

Il formato comune è 600×1040: icone grandi e sei caratteristiche a sinistra, figura intera a destra estesa nella parte alta, sfumata a sinistra e fino a sparire sopra l’abilità. I nomi lunghi mantengono il carattere grande e vanno su due righe; intestazione e posizione della figura si adattano. Il testo dell’abilità usa 27–29 px ed è verificato integralmente sopra la classificazione inferiore, senza tagli, ellissi o abbreviazioni. L’assenza di un’abilità è indicata esplicitamente, senza aggiungere regole.

Il comando spaziale compare tra parentesi accanto a Comando. Solo i personaggi con il relativo attributo sono classificati “Cavaliere imperiale”; gli altri riportano il ruolo di fazione corretto. I numeri nei cerchi sono centrati sull’ingombro reale del carattere dopo il caricamento del font.

Le figure sono le illustrazioni già presenti in `assets_reborn/figure_intere/`, caricate nella pagina su richiesta. Testi, numeri e icone restano indipendenti dalle immagini. Font e licenze sono in `fonts/`.

Ricostruzione: `python tools/build_character_card_examples.py` (nome storico del builder). Verifica ed esportazione PNG a 1200×2080: `python tests/character_card_examples.py`. La raccolta grafica non modifica statistiche o regole di gioco. `esempi-carte.png` conserva il confronto di Redjac e Zina Adora nel formato aggiornato.
