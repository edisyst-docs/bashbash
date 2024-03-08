# VERIFICA NUMERI UGUALI
#declare -i a=10
#declare -i b=20
#if test $a -eq $b
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA NUMERI NON UGUALI
#declare -i a=10
#declare -i b=20
#if test $a -ne $b
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# CONFRONTO FRA NUMERI
# -gt GREATER THAN
# -lt LESS THAN
# -ge GREATER EQUAL >=
# -le LESS EQUAL <=
#declare -i a=10
#declare -i b=20
#if test $a -gt $b
#then
#    echo "successo"
#else
#    echo "falso"
#fi


# CONFRONTO FRA STRINGHE
#a="stringa"
#b="stringa"
#if [[ $a == $b ]]
#then
#    echo "sono uguali"
#else
#    echo "falso"
#fi


# ELIF
#declare -i a=100
#if [[ "$a" -gt 50  ]]
#then
#    echo "maggiore di 50"
#elif [[ "$a" -gt 40  ]]
#then
#    echo "maggiore di 40"
#elif [[ "$a" -gt 30  ]]
#then
#    echo "maggiore di 30"
#else
#    echo "minore di 30"
#fi

# PATTERN MATCHING NEL CASE (FUNZIONA COME LO SWITCH IN C++)
variabile="stringa"
case $variabile in
  str*a)
    echo "match uno"
    ;; # equivale al BREAK
  g*o | [pes]*e | "cane") # virgolette facoltative
    echo "match due"
    ;;
  *)
    echo "match default"
    ;;
esac


