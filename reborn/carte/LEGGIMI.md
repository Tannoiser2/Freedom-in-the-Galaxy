# Due esempi di carta personaggio

Redjac (imperiale) e Zina Adora (ribelle), con dati e abilità esatti di `data/carte.json`. Sei icone vettoriali distinguono Combattimento, Resistenza, Intelligenza, Comando, Diplomazia e Navigazione. Il comando spaziale compare tra parentesi nella quarta riga, come nella carta del gioco.

Le figure intere sono quelle già presenti in `assets_reborn/figure_intere/`, collocate a destra con sfumatura CSS verso sinistra e in basso. Il testo dell’abilità resta testo reale, non è incorporato nell’illustrazione. Numeri e icone sono indipendenti dall’arte e mantengono la leggibilità durante l’adattamento al dispositivo.

Proposta limitata a due esempi: non sostituisce ancora le carte nel gioco. Ricostruzione: `python tools/build_character_card_examples.py`; verifica ed esportazione PNG: `python tests/character_card_examples.py`. Il confronto è in `esempi-carte.png`; le singole carte in `redjac.png` e `zina-adora.png`. Font e licenze sono inclusi nella cartella `fonts/`.

La revisione 2 estende le figure dalla zona del titolo fino al riquadro abilità, con dissolvenza completa prima del testo. Icone, etichette, sottotitoli e testi inferiori sono ingranditi. Il numero usa un cerchio SVG; dopo il caricamento del font il suo centro visivo viene allineato geometricamente al centro del cerchio.
