# Truppe e flotte

40 tipi derivati da `data/regole_avanzate.json`: 10 imperiali e 5 categorie ribelli in ciascuno dei 6 environ. Ogni unità ha due presentazioni, superficie e orbita, con entrambi i valori originali sempre visibili. Il selettore generale e il pulsante di ogni scheda cambiano immagine ed evidenziano il valore pertinente. Le unità con forza spaziale zero sono raffigurate con trasporti, senza attribuire loro forza aggiuntiva.

La Milizia, la Linea e l’Élite hanno figure distinte; per i ribelli ciascuna di queste tre famiglie ha equipaggiamento adattato ai sei ambienti. Le categorie 2-1, 2-3 e 4-3 condividono la famiglia visiva di fanteria di linea e conservano nome e valori distinti. Gli imperiali riportano “Tutti gli environ”: non ricevono una specializzazione ambientale inventata. Le tre navi strategiche con forza terrestre zero mantengono una figura navale anche sulla superficie. Le denominazioni ribelli Milizia/Linea leggera/Linea/Veterana/Élite sono etichette di presentazione delle cinque categorie originali.

Le figure originali di produzione provengono da sei fogli generati, documentati con prompt in `../produzione/truppe-illustrazioni.json`. `tools/export_troop_art.py` estrae le celle con margine, senza ridipingere o ricolorare. Sono disponibili 36 illustrazioni (una nave speciale ribelle è riservata e non usata), 80 PNG di schede a 1200×2080 in `png/`, e 80 pedine quadrate in `assets_reborn/truppe/pedine/` per la mappa del gioco.

In partita, con Grafica Reborn attiva, `UI.truppa_tex` sceglie automaticamente la figura in base al luogo: superficie, orbita e deriva. Mappa, galassia e tavolo 3D usano lo stesso criterio; passando sulla pedina nella mappa si apre la scheda ingrandita. Le unità nemiche nascoste continuano a usare i retro originali; le nuove immagini e le etichette non ne rivelano la forza. Le regole di movimento e combattimento restano invariate. La modalità classica conserva le pedine originali.

`tools/package_troop_game.py`, richiamato anche da `tools/prepara_reborn_gioco.py`, crea copie runtime compresse in `assets/reborn/truppe/`: 35 figure, 80 pedine WebP a 256×256 e 80 schede WebP con lato massimo 860. Le sorgenti restano in `assets_reborn/` e `reborn/`, escluse dall’importazione Godot. Il test della partita verifica le risorse runtime effettive e non soltanto il ripiego sulle pedine originali.

L’atlante usa il nuovo selettore di posizione per la dimostrazione: sposta le sole truppe sulle piattaforme orbitali e lascia i personaggi sulle basi di superficie. Non è uno stato di partita.

Ricostruzione: `python tools/build_troop_cards.py`, poi `python tests/troop_cards.py` per verificare ed esportare. `python tests/troop_atlas.py` verifica il cambio soldati/navi su tutti i sei environ; `tests/truppe.gd` verifica la scelta delle immagini nelle unità reali e negli scenari base. L’atlante si ricostruisce con `python tools/build_planet_atlas.py`.
