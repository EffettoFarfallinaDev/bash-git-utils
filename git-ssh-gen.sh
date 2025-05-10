#!/bin/bash
#
# Script: git-ssh-gen.sh
# Scopo: Generare una chiave SSH basata sull'email e:
#   - Avviare l'ssh-agent ed aggiungere la chiave (se non già presente)
#   - Configurare ~/.ssh/config per forzare l'uso corretto per GitHub
#   - Caricare la chiave pubblica su GitHub (salta questo passaggio se viene specificata l'opzione --skip)
#
# Nota: Questo script dipende dalle funzioni di logging colorato definite in colors/colors.sh.
#       Assicurati che la cartella "colors" (con dentro "colors.sh") si trovi nella stessa directory dello script.

########################################
# Caricamento dei colori per il logging
########################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/colors/colors.sh" ]; then
  source "$SCRIPT_DIR/colors/colors.sh"
else
  echo -e "\033[31m[ERROR] File 'colors/colors.sh' non trovato! Verifica che la cartella 'colors' esista.\033[0m"
  exit 1
fi

########################################
# Parsing degli argomenti
########################################

SKIP_UPLOAD=0
EMAIL_PARAM=""

for arg in "$@"; do
  if [ "$arg" == "--skip" ]; then
    SKIP_UPLOAD=1
  else
    EMAIL_PARAM="$arg"
  fi
done

########################################
# Funzioni
########################################

# Verifica che l'email sia nel formato corretto
validate_email() {
  local email="$1"
  [[ "$email" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]
}

# Richiede l'email all'utente se non è stata passata come parametro
get_email() {
  if [ -z "$EMAIL_PARAM" ]; then
    read -p "$(info "Inserisci la tua email: ")" email
  else
    email="$EMAIL_PARAM"
  fi
  while ! validate_email "$email"; do
    echo "$(error "L'email '$email' non è valida. Format richiesto: utente@example.com")"
    read -p "$(info "Inserisci la tua email: ")" email
  done
}

# Genera la chiave SSH basata sull'email se non esiste già
generate_key() {
  username_part=$(echo "$email" | cut -d'@' -f1)
  key_path="$HOME/.ssh/id_rsa_${username_part}"
  if [ -f "$key_path" ]; then
    echo "$(warn "La chiave SSH esiste già in $key_path. Verrà utilizzata quella esistente.")"
  else
    echo "$(info "Generazione di una nuova chiave SSH per $email...")"
    ssh-keygen -t rsa -b 4096 -C "$email" -f "$key_path" -N "" || { echo "$(error "Generazione chiave fallita")"; exit 1; }
  fi
  pub_key_path="${key_path}.pub"
  if [ ! -f "$pub_key_path" ]; then
    echo "$(error "Chiave pubblica non trovata in $pub_key_path. Interruzione dello script.")"
    exit 1
  fi
}

# Avvia l'ssh-agent ed aggiunge la chiave se necessario
setup_ssh_agent() {
  echo "$(info "Avvio e verifica dell'ssh-agent...")"
  eval "$(ssh-agent -s)" > /dev/null

  # Controlla se la chiave è già presente nell'agent
  if ssh-add -l | grep -q "$(basename "$key_path")"; then
    echo "$(info "La chiave è già presente nell'ssh-agent.")"
  else
    echo "$(info "Aggiungo la chiave all'ssh-agent.")"
    ssh-add "$key_path" || { echo "$(error "Impossibile aggiungere la chiave all'ssh-agent.")"; exit 1; }
  fi
}

# Aggiorna (o crea) il file ~/.ssh/config per forzare l'utilizzo della chiave specifica per GitHub
update_ssh_config() {
  config_file="$HOME/.ssh/config"
  [ -f "$config_file" ] || touch "$config_file"
  if grep -q "Host github.com" "$config_file"; then
    echo "$(info "Configurazione per github.com già presente in ~/.ssh/config.")"
  else
    echo "$(info "Aggiungo configurazione per github.com in ~/.ssh/config.")"
    cat <<EOF >> "$config_file"

Host github.com
    HostName github.com
    User git
    IdentityFile $key_path
EOF
  fi
}

# Carica la chiave pubblica su GitHub usando l'API REST
upload_key_to_github() {
  # Richiede il token se non definito come variabile d'ambiente
  if [ -z "$GITHUB_TOKEN" ]; then
    read -s -p "$(info "Inserisci il tuo GitHub Personal Access Token (con permesso 'admin:public_key'): ")" GITHUB_TOKEN
    echo
  fi
  echo "$(info "Caricamento della chiave SSH su GitHub...")"
  json_payload=$(printf '{"title": "SSH Key for %s", "key": "%s"}' "$email" "$(cat "$pub_key_path")")
  response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Content-Type: application/json" \
    --data "$json_payload" \
    "https://api.github.com/user/keys")
  http_status=$(echo "$response" | awk -F"HTTP_STATUS:" '{print $2}')
  body=$(echo "$response" | sed -e 's/HTTP_STATUS\:.*//g')
  if [ "$http_status" -eq 201 ]; then
    echo "$(success "Chiave SSH caricata correttamente su GitHub!")"
  elif [ "$http_status" -eq 422 ] && echo "$body" | grep -q "key is already in use"; then
    echo "$(warn "Chiave SSH già presente su GitHub, salto il caricamento.")"
  else
    echo "$(error "Caricamento della chiave fallito. HTTP status: $http_status")"
    echo "$(error "Risposta: $body")"
  fi
}

########################################
# Main
########################################

get_email
generate_key
setup_ssh_agent
update_ssh_config

if [ "$SKIP_UPLOAD" -eq 1 ]; then
  echo "$(info "Opzione --skip rilevata: salto il caricamento della chiave su GitHub.")"
else
  upload_key_to_github
fi