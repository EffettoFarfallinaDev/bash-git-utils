#!/bin/bash
#
# Script: git-ssh-gen
# Scopo: Generare una chiave SSH basata sull'email (passata come argomento o richiesta interattivamente),
#        e caricare automaticamente la chiave pubblica su GitHub.
#
# Assicurati che la cartella "colors" si trovi accanto a questo script e contenga il file "colors.sh"
# con funzioni per i log colorati (info, warn, error, success).

# Determina la directory dello script per poter includere i file di "colors"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -f "$SCRIPT_DIR/colors/colors.sh" ]; then
    source "$SCRIPT_DIR/colors/colors.sh"
else
    echo -e "\033[31m[ERROR] File 'colors/colors.sh' non trovato! Assicurati che la cartella 'colors' esista.\033[0m"
    exit 1
fi

# Funzione per validare l'email usando una regex
validate_email() {
    local email="$1"
    if [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Se l'email non viene passata come argomento, la richiede all'utente
if [ -z "$1" ]; then
    read -p "$(info "Inserisci la tua email: ")" email
else
    email="$1"
fi

# Continuo controllo di validità: se non valida, richiede fino a che non lo è
while ! validate_email "$email"; do
    echo "$(error "L'email '$email' non è valida. Assicurati che sia nel formato corretto, ad es.: utente@example.com")"
    read -p "$(info "Inserisci la tua email: ")" email
done

# Utilizza la parte prima della "@" per definire il nome del file della chiave
username_part=$(echo "$email" | cut -d'@' -f1)
key_path="$HOME/.ssh/id_rsa_${username_part}"

# Se la chiave esiste già, avvisa e non la rigenera
if [ -f "$key_path" ]; then
    echo "$(warn "La chiave SSH esiste già in $key_path. Verrà utilizzata quella esistente.")"
else
    echo "$(info "Generazione di una nuova chiave SSH per $email…")"
    ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_path" -N "" || { echo "$(error "Generazione chiave fallita")"; exit 1; }
fi

pub_key_path="${key_path}.pub"
if [ ! -f "$pub_key_path" ]; then
    echo "$(error "Chiave pubblica non trovata in $pub_key_path. Interruzione dello script.")"
    exit 1
fi

# Legge il contenuto della chiave pubblica
pub_key_content=$(cat "$pub_key_path")

# Se il token GitHub non è definito nella variabile d'ambiente, lo richiede (in modalità silenziosa)
if [ -z "$GITHUB_TOKEN" ]; then
    read -s -p "$(info "Inserisci il tuo GitHub Personal Access Token (con permesso 'admin:public_key'): ")" GITHUB_TOKEN
    echo
fi

echo "$(info "Caricamento della chiave SSH su GitHub…")"
json_payload=$(printf '{"title": "SSH Key for %s", "key": "%s"}' "$email" "$(echo $pub_key_content)")

response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$json_payload" \
    "https://api.github.com/user/keys")

# Estrae lo status http dalla risposta
http_status=$(echo "$response" | awk -F"HTTP_STATUS:" '{print $2}')
body=$(echo "$response" | sed -e 's/HTTP_STATUS\:.*//g')

if [ "$http_status" -eq 201 ]; then
    echo "$(success "Chiave SSH caricata correttamente su GitHub!")"
else
    echo "$(error "Caricamento della chiave fallito. HTTP status: $http_status")"
    echo "$(error "Risposta: $body")"
fi
