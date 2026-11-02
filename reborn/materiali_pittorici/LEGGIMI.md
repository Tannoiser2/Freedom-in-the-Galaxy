# Libreria pittorica dei pianeti

18 materiali a 2048×1024, tre per ciascuno dei sei ambienti. I nomi delle varianti sono definiti in `tools/build_planet_atlas.py`; l’assegnazione stabile ai 51 pianeti è nel catalogo generato dell’atlante. Lo stesso materiale viene ridotto a 512×256 per la base rotonda del rispettivo ambiente.

Le varianti 1 di Urbano, Sotterraneo, Selvaggio, Liquido e Aereo conservano le cinque texture approvate nelle prove precedenti (`atlante/painterly/v4/urbano.jpg` e `atlante/painterly/v3/`). Le altre 13 immagini sono nuove; i prompt sono in `prompts.json`. Fuoco ha tre nuovi materiali adatti al globo, con fiumi di lava, caldere e rift.

Colori comuni per famiglia, edifici e alberi minuti, grandi strutture geologiche e atmosferiche leggibili. La rete luminosa urbana è dipinta nella texture, senza reticoli geometrici sovrapposti. Isole e lava sotterranea sono dettagli artistici; non modificano la classificazione degli ambienti.

Le sorgenti sono escluse dall’import Godot grazie a `reborn/.gdignore`. La pubblicazione serve le copie preparate dall’atlante e non richiede servizi di generazione o CDN durante l’uso.
