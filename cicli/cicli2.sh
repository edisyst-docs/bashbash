#!/bin/bash

PS3="Scegli un'opzione: "

select vardir in $(ls ../zz_esempi );
do
  if [ -e $vardir ] && [ -d $vardir ] && [ -x $vardir ];
    then
      cd $vardir
      echo "Hai scelto la directory: "$vardir
      ls
      break
  else
    echo $vardir "non hai scelto una directory valida"
  fi
done
