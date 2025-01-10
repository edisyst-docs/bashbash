# VIM

* https://vim.rtorr.com/lang/it (VIM CHEAT SHEET)
* https://docs.oracle.com/cd/E19620-01/802-7642/6ib8ghcli/index.html
* https://docs.oracle.com/cd/E19620-01/802-7642/6ib8ghcla/index.html
* https://docs.oracle.com/cd/E19620-01/802-7642/6ib8ghclk/index.html (leggi qui per COPY, MOVE, DELETE DI INTERE RIGHE)
* https://docs.oracle.com/cd/E19620-01/802-7642/6ib8ghclm/index.html (leggi qui per RICERCA con lo SLASH)

Editor modale = 4 modalità su VIM

```bash
sudo visudo                     # apre il file sudoers con l'editor di default: magari non è VIM
echo $EDITOR                    # editor di default dell'utente => potrebbe essere vuota
sudo EDITOR="/bin/vim" visudo   # imposto temporaneamente VIM come editor di default
file /etc/alternatives/editor   # indica il simlink all'editor di default (di solito nano)
sudo ln -s /usr/bin/vi /etc/alternatives/editor # così imposto VIM come editor di default
```



# Normal Mode
- ripetere/annullare l'ultima operazione
 
Ci torno sempre facendo `ESC`.  
In generale `N comando` esegue il comando N volte: `10 dd` taglia 10 righe, `10 P` incolla 10 volte

**Navigazione nel testo** (con le `FRECCE` o coi tasti `HJKL`)
- `gg`: vai a inizio file
- `G` : vai a fine file
-
- `0 (zero)`: vai a inizio riga
- `$`: vai a fine riga
- 
- `50 G` : vai alla riga 50
- `: 50` : UGUALE (come in **Command Mode**), forse anche più comodo
- `10 ENTER/FRECCIA_GIU`: vai avanti di 10 righe
- `10 SPAZIO/FRECCIA_DX`: vai avanti di 10 lettere
-
- `b(egin)` e `w(ord)`: vai alla **parola** precedente/successiva
- `(` e `)`: vai alla **frase** precedente/successiva (li identifica con un punto di chiusura) 
- `{` e `}`: vai al **paragrafo** precedente/successivo
- 
- `f(ind)`: cerca il carattere. fZ cerca "Z" `verso avanti`
- `F(ind)`: cerca il carattere. Fi cerca "i" `verso indietro`
- 
- `/ciao`   : cerca "ciao" `verso avanti`
- `n` e `N` : cerca il "ciao" successivo/precedente
- `?ciao`   : cerca "ciao" `verso indietro`. `N` e `n` cambiano verso di ricerca

**Copia e incolla testo** senza entrare in INSERT MODE
- `y(ank)`: copia. ES: `yft` copia dal cursore fino alla prossima t
- `yy`: copia l'intera riga
- 
- `p(aste)`: incolla dal carattere dopo il cursore o nella riga sotto (in caso di `yy`)
- `P`: incolla dal carattere del cursore o nella riga sopra (in caso di `yy`)
- 
- `x`: cancella il carattere dove si trova il cursore. Come `CANC` in un testo classico
- `X`: cancella il carattere prima del cursore. Come `BACKSPACE` in un testo classico
- 
- `d`: taglia. ES: `dfT` taglia dal cursore fino alla prossima T
- `D`: taglia dal cursore fino a fine riga
- `dd`: taglia l'intera riga
- 
- `r(eplace)`: replace carattere corrente. ES: `rT` sostituisce il carattere sul cursore con una T
- `R`: entro in replace mode. Da questo momento se scrivo, sostituisco il testo dove ho il cursore
- 
- `u(ndo)`: è come fare CTRL+Z in un testo classico
- `CTRL+r`: è come fare CTRL+Y in un testo classico

Comandi intuitivi
- `PagUp e PagDn` per spostarmi di pagina
- `SCROLL MOUSE` su e giù tra le righe

Altri comandi di navigazione meno importanti
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



# Insert Mode
Inserimento, Copia, Taglia, Incolla
- `i(nsert)`: inserisco a partire dal carattere sul cursore
- `a(ppend)`: inserisco a partire dal carattere dopo il cursore 
- `I`: inserisco a inizio riga
- `A`: inserisco a fine riga
- 
- `o(pen)`: aggiungo una riga sotto e mi mette in insert
- `O`: aggiungo una riga sopra e mi mette in insert
- 
- `s`: cancella il carattere del cursore e mi mette in insert
- 
- `c(change)`: taglia e mi mette in insert. ES: `cfL` cancella il testo fino a `L` e da lì posso scrivere il testo sostitutivo
- `cc`: taglia l'intera riga, mi mette in insert e mi permette di scrivere di nuovo su quella riga svuotata



# Replace Mode
- premo `R` per entrarci
- da questo momento se scrivo, sostituisco il testo dove ho il cursore
- posso muovermi con le `frecce` nel testo ma se digito lettere le sostituisco dove ho il cursose



# Command Mode
Per uscire da Vim e salvare. Premo sempre i `:` per entrarci
- `:set number` e `:set nonumber` (mostra/nasconde i numeri di riga)
- `:156` (vai alla riga 156)
- 
- `s/vecchio/nuovo`    (sostituisce la prima occorrenza di "vecchio" con "nuovo" nella riga corrente)
- `s/vecchio/nuovo/g`  (sostituisce globalmente "vecchio" con "nuovo" nella riga corrente)
- `%s/vecchio/nuovo`   (sostituisce la prima occorrenza di "vecchio" con "nuovo" in ogni riga del file)
- `%s/vecchio/nuovo/g` (sostituisce globalmente "vecchio" con "nuovo" in tutto il file)
- `%s/vecchio/nuovo/gc`(UGUALE ma chiede conferma per ogni occorrenza)
- 
- `:q!`  (esci senza salvare)
- `:w`   (salva)
- `:X`   (cifra - chiederà una password)
- `:wq`  (salva ed esci)



# Visual Mode
Seleziona il testo per copiarlo (`y`) tagliarlo (`d`) incollarvi qualcosa al suo posto (`p`)
- premo `v` per entrarci
- da questo momento muovendomi con le `frecce` seleziono il testo
