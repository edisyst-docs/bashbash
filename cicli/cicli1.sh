
#declare -i a=0
#declare -i b=10
#while test $a -lt $b
#do
#  echo "Valore variabile a: "$a
#  (( a++ ))
#done

#declare -i a=0
#declare -i b=10
#until test $a -eq $b
#do
#  echo "Valore variabile a: "$a
#  (( a++ ))
#done

#IFS=";"
a="ciao come va"
for var in "ciao come va"
do
    echo $var
done