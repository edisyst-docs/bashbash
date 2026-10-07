#!/usr/bin/env bash
# prepara.sh - crea (o ricrea da zero) il laboratorio dell'area 07: i file di 09-active-directory.md
#
# Uso: bash prepara.sh [-q] [CARTELLA]     (default: ~/lab; -q non stampa il riepilogo)
#
# Gira su pc01. I .bat e i .ps1 delle altre note di questa area sono per Windows e qui non si eseguono:
# in questo laboratorio c'è solo Active Directory, con un controller di dominio vero (Samba 4) su dc1.
set -euo pipefail

LAB_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # questa cartella (lab/)
SILENZIOSO=0
[[ ${1:-} == -q ]] && { SILENZIOSO=1; shift; }
DEST="${1:-$HOME/lab}"

# Sicurezza: cancello DEST solo se è un laboratorio creato da questo script (ha il marcatore)
if [[ -e $DEST ]]; then
    [[ -f $DEST/.lab-bashbash ]] || { echo "ERRORE: $DEST esiste e non è un laboratorio: non la tocco" >&2; exit 1; }
    chmod -R u+rwX "$DEST" 2>/dev/null || true
    rm -rf "$DEST"
fi
mkdir -p "$DEST"
touch "$DEST/.lab-bashbash"

sezione() { mkdir -p "$DEST/$1"; cd "$DEST/$1"; }   # crea ed entra nella sottocartella di un .md

# ---------------------------------------------------------------- 09-active-directory
sezione 09-active-directory
# l'elenco di utenti del .md, da creare in blocco
cat > utenti.csv <<'CSV'
nome,cognome,utente,gruppo
Anna,Rossi,anna,contabilita
Marco,Bianchi,marco,contabilita
Luca,Verdi,luca,magazzino
Sara,Neri,sara,magazzino
CSV
cat > crea-utenti.sh <<'SH'
#!/usr/bin/env bash
# crea-utenti.sh - crea in blocco gli utenti di utenti.csv nell'OU "Ufficio", e i gruppi se non esistono
# Uso: ./crea-utenti.sh utenti.csv        (chiede la password dell'amministratore)
set -euo pipefail
DC=ldap://dc1.lab.test
read -rsp "Password di administrator: " PW; echo

while IFS=, read -r nome cognome utente gruppo; do
    samba-tool user create "$utente" "Passw0rd!$utente" --given-name="$nome" --surname="$cognome" \
        --userou="OU=Ufficio" -H "$DC" -U "administrator%$PW" 2> /dev/null && echo "creato $utente"
    samba-tool group addmembers "$gruppo" "$utente" -H "$DC" -U "administrator%$PW" > /dev/null
done < <(tail -n +2 "$1")
SH
chmod +x crea-utenti.sh
# i comandi PowerShell equivalenti (modulo ActiveDirectory di Windows): non eseguibili qui
cat > ad.ps1 <<'PS1'
# I comandi del modulo ActiveDirectory (RSAT) di Windows per le stesse operazioni del .md.
# NON sono eseguibili nel laboratorio (serve un PC Windows nel dominio): sono qui da confrontare con samba-tool.
Import-Module ActiveDirectory
New-ADOrganizationalUnit -Name "Ufficio" -Path "DC=lab,DC=test"
New-ADUser -Name "Anna Rossi" -GivenName Anna -Surname Rossi -SamAccountName anna `
    -UserPrincipalName anna@lab.test -Path "OU=Ufficio,DC=lab,DC=test" `
    -AccountPassword (Read-Host -AsSecureString "Password") -Enabled $true
New-ADGroup -Name contabilita -GroupScope Global -Path "OU=Ufficio,DC=lab,DC=test"
Add-ADGroupMember -Identity contabilita -Members anna, marco
Get-ADUser -Filter * -SearchBase "OU=Ufficio,DC=lab,DC=test" | Select-Object Name, SamAccountName, Enabled
Get-ADGroupMember contabilita | Select-Object Name
Disable-ADAccount -Identity marco
Import-Csv .\utenti.csv | ForEach-Object {
    New-ADUser -Name "$($_.nome) $($_.cognome)" -SamAccountName $_.utente -Path "OU=Ufficio,DC=lab,DC=test" `
        -AccountPassword (ConvertTo-SecureString "Passw0rd!$($_.utente)" -AsPlainText -Force) -Enabled $true
    Add-ADGroupMember -Identity $_.gruppo -Members $_.utente
}
PS1

# ---------------------------------------------------------------- 10-scenari
sezione 10-scenari
cat > scenari.sh << EOF
#!/usr/bin/env bash
# i guasti stanno in $LAB_SRC/scenari.sh: non aprirlo prima di aver provato
exec bash $LAB_SRC/scenari.sh "\$@"
EOF
chmod +x scenari.sh

[[ $SILENZIOSO == 1 ]] && exit 0
echo "Laboratorio dell'area 07 pronto in $DEST (dominio lab.test, controller dc1)."
echo "  cd 09-active-directory     poi i comandi di 09-active-directory.md"
