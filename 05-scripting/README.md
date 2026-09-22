# 05 - Scripting

Scrivere script bash. Lo script di prova porta lo stesso numero del `.md` che lo spiega,
così restano affiancati nell'elenco.

| # | File | Script | Contenuto |
|---|---|---|---|
| 01 | [basi scripting](01-basi-scripting.md) | | I 4 modi di lanciare uno script, sottoshell vs shell corrente |
| 02 | [variabili](02-variabili.md) | [02-variabili.sh](02-variabili.sh) | Assegnazione, `declare`, `export`, `unset`, opzioni della shell |
| 03 | [parametri](03-parametri.md) | | `$0`, `$1`, `$#`, `$*`, `$@`, `$$`, `$!`, `$?` |
| 04 | [condizioni](04-condizioni.md) | [04-condizioni1.sh](04-condizioni1.sh) · [04-condizioni2.sh](04-condizioni2.sh) | `test`, `[ ]`, `[[ ]]`, `if`, `case` |
| 05 | [cicli](05-cicli.md) | [05-cicli1.sh](05-cicli1.sh) · [05-select.sh](05-select.sh) | `while`, `until`, `for`, `select`, `IFS` |
| 06 | [array](06-array.md) | [06-array.sh](06-array.sh) | Array indicizzati e associativi |
| 07 | [input e read](07-input-read.md) | [07-read1.sh](07-read1.sh) · [07-read2.sh](07-read2.sh) | `read` e `IFS` |
| 08 | [espansioni](08-espansioni.md) | | Le 9 espansioni della shell, nell'ordine in cui vengono applicate |
| 09 | [altro interprete](09-altro-interprete.md) | [09-altro_interprete.sh](09-altro_interprete.sh) | Shebang e uso di interpreti diversi da bash |

Gli script di questa cartella sono appunti in forma di codice, quasi tutti commentati:
si scommenta il blocco da provare. Per script completi e funzionanti vedi [../zz-esempi/](../zz-esempi/).

Area precedente: [../04-processi/](../04-processi/) · Prossima: [../06-sistema/](../06-sistema/)
