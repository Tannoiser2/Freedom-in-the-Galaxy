# Fondali delle piattaforme

Sei immagini condivise a 512×256, con una palette fissa per ambiente. Urbano, Sotterraneo, Selvaggio e Liquido derivano dai materiali pittorici in `../painterly/`; Aereo e Fuoco sono nuove illustrazioni per le piattaforme. Tutti i file restano locali, senza servizi esterni a runtime.

Ogni piattaforma usa la stessa immagine sul piano e sul fondale. Il fondale è dietro personaggi e truppe; nome, bordo colorato e collegamento alla superficie identificano lo stesso ambiente. La piattaforma segue la rotazione del pianeta ma rivolge il fondale verso l'osservatore, per mantenere leggibili le unità.

Le piattaforme sono una vista tattica ingrandita. Sul globo di Solvia e Midest i dettagli dei materiali sono circa 24 volte più piccoli della prima prova; la scala tiene conto del raggio del pianeta. Campionamento variato e mipmap riducono ripetizioni e sfarfallio. Le maschere degli ambienti restano quelle originali.
