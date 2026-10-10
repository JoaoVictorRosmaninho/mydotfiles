#!/bin/bash

# 1. Obtém o valor decimal da bitmask atual
current_mask=$(mmsg -g -t | grep 'tags' | head -n 1 | awk '{print $4}')

# 2. Converte a bitmask (1, 2, 4, 8...) para o índice da tag (0 a 8)
# Usamos logaritmo na base 2 para descobrir o expoente
if [ "$current_mask" -eq 0 ]; then current_idx=0; else
    current_idx=$(echo "l($current_mask)/l(2)" | bc -l | xargs printf "%.0f")
fi

# 3. Configurações
direction=$1
total_tags=9

# 4. Calcula o próximo índice (0 a 8) de forma circular
next_idx=$(( (current_idx + direction + total_tags) % total_tags ))

# 5. Converte o novo índice de volta para bitmask (2^next_idx)
next_mask=$(( 2**next_idx ))

# Debug para o log
echo "Mask: $current_mask (Idx: $current_idx) -> Next Mask: $next_mask (Next Idx: $next_idx)" >> /tmp/mango_script.log

# 6. Envia o comando com a bitmask correta
mmsg -s -d tag,"$next_mask"

