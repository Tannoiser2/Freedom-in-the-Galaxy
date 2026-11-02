# Prove pittoriche di Solvia e Midest

Aprire `../?planet=432&skin=painterly&isolated=1`. Il selettore permette il confronto con la skin attuale. Per Midest aprire `../?planet=341&skin=painterly&isolated=1`. La prova riguarda Solvia e Midest; gli altri pianeti conservano le loro superfici.

Tre materiali illustrati originali generati per questa prova: Urbano ocra/bronzo (#A87943), Sotterraneo terracotta (#854F46), Selvaggio verde (#3E6C45). Questi sono i colori base proposti per ogni ambiente, da mantenere anche su altri pianeti se lo stile verrà adottato. Il disegno può variare, la famiglia cromatica resta fissa.

La maschera originale 2048×1024 di Solvia viene campionata sul globo: Urbano 4/12, Sotterraneo 3/12, Selvaggio 5/12. Il filtro lineare miscela solo i bordi dei texel senza cambiare la classificazione originale. Nessun oceano. Le texture sono materiali pittorici, non fotografie né una simulazione topografica. Nella prova sono disattivati rilievo procedurale, cubetti urbani e luci notturne della vecchia skin.

Le tre mappe JPG sono sorgenti artistiche condivisibili; `solvia-mask.png` copia la maschera di produzione. L'atlante le applica tramite shader e non usa un'immagine di un globo già illuminato. `isolated=1` nasconde inizialmente unità, PDB e nomi, riattivabili dai controlli. Trascinare per ruotare e usare la rotella per ingrandire.

Midest usa lo stesso materiale Selvaggio di Solvia e aggiunge Liquido blu petrolio (#286D88), con correnti dipinte. La maschera originale `midest-mask.png` conserva la geografia del pianeta: Liquido 3/7, Selvaggio 4/7. Il filtro interpola i due materiali lungo le coste. Nessuna zona urbana o sotterranea viene aggiunta.
