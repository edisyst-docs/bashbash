https://www.youtube.com/watch?v=fPii79dBQqY&list=PL4L8OWDC99_c1pppqEyT3FXuBPDI3Qx4F

https://regex101.com/  
https://regexr.com/

Se digito `man regex` vedo il manuale di regex su Linux

Utili da usare con SED e con GREP. Posso far dei test digitando `grep "pattern"` poi lui resta in ascolto di ciò che digito

Si distinguono in BRE (BASIC REGULAR EXPRESSION) e ERE (EXTENDED REGULAR EXPRESSION, BRE estese)
> NOTA: per usare le ERE devo usare con `grep -E` o `sed -E`



# PUNTI IN COMUNE TRA BRE E ERE

## PUNTATORI
- `^` => inizio riga
    - `^W` => cerca tutte le righe che iniziano per W
- `$` => fine riga
    - `.$` => cerca tutte le righe che finiscono con un carattere qualsiasi (escluso lo spazio)

## METACARATTERI (caratteri con un significato speciale)
- `.` => QUALSIASI CARATTERE (A PARTE IL NEWLINE)
- `.*` => QUALSIASI SEQUENZA DI CARATTERI (COMBINO . E *)
- 
- `[abc]`  => QUALSIASI CARATTERE dentro le []
- `[^abc]` => OPPOSTO: QUALSIASI CARATTERE TRANNE QUELLI dentro le []
- 
- `\<co` => cerca le righe contenenti parole che iniziano per "co"
- `do\>` => cerca le righe contenenti parole che finiscono per "do"
- `\<scopo\>` => cerca le righe contenenti l'esatta parola "scopo"
- 
- `\` => carattere di ESCAPE
- Le backreferences si indicano con \1, \2, ecc.



# BRE: BASIC REGULAR EXPRESSION

## METACARATTERI: $ ^ . * [ ] \( \) \> \<
- `\(` e `\)` le uso unicamente per gestire le precedenze (tipo le formule matematiche)
- `\|` => OR logico. Esempio: `\(ciao\|hello\)` => matcha "ciao" o "hello"

## MODIFICATORI
- `\?` => 0,1 OCCORRENZE DELL'ELEMENTO PRECEDENTE (QUALSIASI CARATTERE)
- `*`  => 0,N OCCORRENZE DELL'ELEMENTO PRECEDENTE (QUALSIASI STRINGA, ANCHE VUOTA)
- `\+` => 1,N OCCORRENZE DELL'ELEMENTO PRECEDENTE
- 
- `\{2\}`   => ESATTAMENTE 2 OCCORRENZE DELL'ELEMENTO PRECEDENTE
- `\{2,\}`  => DA 2 OCCORRENZE DELL'ELEMENTO PRECEDENTE IN SU
- `\{2,7\}` => DA 2 A 7 OCCORRENZE DELL'ELEMENTO PRECEDENTE

## ESEMPI
ciao          => matcha unicamente "ciao"
[Cc]iao       => matcha "ciao" e "Ciao"
[.aeiou]      => cerca tutte le vocali e il punto
[0-9]         => cerca tutti i numeri, equivale a [0123456789]
[a-z]         => cerca tutte le lettere minuscole
[a-z] | [A-Z] => cerca tutte le lettere minuscole o maiuscole
[A-Z] [a-z]+  => cerca tutte le parole che iniziano per una MAIUSCOLA
[A-Z] [a-z]*  => così prenderebbe anche le SIGLE tutte maiuscole
[^e]          => cerca tutto tranne la lettera "e"
[^L]inux      => cerca tutto tranne la parola "Linux"
[^0-9]        => cerca tutto tranne i numeri
[^aeiou ]     => esclude le vocali minuscole, e gli SPAZI (è un carattere anche lo spazio)

([Cc]iao)|(colou*r)  => OR tra due pattern (basta che matchi 1 dei 2)

```bash
cat crontab | grep '^#'      # stampa tutte le righe che iniziano per #
cat crontab | grep -v '^#'   # stampa tutte le righe che NON iniziano per #
cat crontab | grep ')$'      # stampa tutte le righe che finiscono con )
```



# ERE: EXTENDED REGULAR EXPRESSION (BRE estese)

## METACARATTERI (sono diversi e di più): $ ^ . * [ ] ( ) { } \> \< ? | ,
- `(` e `)` sempre per gestire le precedenze (come nelle BRE solo che non hanno il backlask davanti)
- `|` => OR logico. Esempio: `(ciao|hello)` => matcha "ciao" o "hello"

## MODIFICATORI (gli stessi delle BRE ma senza bisogno del BACKSLASH)
- `?` => 0,1 OCCORRENZE DELL'ELEMENTO PRECEDENTE (QUALSIASI CARATTERE)
- `*` => 0,N OCCORRENZE DELL'ELEMENTO PRECEDENTE (QUALSIASI STRINGA, ANCHE VUOTA)
- `+` => 1,N OCCORRENZE DELL'ELEMENTO PRECEDENTE (QUALSIASI STRINGA)
- 
- `{2}`   => ESATTAMENTE 2 OCCORRENZE DELL'ELEMENTO PRECEDENTE
- `{2,}`  => DA 2 OCCORRENZE DELL'ELEMENTO PRECEDENTE IN SU
- `{2,7}` => DA 2 A 7 OCCORRENZE DELL'ELEMENTO PRECEDENTE

## ESEMPI
```bash
# Trovare numeri di telefono con grep -E
grep -E '\b[0-9]{3}-[0-9]{3}-[0-9]{4}\b' contatti.txt

# Sostituire estensioni .html con .php con sed
sed -E 's/\.html$/.php/' file.txt

# Ottenere solo indirizzi email validi
grep -E '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$' utenti.txt
```
