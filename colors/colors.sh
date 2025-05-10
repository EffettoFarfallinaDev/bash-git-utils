#!/bin/bash
# Funzioni per messaggi colorati

info() {
    echo -e "\033[34m$@\033[0m"  # Blu
}

warn() {
    echo -e "\033[33m$@\033[0m"  # Giallo
}

error() {
    echo -e "\033[31m$@\033[0m"  # Rosso
}

success() {
    echo -e "\033[32m$@\033[0m"  # Verde
}
