# Raccolta delle carte personaggio

32 carte: 20 ribelli e 12 imperiali, con valori e abilità esatti di `data/carte.json`. `index.html` mostra la raccolta completa, con ricerca per nome e filtro per fazione. Ogni carta ha il proprio PNG scaricabile; il parametro `?personaggio=slug` permette di aprirne una sola.

`prova-limiti.html` e `prova-limiti.png` confrontano Emperor Coreguya (nome più lungo, 16 caratteri) e Thysa Kymbo (abilità più lunga, 179 caratteri). La prova è verificata prima dell’esportazione di tutte le carte.

Il formato comune è 600×1040: icone grandi e sei caratteristiche a sinistra, figura intera a destra estesa nella parte alta, sfumata a sinistra e fino a sparire sopra l’abilità. I nomi lunghi mantengono il carattere grande e vanno su due righe; intestazione e posizione della figura si adattano. Il testo dell’abilità usa 27–29 px ed è verificato integralmente sopra la classificazione inferiore, senza tagli, ellissi o abbreviazioni. L’assenza di un’abilità è indicata esplicitamente, senza aggiungere regole.

Il comando spaziale compare tra parentesi accanto a Comando. Solo i personaggi con il relativo attributo sono classificati “Cavaliere imperiale”; gli altri riportano il ruolo di fazione corretto. I numeri nei cerchi sono centrati sull’ingombro reale del carattere dopo il caricamento del font.

Le figure sono le illustrazioni già presenti in `assets_reborn/figure_intere/`, caricate nella pagina su richiesta. Testi, numeri e icone restano indipendenti dalle immagini. Font e licenze sono in `fonts/`.

Ricostruzione: `python tools/build_character_card_examples.py` (nome storico del builder). Verifica ed esportazione PNG a 1200×2080: `python tests/character_card_examples.py`. La raccolta grafica non modifica statistiche o regole di gioco. `esempi-carte.png` conserva il confronto di Redjac e Zina Adora nel formato aggiornato.
