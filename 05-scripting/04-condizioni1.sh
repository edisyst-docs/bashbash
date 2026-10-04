# Esistono 3 sintassi per descrivere la condizione

# VERIFICA SE E' UNA DIRECTORY ESISTENTE
if test -d cartellau
then
    echo "successo"
else
    echo "falso"
fi

# VERIFICA SE UN PATH (file, cartella) ESISTE
#if [[ -e "./s.sh" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA SE E' UN FILE REGOLARE (file, link a file)
#if [[ -f "./s.sh" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA SE E' UN link simbolico
#if [ -h "./link1" ]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA SE E' UN FILE NON VUOTO
#if test -s "s.sh"
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA CON STRINGHE
#if test "ciao" = "ciao"
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA CON STRINGHE 2
#if [[ "ciao" == "Ciao" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA CON STRINGHE 3
#a="pippo"
#b="pippo"
#if [[ "$a" == "$b" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA STRINGHE DIVERSE
#a="a"
#b="b"
#if [[ "$a" < "$b" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA STRINGA VUOTA
#if [[ -z "" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA STRINGA NON VUOTA
#if [[ -n "" ]] # oppure if [[ "" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi

# VERIFICA STRINGA CON REGEX
#if [[ "ciao come stai" =~ "come" ]]
#then
#    echo "successo"
#else
#    echo "falso"
#fi
