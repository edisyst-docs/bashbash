#!/bin/bash

echo "" > conta.txt

while(true)
  do
  let "contatore++"
  echo $contatore >> conta.txt
  sleep 5
done
