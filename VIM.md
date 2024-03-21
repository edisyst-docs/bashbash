# VIM

Editor modale = 4 modalità su VIM

## Normal Mode
  - ci torno sempre facendo "ESC"
  - navigo nel testo (con le FRECCE o con HJKL)
    - G : vado a fine file
    - gg: torno a inizio file
	- 50G: vai alla riga 50
	- 30: scendi di 30 righe
	- + e - per spostarmi su e giù di 1 riga
	- PagUp e PagDn per spostarmi di pagina
	- Mov.Vert.: CTRL + F(orward), B(ackward), U(p), D(own)
	- 0 (zero): vai a inizio riga
	- $: vai a fine riga
	- ^: vai al primo carattere non vuoto della riga
	- w(ord): vai alla prossima parola
	- W: vai alla prossima parola (delimitata da uno spazio)
	- b(egin): vai alla parola prima
	- B: vai alla parola prima (delimitata da uno spazio)
	- e(nd): vai alla fine della prossima parola
	- E: vai alla fine della prossima parola (delimitata da uno spazio)	
	- f(ind): cerca il carattere. fO cerca "O" in avanti
	- F: cerca il carattere. fi cerca "i" in indietro
	- t(il) e T: funzionano come f,F ma ti portano nel carattere subito prima/dopo
	
  - copia&incolla
  - ripetere/annullare l'ultima operazione

## Insert Mode
  - i: inserisco a partire dal carattere sul cursore
  - a(ppend): inserisco a partire dal carattere dopo il cursore 
  - I: inserisco a partire dall'inizio della riga
  - A: inserisco a partire dalla fine della riga
  - o(pen): aggiungo una riga sotto
  - O: aggiungo una riga sopra
  - y: copia. ES: pft copia dal cursore fino alla prossima t
  - yy: copia l'intera riga
  - d: taglia. ES: dfT taglia dal cursore fino alla prossima T
  - dd: taglia l'intera riga
  - p(ut): incolla dal carattere dopo il cursore
  - P: incolla dal carattere del cursore
  - c(change): taglia e sostituisce (mi mette in insert). ES: ctL cancella il testo fino a "L" e da lì posso scrivere il testo sostitutivo
  - cc: taglia l'intera riga, mi mette in insert e mi permette di scrivere di nuovo su quella riga

## Command Mode
  - premo ":" per entrarci
  - :set number (mostra i nr. di riga)
  - :156 (vado alla riga 156)
  -:w (salva)
  -:wq (salva ed esci)

  - trova&sostituisci, apri altri file, esci

## Visual Mode
  - premo "v" per entrarci
  - seleziono del testo muovendomi con le frecce






