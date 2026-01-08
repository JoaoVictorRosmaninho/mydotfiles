#!/usr/bin/env bash

# Escolha entre wofi ou dmenu
MENU="wofi --dmenu"

# 1. Obtém apenas a seção de Sinks (Saídas) do WirePlumber
# 2. Remove linhas de cabeçalho e espaços extras
# 3. Remove o marcador de "padrão" (*) para evitar erro no ID
# 4. Filtra apenas linhas que começam com ID numérico
devices=$(wpctl status | grep -A 10 "Sinks:" | grep -E "[0-9]+\." | sed 's/^[[:space:]]*//')

# Mostra o menu e captura a seleção
selected=$(echo "$devices" | $MENU -p "Selecionar Saída de Áudio:")

# Se algo foi selecionado, extrai o ID e define como padrão
if [[ -n "$selected" ]]; then
    # Extrai apenas os números antes do ponto (ID)
    id=$(echo "$selected" | grep -oE '^[0-9]+')

    echo "id -> ${id}"
    
    if [[ -n "$id" ]]; then
        wpctl set-default "$id"
        notify-send "Áudio" "Saída alterada para: $selected"
    fi
fi

