# Freedom in the Galaxy REBORN — grafica nuova (istruzioni per Codex)

## 1. Cosa devi fare

Rifai **tutta la grafica** della versione digitale di *Freedom in the Galaxy* (SPI, 1979): personaggi, pedine, astronavi, carte, pianeti, segnalini e mappa della galassia.

La regola più importante di tutto il documento:

> **Più belli e moderni, ma non diversi.** Ogni personaggio, astronave e pedina deve restare riconoscibile a colpo d'occhio rispetto all'originale. È un *remaster*, non un *reboot*: stesso soggetto, stessa identità, resa migliore.

Il materiale originale è già nel repository (vedi il paragrafo 4). **Guarda sempre l'originale prima di disegnare qualsiasi cosa.**

## 2. Fedeltà: cosa NON deve cambiare

Per ogni soggetto che ha un'immagine originale (ritratto sulla carta personaggio, pedina, carta possesso), conserva:

- **specie e razza** (Rhone, Kayn, Saurian, Piorad, Xanthon, Segunden, Suvan…: tratti non umani, forma della testa, pelle, squame, pelo, orecchie, occhi);
- **viso**: proporzioni, età apparente, espressione, barba, baffi, capigliatura e acconciatura;
- **corporatura**: alto, tozzo, esile, muscoloso;
- **abbigliamento**: forma degli abiti, mantelli, armature, cappucci, uniformi, gioielli e insegne;
- **oggetti**: armi, strumenti e accessori nella stessa mano e nella stessa posizione;
- **posa e inquadratura**: stessa direzione dello sguardo, stessa postura, stesso taglio (busto, figura intera);
- **colori dominanti**, quando l'originale li ha. Se l'originale è in bianco e nero, scegli colori coerenti con la razza e con la parte: Ribelli caldi e terrosi, Impero freddo, metallico e oro;
- per le **astronavi**: sagoma, numero e posizione di motori, ali e cannoni, proporzioni dello scafo.

Cosa PUOI migliorare:

- tratto, anatomia, illuminazione, volumi, materiali e texture (stoffa, metallo, pelle);
- dettagli coerenti con l'originale (cuciture, graffi, riflessi, piccoli componenti);
- leggibilità a dimensioni piccole: contrasto, silhouette pulita, sfondo semplice.

Cosa NON devi fare:

- aggiungere o togliere armi, mantelli, caschi, cicatrici, protesi o animali;
- cambiare genere, età, razza o colore della pelle;
- inventare uniformi, loghi o simboli nuovi;
- **mettere testo nelle immagini**: niente nomi, numeri o lettere. Testi e valori li scrive il gioco con i suoi font;
- usare elementi riconoscibili di *Star Wars* o di altre opere protette: spade laser, caschi da stormtrooper, X-wing, TIE fighter, Morte Nera, simboli dell'Alleanza o dell'Impero di quei film. Il gioco nacque proprio come alternativa non su licenza: deve restare originale.

## 3. Stile visivo comune

- **Genere:** fantascienza illustrata, come una copertina di romanzo sci-fi della fine degli anni '70 rifatta oggi. Pittorico e pulito, non fotorealistico e non cartoon.
- **Luce:** controluce e luce di taglio; per i Ribelli una luce calda (arancio, rosso), per l'Impero una luce fredda (blu acciaio) con riflessi oro.
- **Palette dell'interfaccia** (resta questa):
  - notte `#07091A`;
  - pannelli `#0F1429`;
  - rosso dei Ribelli `#E14D38`;
  - oro dell'Impero `#F5BD33`;
  - ciano `#5CC8F5`;
  - testo `#EBE6D6`.
- **Colori degli ambienti** (la mappa li usa per riconoscerli; restano gli stessi):
  - Urbano: blu `#407AEB`;
  - Selvaggio: verde `#4DA84D`;
  - Sotterraneo: rosso mattone;
  - Liquido: azzurro;
  - Aereo: celeste;
  - Fuoco: arancio.
- **Coerenza:** tutti i ritratti devono sembrare dello stesso illustratore. Prima produci tre ritratti di prova (Zina Adora, Redjac, Kogus) e fermati per la conferma di Stefano. Poi procedi con il resto usando gli stessi prompt di stile.

## 4. Dove trovi gli originali

| Cosa | Dove |
|---|---|
| Carte (fronte e retro, 382×577) | `assets/carte/scansioni/<tipo>_<nn>_fronte.webp` e `_retro.webp`. Tipi: `ribelli` (20), `imperiali` (12), `possessi` (20), `missione` (15), `azione` (30), `evento` (29), `strategico` (14) |
| Pedine (140×140, fronte e retro `_r`) | `assets/pedine/*.jpg` |
| Mappa della galassia (3874×2844) | `assets/mappa/galassia.jpg` |
| Icona del gioco | `assets/misc/icona.png` |
| Dati (nomi, razze, titoli, pianeti) | `data/carte.json`, `data/galassia.json`, `data/regole_avanzate.json` |

Il ritratto di ogni personaggio è nel riquadro in alto a sinistra della sua carta (`ribelli_*` e `imperiali_*`). La pedina mostra lo stesso personaggio in piccolo.

## 5. Come lavorare, soggetto per soggetto

1. **Osserva** la carta e la pedina originali.
2. **Scrivi la scheda** `reborn/schede/<chiave>.md` con:
   - una descrizione visiva oggettiva dell'originale: razza, viso, capelli, abiti, colori, oggetti, posa;
   - l'elenco degli elementi da conservare;
   - il prompt usato.

   Niente immagine senza scheda.
3. **Genera** usando la scheda e passando l'originale come immagine di riferimento, se lo strumento lo consente.
4. **Confronta**: salva in `reborn/confronti/<chiave>.png` l'originale e la versione nuova affiancati.
5. **Controlla** la lista del paragrafo 8. Se un punto non va, rigenera; non correggere a parole.
6. **Registra** il file in `reborn/manifest.json` (paragrafo 9).

## 6. Formati e cartelle

- Tutto il nuovo materiale va in **`assets_reborn/`**, con le stesse sottocartelle e **gli stessi nomi di file** degli originali. Cambia solo l'estensione in `.png`. Esempio: `assets/pedine/pg_kogus.jpg` diventa `assets_reborn/pedine/pg_kogus.png`.
- **Non modificare né cancellare nulla in `assets/`** e non toccare il codice (`scripts/`, `scenes/`, `data/`). L'integrazione nel gioco si farà dopo.
- Specifiche per tipo:

| Tipo | Dimensioni | Note |
|---|---|---|
| Ritratti per le carte | 768×768 PNG | busto, sfondo scuro sfumato del colore della parte, in `assets_reborn/ritratti/` |
| Pedine | 512×512 PNG | quadrate, bordo arrotondato 6%, leggibili anche a 48 px; retro `_r` = stessa figura in versione «individuato» (vedi sotto) |
| Fogli di riferimento per Meshy | 2048×1024 PNG | personaggio a figura intera in T-pose leggera: fronte, profilo, retro; sfondo grigio neutro uniforme; in `assets_reborn/meshy/` |
| Astronavi | 1024×1024 PNG con trasparenza + pedina 512×512 | vista di tre quarti dall'alto; retro `_r` = versione danneggiata (fumo, squarci) |
| Pianeti | texture equirettangolare 2048×1024 PNG + disco illuminato 512×512 PNG con trasparenza | in `assets_reborn/pianeti/<id>.png` e `<id>_disco.png` |
| Stelle | 512×512 PNG con trasparenza | in `assets_reborn/stelle/<id>.png` |
| Cornici delle carte | 764×1154 PNG (doppio dell'originale) | solo cornice e fondo, **senza testo**; una per tipo; più il retro di ogni tipo |
| Mappa della galassia | **3874×2844**, stesse posizioni | vedi il paragrafo 7.8 |
| Icona | 1024×1024 PNG | |

**Retro delle pedine:**
- personaggio: versione «individuato», cioè la stessa figura con un mirino o un alone rosso disegnato, senza testo;
- unità imperiale mobile: il retro nasconde il valore, quindi è solo lo stemma imperiale nuovo;
- negli altri casi segui il retro originale.

## 7. Inventario completo

### 7.1 Personaggi (32): ritratto, pedina fronte e retro, foglio Meshy

La chiave del file è quella della pedina originale.

| Personaggio | Parte | Razza | Titolo | Pianeta natale | Carta originale | Pedina originale | File da produrre |
|---|---|---|---|---|---|---|---|
| Zina Adora | Ribelli | Rhone | Principessa di Adare | Adare | `assets/carte/scansioni/ribelli_19_fronte.webp` | `assets/pedine/pg_zina_adora.jpg` | `ritratti/pg_zina_adora.png`, `pedine/pg_zina_adora.png`, `pedine/pg_zina_adora_r.png` |
| Adam Starlight | Ribelli | Rhone | - | Liomax | `assets/carte/scansioni/ribelli_18_fronte.webp` | `assets/pedine/pg_adam_starlight.jpg` | `ritratti/pg_adam_starlight.png`, `pedine/pg_adam_starlight.png`, `pedine/pg_adam_starlight_r.png` |
| Agan Rafa | Ribelli | Rhone | - | Pronox | `assets/carte/scansioni/ribelli_17_fronte.webp` | `assets/pedine/pg_agan_rafa.jpg` | `ritratti/pg_agan_rafa.png`, `pedine/pg_agan_rafa.png`, `pedine/pg_agan_rafa_r.png` |
| Frun Sentel | Ribelli | Xanthon | Principe di Xan | Xan | `assets/carte/scansioni/ribelli_16_fronte.webp` | `assets/pedine/pg_frun_sentel.jpg` | `ritratti/pg_frun_sentel.png`, `pedine/pg_frun_sentel.png`, `pedine/pg_frun_sentel_r.png` |
| Odene Hobar | Ribelli | Leonid | Principe di Heliax | Heliax | `assets/carte/scansioni/ribelli_15_fronte.webp` | `assets/pedine/pg_odene_hobar.jpg` | `ritratti/pg_odene_hobar.png`, `pedine/pg_odene_hobar.png`, `pedine/pg_odene_hobar_r.png` |
| Ly Mantok | Ribelli | Saurian | - | Jura | `assets/carte/scansioni/ribelli_14_fronte.webp` | `assets/pedine/pg_ly_mantok.jpg` | `ritratti/pg_ly_mantok.png`, `pedine/pg_ly_mantok.png`, `pedine/pg_ly_mantok_r.png` |
| Vudot Vodot | Ribelli | Suvan | - | Akubera | `assets/carte/scansioni/ribelli_13_fronte.webp` | `assets/pedine/pg_vudot_vodot.jpg` | `ritratti/pg_vudot_vodot.png`, `pedine/pg_vudot_vodot.png`, `pedine/pg_vudot_vodot_r.png` |
| Ran Jayma | Ribelli | Piorad | - | Ownex | `assets/carte/scansioni/ribelli_12_fronte.webp` | `assets/pedine/pg_ran_jayma.jpg` | `ritratti/pg_ran_jayma.png`, `pedine/pg_ran_jayma.png`, `pedine/pg_ran_jayma_r.png` |
| Tourag | Ribelli | Rhone | - | Diomas | `assets/carte/scansioni/ribelli_11_fronte.webp` | `assets/pedine/pg_tourag.jpg` | `ritratti/pg_tourag.png`, `pedine/pg_tourag.png`, `pedine/pg_tourag_r.png` |
| Rayner Derban | Ribelli | Rhone | - | Orlog | `assets/carte/scansioni/ribelli_10_fronte.webp` | `assets/pedine/pg_rayner_derban.jpg` | `ritratti/pg_rayner_derban.png`, `pedine/pg_rayner_derban.png`, `pedine/pg_rayner_derban_r.png` |
| Kogus | Ribelli | Kayn | - | Niconi | `assets/carte/scansioni/ribelli_09_fronte.webp` | `assets/pedine/pg_kogus.jpg` | `ritratti/pg_kogus.png`, `pedine/pg_kogus.png`, `pedine/pg_kogus_r.png` |
| Doctor Sontag | Ribelli | Rhone | - | Orlog | `assets/carte/scansioni/ribelli_08_fronte.webp` | `assets/pedine/pg_doctor_sontag.jpg` | `ritratti/pg_doctor_sontag.png`, `pedine/pg_doctor_sontag.png`, `pedine/pg_doctor_sontag_r.png` |
| Scott Rubel | Ribelli | Rhone | - | Adrax | `assets/carte/scansioni/ribelli_07_fronte.webp` | `assets/pedine/pg_scott_rubel.jpg` | `ritratti/pg_scott_rubel.png`, `pedine/pg_scott_rubel.png`, `pedine/pg_scott_rubel_r.png` |
| Boccanegra | Ribelli | Piorad | - | Ayod | `assets/carte/scansioni/ribelli_06_fronte.webp` | `assets/pedine/pg_boccanegra.jpg` | `ritratti/pg_boccanegra.png`, `pedine/pg_boccanegra.png`, `pedine/pg_boccanegra_r.png` |
| Drakir Grebb | Ribelli | Calma | Principe di Suti | Suti | `assets/carte/scansioni/ribelli_05_fronte.webp` | `assets/pedine/pg_drakir_grebb.jpg` | `ritratti/pg_drakir_grebb.png`, `pedine/pg_drakir_grebb.png`, `pedine/pg_drakir_grebb_r.png` |
| Yarro Latac | Ribelli | Theshian | - | Rhexia | `assets/carte/scansioni/ribelli_04_fronte.webp` | `assets/pedine/pg_yarro_latac.jpg` | `ritratti/pg_yarro_latac.png`, `pedine/pg_yarro_latac.png`, `pedine/pg_yarro_latac_r.png` |
| Professor Mareg | Ribelli | Illias | - | Cercis | `assets/carte/scansioni/ribelli_03_fronte.webp` | `assets/pedine/pg_prof_mareg.jpg` | `ritratti/pg_prof_mareg.png`, `pedine/pg_prof_mareg.png`, `pedine/pg_prof_mareg_r.png` |
| Oneste Woada | Ribelli | Henone | - | Horon | `assets/carte/scansioni/ribelli_02_fronte.webp` | `assets/pedine/pg_oneste_woada.jpg` | `ritratti/pg_oneste_woada.png`, `pedine/pg_oneste_woada.png`, `pedine/pg_oneste_woada_r.png` |
| Sidir Ganang | Ribelli | Segunden | - | Bajukai | `assets/carte/scansioni/ribelli_01_fronte.webp` | `assets/pedine/pg_sidir_ganang.jpg` | `ritratti/pg_sidir_ganang.png`, `pedine/pg_sidir_ganang.png`, `pedine/pg_sidir_ganang_r.png` |
| Bridne Murcada | Ribelli | Ursi | - | Lysenda | `assets/carte/scansioni/ribelli_00_fronte.webp` | `assets/pedine/pg_bridne_murcada.jpg` | `ritratti/pg_bridne_murcada.png`, `pedine/pg_bridne_murcada.png`, `pedine/pg_bridne_murcada_r.png` |
| Thysa Kymbo | Impero | Rhone | Principessa di Orlog | Orlog | `assets/carte/scansioni/imperiali_11_fronte.webp` | `assets/pedine/pg_thysa_kymbo.jpg` | `ritratti/pg_thysa_kymbo.png`, `pedine/pg_thysa_kymbo.png`, `pedine/pg_thysa_kymbo_r.png` |
| Barca | Impero | Kayn | - | Kalgar | `assets/carte/scansioni/imperiali_10_fronte.webp` | `assets/pedine/pg_barca.jpg` | `ritratti/pg_barca.png`, `pedine/pg_barca.png`, `pedine/pg_barca_r.png` |
| Saytar | Impero | Charkhan | - | Charkhan | `assets/carte/scansioni/imperiali_09_fronte.webp` | `assets/pedine/pg_saytar.jpg` | `ritratti/pg_saytar.png`, `pedine/pg_saytar.png`, `pedine/pg_saytar_r.png` |
| Telmen | Impero | Rhone | - | Tsipa | `assets/carte/scansioni/imperiali_08_fronte.webp` | `assets/pedine/pg_telmen.jpg` | `ritratti/pg_telmen.png`, `pedine/pg_telmen.png`, `pedine/pg_telmen_r.png` |
| Jon Kidu | Impero | Saurian | Governatore di Chim | Chim, Squamot | `assets/carte/scansioni/imperiali_07_fronte.webp` | `assets/pedine/pg_jon_kidu.jpg` | `ritratti/pg_jon_kidu.png`, `pedine/pg_jon_kidu.png`, `pedine/pg_jon_kidu_r.png` |
| Gelba | Impero | Rhone | Governatore di Trov | Trov, Adrax | `assets/carte/scansioni/imperiali_06_fronte.webp` | `assets/pedine/pg_gelba.jpg` | `ritratti/pg_gelba.png`, `pedine/pg_gelba.png`, `pedine/pg_gelba_r.png` |
| Senator Dermond | Impero | Rhone | - | Diomas | `assets/carte/scansioni/imperiali_05_fronte.webp` | `assets/pedine/pg_dermond.jpg` | `ritratti/pg_dermond.png`, `pedine/pg_dermond.png`, `pedine/pg_dermond_r.png` |
| Redjac | Impero | Rhone | Cavaliere dell'Impero | Magro, Diomas, Orlog | `assets/carte/scansioni/imperiali_04_fronte.webp` | `assets/pedine/pg_redjac.jpg` | `ritratti/pg_redjac.png`, `pedine/pg_redjac.png`, `pedine/pg_redjac_r.png` |
| Jin Voles | Impero | Segunden | Cavaliere dell'Impero | Tiglyf | `assets/carte/scansioni/imperiali_03_fronte.webp` | `assets/pedine/pg_jin_voles.jpg` | `ritratti/pg_jin_voles.png`, `pedine/pg_jin_voles.png`, `pedine/pg_jin_voles_r.png` |
| Vans Ka-Tie-A | Impero | Rhone | Cavaliere dell'Impero | Lonica | `assets/carte/scansioni/imperiali_02_fronte.webp` | `assets/pedine/pg_vans_ka_tie_a.jpg` | `ritratti/pg_vans_ka_tie_a.png`, `pedine/pg_vans_ka_tie_a.png`, `pedine/pg_vans_ka_tie_a_r.png` |
| Els Taroff | Impero | Rhone | Cavaliere dell'Impero | Liomax | `assets/carte/scansioni/imperiali_01_fronte.webp` | `assets/pedine/pg_els_taroff.jpg` | `ritratti/pg_els_taroff.png`, `pedine/pg_els_taroff.png`, `pedine/pg_els_taroff_r.png` |
| Emperor Coreguya | Impero | Rhone | Re di Orlog | Orlog | `assets/carte/scansioni/imperiali_00_fronte.webp` | `assets/pedine/pg_coreguya.jpg` | `ritratti/pg_coreguya.png`, `pedine/pg_coreguya.png`, `pedine/pg_coreguya_r.png` |

### 7.2 Sovrani (12): solo pedine

Gli originali sono in `assets/pedine/<chiave>.jpg` e `<chiave>_r.jpg`: Nam Nhuk (`sovrano_nan_nhuk`), Treb Eyro (`sovrano_treb_eyro`), Megda Sheels (`sovrano_megda_sheels`), Ascaill (`sovrano_ascaill`), Shirofune (`sovrano_shirofune`), Xela Grebb (`sovrano_xela_grebb`), Balgar (`sovrano_balgar`), Odel Hobar (`sovrano_odel_hobar`), Yaldor (`sovrano_yaldor`), Inzenzia III (`sovrano_inzenzia_iii`), Tensok Phi (`sovrano_tensok_phi`), Darb Selesh (`sovrano_darb_selesh`).

### 7.3 Astronavi (10)

| Nr | Astronave | Proprietario | Carta originale | Pedina originale |
|---|---|---|---|---|
| 33 | Explorer (Explorer) | Ly Mantok | `assets/carte/scansioni/possessi_00_fronte.webp` | `assets/pedine/nave_33.jpg` |
| 34 | Galactic Freighter (Cargo Galattico) | - | `assets/carte/scansioni/possessi_01_fronte.webp` | `assets/pedine/nave_34.jpg` |
| 35 | Interstellar Sloop (Sloop Interstellare) | - | `assets/carte/scansioni/possessi_02_fronte.webp` | `assets/pedine/nave_35.jpg` |
| 36 | Planetary Privateer (Corsaro Planetario) | Boccanegra | `assets/carte/scansioni/possessi_03_fronte.webp` | `assets/pedine/nave_36.jpg` |
| 37 | Solar Merchant (Mercante Solare) | Tourag | `assets/carte/scansioni/possessi_04_fronte.webp` | `assets/pedine/nave_37.jpg` |
| 38 | Star Cruiser (Incrociatore Stellare) | - | `assets/carte/scansioni/possessi_05_fronte.webp` | `assets/pedine/nave_38.jpg` |
| 39 | Stellar Courier (Corriere Stellare) | - | `assets/carte/scansioni/possessi_06_fronte.webp` | `assets/pedine/nave_39.jpg` |
| 40 | S-XIII (S-XIII) | - | `assets/carte/scansioni/possessi_07_fronte.webp` | `assets/pedine/nave_40.jpg` |
| - | Astronave imperiale | Cavalieri imperiali | - | `assets/pedine/nave_imperiale.jpg` |
| - | Astronave di Redjac | Redjac | - | `assets/pedine/nave_redjac.jpg` |

### 7.4 Unità militari

Le nuove pedine devono avere **la stessa composizione** delle originali: simbolo dell'unità al centro, area libera in basso dove il gioco scrive i valori. Nessun numero nell'immagine.

- **Impero**:
  - pedine: `imp_milizia`, `imp_pattuglia`, `imp_linea`, `imp_veterano`, `imp_elite_esercito`, `imp_elite_flotta`, `imp_squadra_suicida`;
  - unità Atrocità: `imp_resolution`, `imp_peacemaker`, `imp_stabilizzatore`. Queste sono grandi navi da guerra: rendile minacciose ma con le sagome originali.
- **Ribelli**: `rib_<ambiente>_<tipo>` con ambiente in urbano, selvaggio, sotterraneo, liquido, aereo, fuoco e tipo in `10`, `21`, `23`, `43`, `elite`.
  - Il colore di fondo segue l'ambiente (paragrafo 3).
  - Mancano nell'originale e vanno creati nello stesso stile: `rib_fuoco_43`, `rib_sotterraneo_elite`, `rib_liquido_elite`, `rib_aereo_elite`, `rib_fuoco_elite`.

### 7.5 Segnalini

Fronte e retro come gli originali:
- `bdp` (BDP in funzione / fuori uso);
- `lealta` (segnalino Lealtà / Ribellione);
- `campo_ribelle` (Campo ribelle / Colpo di Stato);
- `cr_imp1`, `cr_imp10`, `cr_ribelle10` (crediti dei tracciati delle risorse);
- `fase`, `turno`.

### 7.6 Segreti planetari (17)

Si tratta del segnalino coperto `segreto` più 16 segnalini scoperti `segreto_<chiave>`, con un'illustrazione simbolica senza testo:
- Casino Galactica (`casino`)
- Complesso di clonazione (`clonazione`)
- Mondo morto (`morto`)
- Mondo della droga (`droga`)
- Impero per sempre (`impero`)
- Mondo delle gemme (`gemme`)
- Mondo iperdimensionale (`iper`)
- Archivi imperiali (`archivi`)
- Imperial Deltronics (`deltronics`)
- IPOC (`ipoc`)
- Mondo industriale (`industria`)
- Pianeta vivente (`vivo`)
- Mondo mutante (`mutanti`)
- Mondo degli schiavi (`schiavi`)
- Trappola! (`trappola`)
- Benvenuti Ribelli (`benvenuti`)

Le descrizioni sono in `data/regole_avanzate.json` (chiave `segreti`).

### 7.7 Carte

Il gioco ricompone le carte in italiano da solo: servono **cornici e fondi senza testo**, uno per tipo, con le aree dei testi negli stessi punti dell'originale.

- `cornice_ribelli`, `cornice_imperiali`: c'è il riquadro per il ritratto, che arriva dal paragrafo 7.1.
- `cornice_possessi`, `cornice_missione`, `cornice_azione` (con le tre sezioni Urbano, Selvaggio e Speciale), `cornice_evento`, `cornice_strategico`.
- Un retro per ogni tipo, ispirato al retro originale.
- Per ogni possesso che nell'originale ha un disegno, produci anche `assets_reborn/carte/illustrazioni/possessi_<nn>.png` (768×512). Stesso oggetto e stessa forma, resa migliore.

### 7.8 Mappa della galassia e pianeti

- **Mappa**:
  - 3874×2844, `assets_reborn/mappa/galassia.png`;
  - **stelle, rotte, confini delle province e caselle d'orbita esattamente nelle stesse coordinate** dell'originale: il gioco usa i valori `x`, `y`, `x_orbita`, `y_orbita` di `data/galassia.json`;
  - nebulose e sfondo nuovi; niente testo stampato (i nomi li scrive il gioco).
- **Pianeti**: per l'aspetto, parti dagli ambienti. Il colore e il terreno prevalenti vengono dal primo ambiente, gli altri compaiono come zone o bande:
  - Urbano: città e luci notturne;
  - Selvaggio: foreste e pianure;
  - Sotterraneo: crateri e roccia;
  - Liquido: oceani;
  - Aereo: atmosfera densa a bande;
  - Fuoco: lava.
- Il pianeta del Trono, Orlog (162), deve essere il più imponente.

| Pianeta | Sistema | Stato | Ambienti (tipo, razze) |
|---|---|---|---|
| 111 Mimulus | Tardyn 11 | Kayns | selvaggio (Kayns) |
| 112 Magro | Tardyn 11 | - | urbano (Rhones); aereo (Yesters) |
| 113 Fliad | Tardyn 11 | secret | liquido (Suvans); selvaggio (Urgaks) |
| 121 Kalgar | Uracus 12 | - | sotterraneo (Kayns, Saurians) |
| 122 Bajukai | Uracus 12 | Segundens | urbano (Segundens); liquido (Segundens); selvaggio (Borks) |
| 131 Tiglyf | Zamorax 13 | secret | urbano (Segundens) |
| 141 Ownex | Atriard 14 | - | sotterraneo (Piorads) |
| 142 Adare | Atriard 14 | - | urbano (Rhones); selvaggio (Rhones) |
| 143 Mitrith | Atriard 14 | secret | fuoco (Xanthons); selvaggio (Saurians) |
| 151 Jura | Bex 15 | - | urbano (Saurians, Rhones); aereo (Anons) |
| 152 Diomas | Bex 15 | capital | urbano (Rhones); selvaggio (Rhones) |
| 161 Liomax | Osirius 16 | - | selvaggio (Rhones) |
| 162 Orlog | Osirius 16 | throne | urbano (Rhones); sotterraneo (Rhones); selvaggio (Rhones) |
| 163 Icid | Osirius 16 | - | selvaggio (Saurians) |
| 211 Cieson | Phisaria 21 | Yesters | aereo (Yesters) |
| 212 Etreg | Phisaria 21 | secret | urbano (Ultraks); selvaggio (Kayns) |
| 221 Quibron | Egrix 22 | secret | selvaggio (Saurians) |
| 222 Angoff | Egrix 22 | secret | urbano (Yesters) |
| 223 Charkhan | Egrix 22 | - | aereo (Yesters); selvaggio (Charkhans) |
| 231 Pronox | Ancore 23 | - | urbano (Rhones); aereo (Yesters) |
| 232 Lysenda | Ancore 23 | - | urbano (Segundens, Piorads); sotterraneo (Piorads); selvaggio (Ursi) |
| 241 Orning | Gellas 24 | capital | liquido (Suvans); selvaggio (Rhones) |
| 311 Chim | Pycius 31 | capital | urbano (Rhones); selvaggio (Mowevs) |
| 312 Tamset | Pycius 31 | secret | aereo (Yesters); selvaggio (Kirts) |
| 321 Unarpha | Ribex 32 | Saurians | urbano (Saurians) |
| 322 Suti | Ribex 32 | - | sotterraneo (Calmas); selvaggio (Moghas) |
| 323 Tsipa | Ribex 32 | - | urbano (Rhones); selvaggio (Rhones) |
| 331 Squamot | Rorth 33 | secret | urbano (Saurians) |
| 341 Midest | Aziza 34 | secret | liquido (Suvans); selvaggio (Deaxins) |
| 342 Akubera | Aziza 34 | - | urbano (Suvans, Rhones); liquido (Suvans); sotterraneo (Rylians) |
| 351 Mrane | Luine 35 | Suvans | liquido (Suvans) |
| 352 Kelta | Luine 35 | secret | selvaggio (Saurians) |
| 411 Troliso | Erwind 41 | capital | urbano (Rhones) |
| 412 Heliax | Erwind 41 | - | liquido (Phans); selvaggio (Leonids) |
| 421 Lonica | Wex 42 | - | urbano (Segundens, Rhones); selvaggio (Rhones) |
| 431 Horon | Varu 43 | - | liquido (Henones) |
| 432 Solvia | Varu 43 | - | urbano (Susperans); sotterraneo (Piorads); selvaggio (Thoks) |
| 433 Cercis | Varu 43 | - | sotterraneo (Piorads); selvaggio (Illias) |
| 441 Rhexia | Deblon 44 | - | selvaggio (Theshians) |
| 442 Tartio | Deblon 44 | secret | urbano (Piorads); sotterraneo (Piorads) |
| 451 Ayod | Martigna 45 | Piorads | sotterraneo (Piorads) |
| 511 Barak | Zakir 51 | - | urbano (Jopers) |
| 512 Liatris | Zakir 51 | secret | selvaggio (Ardorats) |
| 513 Xan | Zakir 51 | Xanthons | urbano (Ornotins); fuoco (Xanthons) |
| 521 Aras | Eudox 52 | secret | urbano (Segundens) |
| 522 Capilax | Eudox 52 | secret | fuoco (Xanthons) |
| 523 Adrax | Eudox 52 | - | sotterraneo (Rhones); selvaggio (Rhones) |
| 531 Scythia | Corusa 53 | secret | fuoco (Xanthons) |
| 541 Anell | Irajeba 54 | secret | aereo (Cavalkus) |
| 542 Trov | Irajeba 54 | capital | urbano (Rhones); selvaggio (Rhones) |
| 551 Niconi | Moda 55 | - | selvaggio (Kayns) |

### 7.9 Interfaccia

- **Sfondo del menu**: 1920×1080, `assets_reborn/misc/sfondo_menu.png`. Un campo stellare con una nebulosa, lasciando libero il centro per il titolo.
- **Icona**: `assets_reborn/misc/icona.png`.

## 8. Controllo di ogni immagine (tutto deve essere «sì»)

- [ ] Messa accanto all'originale, una persona che conosce il gioco la riconosce subito?
- [ ] Razza, viso, capelli, abiti, oggetti e posa sono quelli dell'originale?
- [ ] Non c'è nessun testo, numero o lettera nell'immagine?
- [ ] Non c'è nessun elemento riconoscibile di *Star Wars* o di altre opere protette?
- [ ] Rimpicciolita a 48 px (pedine) o a 120 px (ritratti) si capisce ancora chi è?
- [ ] Stile, luce e palette sono coerenti con le immagini già approvate?
- [ ] Nome del file e dimensioni sono quelli del paragrafo 6?

## 9. Manifest

Tieni aggiornato `reborn/manifest.json`, con una voce per file:

```json
{"file": "assets_reborn/pedine/pg_kogus.png", "originale": "assets/pedine/pg_kogus.jpg",
  "scheda": "reborn/schede/pg_kogus.md", "confronto": "reborn/confronti/pg_kogus.png", "stato": "da_approvare"}
```

Valori di `stato`: `da_approvare`, `approvato`, `da_rifare`.

## 10. Ordine di lavoro

1. Tre ritratti di prova (Zina Adora, Redjac, Kogus), con le loro schede e i confronti. **Fermati e attendi l'approvazione di Stefano.**
2. Gli altri 29 personaggi: ritratti, poi pedine, poi fogli Meshy.
3. Astronavi e sovrani.
4. Unità militari, segnalini e segreti planetari.
5. Cornici e retro delle carte, illustrazioni dei possessi.
6. Pianeti e stelle.
7. Mappa della galassia, sfondo del menu e icona.

Alla fine di ogni blocco fai un commit con un messaggio in italiano, senza `[pubblica]` (quel tag avvia la pubblicazione del sito). Scrivi in `reborn/LEGGIMI.md` cosa è stato fatto e cosa resta.
