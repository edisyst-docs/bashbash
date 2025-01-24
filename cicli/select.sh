#!/bin/bash

#PS3="Scegli un'opzione: "
#dirs=$(ls -d ../zz_esempi/*/)
#select vardir in $dirs;
#do
#  if [[ -e $vardir  &&  -d $vardir  &&  -x $vardir ]];
#    then
#      cd "$vardir" || exit 1
#      echo "Hai scelto la directory: "$vardir
#      ls
#      break
#  else
#    echo $vardir "non hai scelto una directory valida"
#  fi
#done


#echo "Seleziona un'opzione:"
#select option in "Opzione 1" "Opzione 2" "Esci"; do
#    case $REPLY in
#        1)
#            echo "Hai selezionato Opzione 1"
#            ;;
#        2)
#            echo "Hai selezionato Opzione 2"
#            ;;
#        3)
#            echo "Uscita dal menu"
#            break
#            ;;
#        *)
#            echo "Scelta non valida. Riprova."
#            ;;
#    esac
#done



PS3="Scegli un'opzione (1-3): "  # Cambia il prompt di default
options=("Crea file" "Elenca file" "Esci")
select opt in "${options[@]}"; do
    if [[ -n $opt ]]; then
        case $REPLY in
            1)
                echo "Inserisci il nome del file:"
                read filename
                touch "$filename"
                echo "File $filename creato."
                ;;
            2)
                echo "File nella directory corrente:"
                ls
                ;;
            3)
                echo "Uscita."
                break
                ;;
            *)
                echo "Scelta non valida."
                ;;
        esac
    else
        echo "Opzione non valida, riprova."
    fi
done



#PS3="Scegli un'opzione: "
#main_menu=("Gestisci file" "Gestisci cartelle" "Esci")
#
#select main_option in "${main_menu[@]}"; do
#    case $main_option in
#        "Gestisci file")
#            file_menu=("Crea file" "Elimina file" "Indietro")
#            select file_option in "${file_menu[@]}"; do
#                case $file_option in
#                    "Crea file")
#                        echo "Inserisci il nome del file:"
#                        read filename
#                        touch "$filename"
#                        echo "File $filename creato."
#                        ;;
#                    "Elimina file")
#                        echo "Inserisci il nome del file da eliminare:"
#                        read filename
#                        rm -f "$filename" && echo "File $filename eliminato." || echo "Errore: File non trovato."
#                        ;;
#                    "Indietro")
#                        break
#                        ;;
#                    *)
#                        echo "Scelta non valida."
#                        ;;
#                esac
#            done
#            ;;
#        "Gestisci cartelle")
#            echo "Funzionalità cartelle in sviluppo..."
#            ;;
#        "Esci")
#            echo "Uscita."
#            break
#            ;;
#        *)
#            echo "Scelta non valida."
#            ;;
#    esac
#done


