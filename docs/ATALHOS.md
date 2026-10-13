# Guia de atalhos e workflow — MangoWC + Quickshell

> Fonte da verdade: [`.config/mango/binds.conf`](../.config/mango/binds.conf). Se um atalho aqui divergir de lá, vale o arquivo.
> Depois de editar o `binds.conf`: `Super+R` recarrega e `mango -c ~/.config/mango/config.conf -p` valida (o `-c` tem que vir antes do `-p`).

## Conceitos em 1 minuto

- **`Super`** (a tecla Windows) comanda o gerenciador de janelas. **`Alt` fica livre para os apps** (voltar/avançar no navegador, mover linha no VS Code...). A exceção é o `Alt+Tab`.
- **Tags** são as "áreas de trabalho" 1 a 9. Diferente de um desktop comum, cada tag tem um **propósito fixo** e um **layout próprio** (veja [o mapa](#o-mapa-de-tags)). A barra só mostra as tags que têm janelas.
- **Layouts** decidem como as janelas se organizam: `tile` (principal + pilha), `center_tile` (principal no centro), `monocle` (uma por vez, tela cheia), `scroller` (colunas lado a lado, roláveis), `grid`.
- **Scratchpad** é uma janela que **aparece por cima de qualquer tag** com uma tecla e **some** com a mesma tecla. Serve para consultas rápidas sem perder o lugar.
- **Janela principal (master)** é a maior do layout. `Super+Enter` troca a janela focada com ela.

Notação: `Super+Shift+N` = segurar Super e Shift e apertar N. `←↑→↓` = setas.

---

## Atalhos

### Abrir coisas

| Atalho | O que faz |
| --- | --- |
| `Super+Shift+Enter` | Abre um terminal (Alacritty) |
| `Super+P` | Lançador de aplicativos (rofi). Apertar de novo fecha |
| `Super+V` | Histórico da área de transferência: escolha um item e ele volta a ser o "copiado" |
| `Super+E` | Gerenciador de arquivos (Nautilus) |
| `Super+Alt+O` | Escolher a **saída** de áudio (fone, caixa, HDMI) |
| `Super+Alt+I` | Escolher a **entrada** de áudio (microfone do headset, da webcam) |

### Scratchpads (aparecem e somem por cima de tudo)

| Atalho | O que faz |
| --- | --- |
| `Super+U` | Terminal suspenso. Se não existir, abre um; apertar de novo esconde. A sessão dele continua viva escondida |
| `Super+B` | Slack suspenso. Clicar numa notificação do Slack também o mostra |
| `Super+I` | Minimiza a janela focada (ela vai para o "scratchpad genérico") |
| `Super+Shift+Z` | Mostra ou esconde, uma por vez e flutuando, as janelas minimizadas |
| `Super+Shift+I` | Restaura as minimizadas para o lugar delas no layout |

### Foco: ir até uma janela

| Atalho | O que faz |
| --- | --- |
| `Super+←↑→↓` | Foca a janela naquela direção |
| `Super+K` / `Super+J` | Próxima / anterior janela da pilha (em ordem) |
| `Super+;` | **Rótulos de salto**: aparece uma letra sobre cada janela; aperte a letra para ir direto nela |
| `Alt+Tab` | **Overview**: mostra as janelas de todas as tags lado a lado; clique para ir |

### Mover e redimensionar janelas

| Atalho | O que faz |
| --- | --- |
| `Super+Shift+←↑→↓` | Troca a janela de lugar com a vizinha naquela direção |
| `Super+Enter` | Troca a janela focada com a principal (master) |
| `Super+Alt+←↑→↓` | Redimensiona em passos de 50 px |
| `Super+Alt+R` | **Modo de redimensionar**: depois só as setas (40 px; com `Shift`, 160 px). `Esc` ou `Enter` sai do modo |
| `Super` + arrastar com botão **esquerdo** | Move a janela. Uma janela do tiling solta sobre outra **troca de lugar** com ela; uma flutuante vai para onde você soltar |
| `Super` + arrastar com botão **direito** | Redimensiona a janela |

### Estado da janela

| Atalho | O que faz |
| --- | --- |
| `Super+Q` | Fecha a janela |
| `Super+F` | Tela cheia de verdade (cobre a barra) |
| `Super+Shift+F` | "Tela cheia falsa": o app *acha* que está em tela cheia (vídeo, apresentação), mas continua no tamanho do tiling |
| `Super+Shift+M` | Maximiza (ocupa a área toda, mas a barra continua visível) |
| `Super+Space` | Alterna entre flutuante e tiling |
| `Super+O` | **Sobreposição**: a janela fica sempre por cima das outras (bom para uma calculadora, um vídeo ou um log) |
| `Super+Shift+G` | **Global**: a janela aparece em **todas** as tags (bom para uma doc de referência) |

### Tags: navegar

| Atalho | O que faz |
| --- | --- |
| `Super+1..9` | Vai para a tag. **Apertar a da tag em que você já está volta para a anterior** |
| `Super+Tab` | Alterna entre as **duas últimas tags** (1 → 5 → 1 → 5...) |
| `Super+Ctrl+←` / `→` | Tag anterior / próxima (pela numeração) |
| `Super` + rolar o mouse | Tag anterior / próxima, pulando as vazias |
| `Super+Ctrl+N` | Vai para a **primeira tag vazia** (prefere 6–9, as de task) |

### Tags: mover janelas

| Atalho | O que faz |
| --- | --- |
| `Super+Shift+1..9` | Move a janela para a tag e vai junto |
| `Super+Ctrl+Shift+←` / `→` | Move a janela para a tag anterior / próxima e vai junto |
| `Super+N` / `Super+Shift+N` | Joga a janela para a próxima / anterior tag |
| `Super+Ctrl+Shift+N` | Leva a janela para a primeira tag vazia |

### Layouts

| Atalho | O que faz |
| --- | --- |
| `Super+T` | `tile`: principal à esquerda, as outras empilhadas à direita |
| `Super+M` | `monocle`: uma janela por vez, ocupando tudo (`Super+K/J` troca) |
| `Super+G` | `grid`: todas em grade |
| `Super+S` | `scroller`: colunas lado a lado; as que não cabem ficam à direita, roláveis |
| `Super+C` | Cicla entre os layouts |
| `Super+Shift+X` | No scroller: cicla a largura da coluna focada entre 1/3, 1/2, 2/3 e tela cheia |
| `Super+Shift+E` | No scroller: coluna focada em largura total |
| `Super+Ctrl+X` / `Super+Ctrl+Z` | Aumenta / diminui o espaçamento (gaps) |
| `Super+Ctrl+R` | Liga/desliga os gaps |

> A mudança de layout vale só para a tag atual. O layout de cada tag ao iniciar está no [mapa](#o-mapa-de-tags).

### Shell (barra, menus, sessão)

| Atalho | O que faz |
| --- | --- |
| `Super+A` | Configurações (sistema, áudio, monitor, rede, temas...) |
| `Super+X` | Central de notificações |
| `Super+D` | Notas / to-do |
| `Super+Z` | Menu radial de atalhos |
| `Super+W` | Seletor de wallpaper (as cores do sistema acompanham o wallpaper) |
| `Super+Shift+W` | Esconde/mostra a barra |
| `Super+Shift+O` | Opacidade das janelas e da barra |
| `Super+Shift+L` | Alterna tema claro/escuro |
| `Super+Grave` (`` ` ``) | Menu de energia (bloquear, desligar, reiniciar, suspender, sair) |
| `Super+Escape` | Bloqueia a tela |
| `Super+R` | Recarrega a configuração do mango |
| `Super+Shift+Q` | Sai da sessão |

> Inatividade: a tela **bloqueia sozinha aos 10 min** e **apaga aos 15 min** (volta com qualquer tecla). Apps que pedem para manter a tela ligada (vídeo, chamadas) adiam isso. Ela também bloqueia antes de suspender.

### Screenshots

| Atalho | O que faz |
| --- | --- |
| `Super+L` | **flameshot**: selecione uma área, anote (setas, texto, blur) e salve ou copie |
| `Print` | Tela inteira: salva em `~/Pictures`, copia e mostra uma prévia |
| `Shift+Print` | Seleciona uma área: salva, copia e mostra uma prévia |

### Teclas de mídia

| Tecla | O que faz |
| --- | --- |
| Volume `+` / `−` / mudo | Volume da saída padrão (o indicador do Quickshell aparece) |
| Microfone mudo | Muta/desmuta **todos** os microfones (o mesmo que o botão da barra) |
| Play / próxima / anterior | Controla o player ativo (Spotify, YouTube no navegador...) |
| Brilho `+` / `−` | Brilho do monitor externo via DDC/CI (`ddcutil`) |

### Mouse na barra superior

| Onde | Clique esquerdo | Outros |
| --- | --- | --- |
| Tags (números) | Vai para a tag | Rolar: tag anterior/próxima |
| Título da janela | — | — |
| Relógio | Calendário | Direito: customizar a barra (posição, estilo, módulos) |
| Mídia (texto rolando) | Play/pause | Direito: próxima · Meio: anterior |
| Ícones do tray | Abre o app | Direito: menu do app · Meio: ação secundária |
| Microfone | Muta/desmuta todos (fica **vermelho** quando algum app está usando, cortado quando mudo) | Direito: `pavucontrol` na aba de entrada |
| Volume | Configurações de áudio | Direito: mudo · Rolar: volume |
| Rede | Configurações de rede | — |
| Notificações (sino) | Central de notificações | — |
| Câmera (screenshot) | flameshot | Direito: tela inteira direto para a área de transferência |
| Wallpaper | Seletor de wallpaper | — |
| Energia | Menu de energia | — |

**Notificações:** clicar no popup leva ao app que a enviou (e, se o app suportar, à conversa ou aba certa); o botão direito copia o texto. Na central (`Super+X`) vale o mesmo.

---

## O mapa de tags

| Tag | Propósito | Layout inicial | Abre sozinho aqui |
| --- | --- | --- | --- |
| **1** | Navegador | `monocle` | Chrome |
| **2** | Código | `center_tile` | VS Code |
| **3** | Chat e e-mail | `center_tile` | — (o Slack mora no scratchpad `Super+B`) |
| **4** | Terminais | `scroller` | — |
| **5** | Notas e docs | `tile` | — |
| **6–9** | Tasks e protótipos | `scroller` | — |

Por que esses layouts:
- **`monocle` no navegador:** uma janela grande; quem navega são as abas.
- **`center_tile` no código e no chat:** no ultrawide, uma janela sozinha fica **centralizada** com largura confortável, em vez de esticada em 2560 px. Duas janelas ficam lado a lado; três ou mais deixam a principal no meio.
- **`scroller` nos terminais e nas tasks:** cada janela nova vira uma coluna (metade da tela por padrão). Cabem 2 ou 3 lado a lado, e o resto fica à direita, alcançável com `Super+←/→`.

> Janelas **novas** do Chrome e do VS Code sempre nascem nas tags 1 e 2, mesmo se você abrir de outra tag. Para usar uma delas numa task, mova com `Super+Shift+<n>`.

---

## Exemplos de uso

### 1. Começar o dia

1. `Super+1`: o navegador. `Super+2`: o VS Code. Cada um já está no seu lugar.
2. `Super+B`: dá uma olhada no Slack. `Super+B` de novo esconde.
3. `Super+4`: abra 2 ou 3 terminais (`Super+Shift+Enter`). No scroller eles ficam em colunas; `Super+←/→` passa de um para o outro.

### 2. Uma task nova ou um protótipo rápido

1. `Super+Ctrl+N`: você cai na primeira tag livre (a 6, por exemplo). A barra passa a mostrar o "6".
2. Abra o que precisar: `Super+Shift+Enter` para um terminal, e traga o editor da tag 2 com `Super+2` e depois `Super+Shift+6` (o VS Code abriria na 2).
3. Ajuste as colunas: foque uma e use `Super+Shift+X` até ficar 1/3, 1/2 ou 2/3. Para uma coluna ocupar tudo por um momento, `Super+Shift+E`.
4. Precisa consultar o código principal? `Super+2`, e depois `Super+Tab` para voltar à task. Repita à vontade: `Super+Tab` sempre alterna entre as duas.
5. Terminou: feche as janelas da task (`Super+Q`) e a tag some da barra.

### 3. Interrupção sem perder o lugar

- Chegou uma mensagem: `Super+B`, responde, `Super+B`. Você continua exatamente onde estava.
- Um comando rápido (`git status`, `docker ps`): `Super+U`, digita, `Super+U`. O terminal suspenso guarda o histórico e o diretório.
- Uma notificação importante: clique nela e você vai direto ao app; `Super+Tab` te traz de volta.

### 4. Muitas janelas na tela

- Em vez de ciclar com `Super+K` várias vezes: `Super+;` e a letra da janela.
- Perdeu uma janela em alguma tag: `Alt+Tab` mostra todas, de todas as tags.
- Uma doc ou um log que você quer ver em todas as tags: foque e aperte `Super+Shift+G`. Para tirar, `Super+Shift+G` de novo.
- Um vídeo ou uma calculadora sempre por cima: `Super+O`.

### 5. Comparar duas coisas lado a lado

1. Leve as duas janelas para a mesma tag (`Super+Shift+<n>` em cada uma).
2. `Super+T` (tile) para metade/metade, ou `Super+S` (scroller) e `Super+Shift+X` para escolher a proporção.
3. Para inverter os lados: `Super+Shift+←` ou `→`.
4. Ajuste fino da divisão: `Super+Alt+R`, depois as setas, depois `Esc`.

### 6. Reunião ou apresentação

- O microfone na barra fica **vermelho** quando o app de chamada está usando. Clique para mutar **todos** os microfones; ele fica cortado.
- Compartilhar a tela funciona pelo portal do navegador (escolha a tela ou a janela).
- Apresentar sem perder a barra: `Super+Shift+F` (tela cheia falsa). Tela cheia de verdade: `Super+F`.
- Apps que pedem para manter a tela ligada (players de vídeo, a maioria das chamadas no navegador) adiam o bloqueio automático. Se o seu não pedir, bloqueie e desbloqueie normalmente ou mexa o mouse.

---

## Quando algo não responde

| Situação | Faça |
| --- | --- |
| Um atalho não funciona | `Super+R` (recarrega) e `cd ~/dotfiles && ./check.sh`; confira o atalho no `binds.conf` |
| A barra sumiu | `Super+Shift+W`; se não voltar, num terminal: `qs kill; setsid qs &` |
| Ficou preso no modo de redimensionar | `Esc` ou `Enter` |
| Tela bloqueada e o Quickshell travou | `Ctrl+Alt+F2`, faça login e rode `export WAYLAND_DISPLAY=wayland-0; qs -d; sleep 2; qs ipc call lock lock`; depois volte e desbloqueie |
| Mudou um atalho e quer garantir que está certo | `mango -c ~/.config/mango/config.conf -p` (sem saída = sem erros) |
