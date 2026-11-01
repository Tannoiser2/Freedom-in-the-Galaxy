extends Control
## Riassunto delle regole dello Star System Game in italiano.

signal chiudi

var main
var in_partita := false

const TESTO := """[font_size=30][color=#f5c738][b]FREEDOM IN THE GALAXY — STAR SYSTEM GAME[/b][/color][/font_size]

Una manciata di eroi ribelli prova a sollevare i pianeti di un sistema stellare contro l'Impero. I [color=#e2513a]Ribelli[/color] vincono portando i pianeti in Agitazione, in Ribellione e infine sotto il proprio controllo; l'[color=#f5bd33]Impero[/color] vince dando la caccia ai Ribelli e riportando la popolazione alla fedeltà. Si gioca contro l'IA (con l'una o l'altra parte), in due sullo stesso schermo oppure online.

[font_size=22][color=#5cc8f5][b]Il turno[/b][/color][/font_size]
Ogni turno di gioco è un mese. Prima giocano i Ribelli, poi l'Impero; ognuno nel proprio turno:
[b]1. Movimento.[/b] I personaggi si spostano a piedi da un ambiente all'altro dello stesso pianeta, oppure in astronave verso qualsiasi ambiente del sistema. Le truppe mobili (Pattuglie, Linee, unità ribelli 2-1) possono cambiare pianeta; le Milizie e le unità 1-0 restano sul loro. Alla fine si decide quali personaggi restano con le truppe (comandano, non fanno missioni, non possono essere cercati).
[b]2. Reazione nemica.[/b] L'avversario può spostare, dallo stesso pianeta, un personaggio o una truppa (con un comandante) in ogni ambiente dove ci sono truppe o personaggi individuati di chi è di turno.
[b]3. Combattimento militare.[/b] Dove ci sono truppe delle due parti, prima chi è di turno e poi l'avversario può dichiarare battaglia.
[b]4. Ricerca.[/b] L'avversario cerca i personaggi individuati con le sue truppe e/o con i suoi personaggi; se li trova può attaccarli per ucciderli o catturarli.
[b]5. Missioni.[/b] In ogni ambiente i personaggi liberi formano Gruppi di Missione e peschiamo carte Azione.

[font_size=22][color=#5cc8f5][b]Rilevamento e BDP[/b][/color][/font_size]
Ogni pianeta ha una Base di Difesa Planetaria (BDP) di livello 0, 1 o 2, utilizzabile solo da chi controlla il pianeta e solo se è in funzione. Un'astronave che parte, arriva o vola fra gli ambienti di un pianeta nemico subisce il rilevamento: valore di evasione = Navigazione del pilota + Manovra della nave (nessuno dei due può superare l'altro di più di uno). Esiti: non individuata, individuata, individuata e danneggiata (la nave è perduta all'arrivo), distrutta con tutti a bordo. Un BDP di livello 1 o 2 spara anche sulle truppe che lasciano o raggiungono il pianeta.

[font_size=22][color=#5cc8f5][b]Combattimenti[/b][/color][/font_size]
[b]Militare:[/b] rapporto fra le forze arrotondato a favore del difensore; ogni punto di Comando del comandante sposta di una colonna; le truppe ribelli nel proprio tipo di ambiente e gli Imperiali negli ambienti speciali (Sotterraneo, Liquido, Aereo, Fuoco) senza comandante danno uno spostamento ai Ribelli. Ognuno tira per le perdite dell'altro; si eliminano unità senza mai superare la perdita.
[b]Fra personaggi:[/b] la differenza fra la forza attaccante e il Combattimento dei difensori attivi dà la colonna. Ogni ferita toglie un punto di Combattimento e di Resistenza; a Resistenza zero il personaggio muore. Lo scontro a fuoco raddoppia i risultati. Chi difende può tentare lo sganciamento; chi attacca può combattere per catturare (due colonne a sinistra, l'asterisco cattura un difensore).

[font_size=22][color=#5cc8f5][b]Missioni e carte Azione[/b][/color][/font_size]
Si pescano tante carte quanto la taglia dell'ambiente, una alla volta: prima si applica l'evento della sezione dell'ambiente (Urbano, Selvaggio o Speciale), poi se compare la lettera della missione questa riesce. Si può smettere prima, ma solo chi pesca tutte le carte ha diritto alle pescate bonus (dalla carta Missione, dalle abilità dei personaggi e dai possessi), che ignorano gli eventi. Diplomazia, Colpo di Stato, Liberare prigionieri, Raccogliere informazioni, Sabotaggio e Sovvertire truppe migliorano con più lettere: si può continuare a pescare, rischiando che la missione venga abortita.
Missioni: [b]D[/b] Diplomazia, [b]C[/b] Colpo di Stato, [b]R[/b] Avvia/Ferma Ribellione, [b]B[/b] Campo ribelle, [b]T[/b] Sovvertire truppe, [b]S[/b] Sabotaggio, [b]A[/b] Assassinio, [b]I[/b] Raccogliere informazioni, [b]G[/b] Reclutare personaggi, [b]P[/b] Procurarsi possessi, [b]F[/b] Liberare prigionieri. Il pulsante «Missioni» mostra tutte le carte.

[font_size=22][color=#5cc8f5][b]Lealtà, Ribellione e controllo[/b][/color][/font_size]
La traccia politica va da Patriottico a Agitazione. Solo in Agitazione i Ribelli possono avviare la Ribellione: ricevono Punti Forza pari alle risorse di ogni ambiente (unità 1-0 a un punto, 2-1 a tre punti) e possono attaccare subito. Un pianeta in Ribellione senza truppe imperiali e con il BDP in funzione passa sotto Controllo ribelle alla fine del turno imperiale. L'Impero ferma la ribellione con due lettere R. Chi controlla un pianeta usa il suo BDP e rimette in funzione un BDP fuori uso (Ribelli nei turni dispari, Impero nei pari).

[font_size=22][color=#5cc8f5][b]Vittoria[/b][/color][/font_size]
A fine partita i Ribelli contano i Punti Vittoria: pianeta sotto controllo ribelle 9, in ribellione 6, in Agitazione 3, Patriottico -2; imperiale ucciso +1, catturato +2; ribelle ucciso -1, catturato -2; Raccogliere informazioni con due lettere ±1.
[b]La fuga verso Egrix[/b] (6 turni): i Ribelli vincono subito se un pianeta passa sotto il loro controllo, altrimenti con 12 PV. L'Impero vince subito se tutti i Ribelli cadono e ogni pianeta resta imperiale; riceve una Linea ogni volta che un pianeta insorge.
[b]La polveriera di Varu[/b] (7 turni): Cercis è già ribelle. I Ribelli vincono subito con Cercis e un altro pianeta sotto controllo, altrimenti con 20 PV. L'Impero vince subito con tutti i pianeti imperiali e tre Ribelli caduti; riceve una Linea nei turni 2, 4 e 6 (o una Pattuglia rimettendo in funzione un BDP).

[font_size=22][color=#5cc8f5][b]Comandi[/b][/color][/font_size]
Le decisioni compaiono nel pannello a destra: clicca un'opzione, premi i tasti 1-9 oppure clicca direttamente l'ambiente sulla mappa. Passa il mouse sulle pedine per i dettagli. Le carte in basso sono in italiano; il clic destro mostra la carta originale. «Vista 3D» apre il sistema stellare in tre dimensioni: trascina per ruotare, rotella per lo zoom. «Salva su Firebase» dà un codice per riprendere la partita da qualsiasi dispositivo; sul dispositivo la partita si salva comunque da sola.
"""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var p := UI.pannello(Color(0.04, 0.05, 0.11, 0.97), UI.GIALLO, 2)
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 120
	p.offset_right = -120
	p.offset_top = 40
	p.offset_bottom = -40
	add_child(p)
	var v := VBoxContainer.new()
	p.add_child(v)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.add_theme_font_size_override("bold_font_size", 18)
	rt.text = TESTO
	v.add_child(rt)
	var b := UI.bottone("Chiudi" if in_partita else "Torna al menu", 20)
	b.pressed.connect(func():
		if in_partita:
			chiudi.emit()
		else:
			main.show_menu())
	v.add_child(b)
