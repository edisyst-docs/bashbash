## VIM

Editor modale = 4 modalità su VIM


## Normal Mode
- ripetere/annullare l'ultima operazione
 
Ci torno sempre facendo `ESC`

Navigazione nel testo (con le FRECCE o coi tasti `HJKL`)
- `gg`: vai a inizio file
- `G` : vai a fine file
-
- `0 (zero)`: vai a inizio riga
- `$`: vai a fine riga
- 
- `50G`: vai alla riga 50
- `10 ENTER/FRECCIA_GIU`: vai avanti di 10 righe
- `10 SPAZIO/FRECCIA_DX`: vai avanti di 10 lettere
-
- `w(ord)`: vai alla prossima parola
- `b(egin)`: vai alla parola precedente
- 
- `f(ind)`: cerca il carattere. fZ cerca "Z" `verso avanti`
- `F(ind)`: cerca il carattere. Fi cerca "i" `verso indietro`

Comandi intuitivi
- `PagUp e PagDn` per spostarmi di pagina
- `SCROLL MOUSE` su e giù tra le righe

Altri comandi meno importanti
- `e(nd)`: vai alla fine della prossima parola
- `W`: vai alla prossima parola (delimitata da uno spazio)
- `B`: vai alla parola prima (delimitata da uno spazio)
- `E`: vai alla fine della prossima parola (delimitata da uno spazio)
- `^`: vai al primo carattere non vuoto della riga
- `t(il)` e `T`: funzionano come `f,F` ma ti portano nel carattere subito prima/dopo
- 
- `+ e -` vai su e giù di 1 riga
- `CTRL + u(p), d(own)`: su/giù di 20 righe
- `CTRL + f(orward), b(ackward)`: movimenti verticali nello stesso punto della pagina


## Insert Mode
Inserimento, Copia, Taglia, Incolla
- `i(nsert)`: inserisco a partire dal carattere sul cursore
- `a(ppend)`: inserisco a partire dal carattere dopo il cursore 
- `I`: inserisco a partire dall'inizio della riga
- `A`: inserisco a partire dalla fine della riga
- 
- `o(pen)`: aggiungo una riga sotto
- `O`: aggiungo una riga sopra 
-  
- `y(ank)`: copia. ES: `yft` copia dal cursore fino alla prossima t
- `yy`: copia l'intera riga
- `d`: taglia. ES: `dfT` taglia dal cursore fino alla prossima T
- `dd`: taglia l'intera riga
- `p(ut)`: incolla dal carattere dopo il cursore
- `P`: incolla dal carattere del cursore
- 
- `c(change)`: taglia e mi mette in insert. ES: `cfL` cancella il testo fino a `L` e da lì posso scrivere il testo sostitutivo
- `cc`: taglia l'intera riga, mi mette in insert e mi permette di scrivere di nuovo su quella riga svuotata


## Command Mode
Per uscire da Vim e salvare. Premo sempre i `:` per entrarci
- `:set number` (mostra i nr. di riga)
- `:q` (esci senza salvare)
- `:w` (salva)
- `:wq` (salva ed esci)
- `:156` (vado alla riga 156)


## Visual Mode
Seleziona il testo per copiarlo (`y`) tagliarlo (`d`) incollarvi qualcosa al suo posto (`p`)
- premo `v` per entrarci
- da questo momento muovendomi con le `frecce` seleziono il testo


