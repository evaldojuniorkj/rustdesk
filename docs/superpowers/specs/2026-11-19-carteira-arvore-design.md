# Design — Carteira em tabela de árvore (estilo TeamViewer)

Data: 2026-11-19 · Status: aprovado pelo usuário · Branch `feature/carteira-clientes`
Complementa `2026-11-19-carteira-clientes-design.md`.

## Intenção

A aba Carteira com painel lateral de grupos e grade de cartões pareceu pouco
familiar. Os técnicos conhecem o TeamViewer. O protótipo aprovado
(https://claude.ai/artifact/1T6wtbrNEBLwRSibPMHmXD) mostra a carteira como uma
tabela em árvore. Esta entrega leva só o conteúdo da aba para o Flutter.

## Goals

- Linhas de grupo (Empresa › Filial) com seta, contagem `x/y online` e ⋮
  (Renomear grupo).
- Linhas de dispositivo com colunas Nome, ID, Status e Sistema, mais Conectar
  e ⋮ (o mesmo menu do `CarteiraPeerCard`).
- Duplo-clique conecta via `connectInPeerTab`.
- A busca da aba (`peerSearchText`) filtra e abre os grupos com resultado.
- Ficam como estão a barra de conta Start X e os botões Adicionar dispositivo
  e Importar.

## Non-goals

- Recentes e Favoritos dentro da árvore (já são abas vizinhas), o filtro
  "Somente online", a coluna Último acesso e grupos vazios.
- Mudar a home, outras abas, o modelo de dados ou o Rust.

## Abordagens

1. **Tabela própria em `carteira_view.dart` + menu do card reutilizado
   (escolhida).** Uma função nova em `peer_card.dart` abre o menu do
   `CarteiraPeerCard` numa posição dada. Nenhuma linha existente do card muda.
2. Renderizar o `CarteiraPeerCard` no modo lista dentro da árvore. Rejeitada:
   o modo do card é global (`peerCardUiType`) e mudaria as outras abas.
3. Copiar o menu para a Carteira. Rejeitada: duplica ações de conexão que o
   card já mantém.

## Adendo: janela do técnico (aprovado depois)

Com o app rodando, o usuário pediu a janela inteira no molde do protótipo, para
uso do técnico, sem renomear o RustDesk.

- `flutter/lib/desktop/pages/devices_home_page.dart` (`DevicesHomePage`): barra
  lateral (Dispositivos, Suporte remoto, Configurações), topo com um campo que
  busca ou conecta por ID, a árvore da Carteira com Sessões recentes e Favoritos
  no topo, e a barra de status existente.
- "Suporte remoto" é a `DesktopHomePage` original, sempre montada (o `initState`
  dela registra serviços que a barra de status usa).
- Gancho: `desktop_tab_page.dart` usa a `DevicesHomePage` só quando
  `START_X_DEV_EDITION=technician`; as outras edições seguem com a home antiga.
- Textos "Dispositivos", "Suporte remoto" e a dica do campo ficam em português
  no código, como o restante do código Start X, para não exigir chave nova e
  recompilar o Rust.

## Redesenho do app inteiro (próximos passos)

Protótipo clicável aprovado: `docs/superpowers/prototypes/2026-11-19-app-inteiro.html`
(abra no navegador; também em https://claude.ai/artifact/1T6wtbrNEBLwRSibPMHmXD).
Visual: tema "loja" do design system Start X; o nome continua RustDesk.

### Modelo de acesso (como o AnyDesk)

- Sem senha por padrão: o cliente passa o ID e cada acesso espera ele clicar em
  Aceitar (no RustDesk: `approve-mode = click`).
- Senha só no **acesso não supervisionado**: ao ligar, cadastra-se a senha; quem
  a tiver entra sem aceite (servidores e caixas sem ninguém na frente).
- Não mostrar senha de uso único nem permanente nas telas de cliente e suporte.

### Roteiro, uma parte por vez (protótipo → aprovação → Flutter)

1. **Feito em 2026-11-20.** Organizar e conta: arrastar dispositivo para grupo
   (só a célula do nome arrasta, para não engolir cliques em Conectar e ⋮);
   "Adicionar à carteira…" pergunta o grupo; login Start X salvo na opção local
   `carteira-session`; sessão salva busca a carteira da conta ao abrir e nunca
   mostra a local com o nome da conta; 401 sai da conta; levar a carteira local
   para a conta no login (a conta vence em ID repetido). Contas são criadas no
   Start Admin (perfil `start_x`); não criar cadastro público no app.
   - Servidor (Start-X): contas próprias do RustDesk, fora das contas do Start
     Admin (`Start-X/docs/superpowers/specs/2026-11-20-contas-do-rustdesk-design.md`).
     O técnico cria a conta no diálogo de entrar ("Criar conta": nome, e-mail,
     senha de 8+) por `POST /suporte/contas` e entra por `POST /suporte/entrar`;
     a sessão cai com 30 dias sem uso (o uso renova). Nenhuma conta do Start X
     entra no RustDesk. Na VPS, o Caddy só deixa sair `/suporte/*` na de teste
     (`api.devstartx.vps-kinghost.net`).
   - Limite: sem confirmação de e-mail nem "Esqueci a senha"; quem esquece a
     senha cria outra conta.
   - Pendente menor: a pergunta de levar a carteira se perde se o diálogo de
     login for fechado durante o login; a etiqueta do arraste aparece longe do
     cursor; a lista não rola sozinha durante o arraste.
2. **Feito em 2026-11-20** (`support_page.dart`, seção Suporte remoto da edição
   técnico): cartões "Permitir controle remoto" (só o ID, com copiar, a linha
   "Acesso só com a sua aprovação" ou "Acesso não supervisionado ligado" e o
   link para Configurações › Segurança) e "Controlar dispositivo remoto" (ID,
   Conectar, Transferir arquivos e as 4 conexões mais recentes), mais o cartão
   de permissões do macOS (Gravar a tela, Acessibilidade, Monitorar entrada).
   O botão "Tela clássica" mostra a `DesktopHomePage` original, que segue
   montada primeiro; clicar de novo em Suporte remoto volta à tela nova. A tela
   tem o bloqueio contra o mouse de quem acessa, como a home original.
   - Limites: a linha "Acesso só com a sua aprovação" descreve o modo que o
     `main.dart` fixa nas duas edições Start X; quem mudar o modo nas
     configurações avançadas o perde ao reabrir o app. As conexões recentes
     mostram nome e ID, sem "há quanto tempo" (o `Peer` não guarda a hora). A
     tela relê a senha permanente e as permissões a cada 1 s, como a home
     antiga, mesmo com outra seção aberta. Os avisos da home antiga (instalar,
     atualizar, erro de sistema, serviço do macOS, Wayland) ficam só na Tela
     clássica.
3. **Feito em 2026-11-20** (`simple_settings_page.dart`, nas duas edições Start X).
   A aba Configurações abre a `SimpleSettingsView`: Geral (tema, idioma, abrir
   sessões em abas), Segurança (acesso com aprovação sempre ligado; acesso não
   supervisionado = senha permanente, ligar cadastra e desligar apaga; o que
   quem acessa pode fazer: teclado e mouse, área de transferência, arquivos,
   áudio, reiniciar), Rede (servidores só para leitura e conexão direta por IP),
   Conta (entrar, sincronizar, sair; fica fora da edição cliente) e Sobre
   (versão e estado do servidor). "Configurações avançadas" troca para a
   página original na mesma aba. A tela usa o mesmo bloqueio da página original
   contra quem acessa, e a mesma trava de administrador/PIN para as opções de
   acesso num app instalado.
   - Limites: "Iniciar com o computador" e "Procurar atualização" do protótipo
     ficaram de fora (não há opção pronta no RustDesk); "Sempre ligado" não lê
     o `approve-mode` (o `main.dart` o fixa a cada abertura nas duas edições);
     quem muda os servidores nas configurações avançadas os perde ao reabrir o
     app (o preset volta); `switch2page` (atalhos da home antiga) abre a tela
     simples na aba Geral; para voltar das configurações avançadas, feche e
     reabra a aba.
4. Sessão remota: abas por computador; Ações, Tela, Arquivos, Chat, Gravar,
   Encerrar; "Aguardando o cliente aceitar" antes de abrir.
   **Feito em 2026-11-20** (`session_toolbar_labels.dart` + ganchos em
   `remote_toolbar.dart`, só nas edições Start X): a barra flutuante da sessão
   usa as cores da marca (`brandMid`, `brandDark` no hover) e os botões de
   sempre ganham texto: Ações ▾ (menu de controle), Tela ▾ (menu de exibição e
   qualidade), Arquivos (novo botão, faz o mesmo que "Transferir arquivo" do
   menu Ações), Chat ▾, Gravar/Gravando e Encerrar com contorno vermelho. Cada
   botão segue fazendo o que já fazia; o texto é escolhido pela dica (tooltip)
   original do botão.
   - Limites: nome, ID e qualidade não entram na barra, porque a aba já mostra
     o nome (ou ID) e o ícone direta/relay com a dica da conexão; a latência
     fica no "monitor de qualidade" do menu Tela. A barra continua flutuante
     (fixar, recolher, arrastar para as bordas), não uma faixa fixa sob as
     abas; encostada na lateral ela fica mais larga com os textos. Os botões
     são cheios na cor da marca, não "fantasma" como no protótipo, para casar
     com os botões só de ícone (fixar, monitor, teclado), que têm ícone branco.
     Ações e Tela mostram os menus completos do RustDesk; Chat continua com o
     submenu (chat de texto e chamada de voz). "Aguardando o cliente aceitar"
     é o aviso do próprio RustDesk ("Aguarde que o lado remoto aceite..."), não
     o cartão do protótipo. Arquivos reusa o token da sessão como o item do
     menu, que o RustDesk avisa não valer para sessões aceitas por clique: o
     cliente pode ter de aceitar de novo (não testado). Se o RustDesk mudar a
     dica de um botão, ele volta ao ícone original sem texto.
5. **Feito em 2026-11-20** (`client_home_page.dart`, só na edição cliente), no
   layout do AnyDesk 7: barra de endereço, "Seu endereço" grande com ⓘ, 🔒 e
   Convidar, abas Início/Sessões recentes/Favoritos e blocos (ajuda, instalar no
   Windows, acesso não supervisionado = senha permanente, permissões do macOS).
   Acesso sem senha temporária (`verification-method = use-permanent-password`,
   `approve-mode = ''`). A tela tem o bloqueio contra o mouse de quem acessa,
   como a home original. A janela de aceite segue a do RustDesk.
   - Limites: o bloco de acesso não supervisionado não se atualiza se a senha
     mudar em Configurações › Segurança; os avisos da home antiga (erro de
     sistema, atualização no Windows, serviço do macOS, Wayland) não aparecem
     nesta tela; abrir a edição cliente num computador fixa esse modo de acesso
     na configuração do RustDesk dele.
   Desenho original da parte 5 (molde AnyDesk, nosso visual): "Seu endereço" em destaque,
   janela de aceite no canto com ícones de permissão, Aceitar/Recusar e, na
   sessão, tempo, Chat e Desconectar; histórico de quem acessou.

### Como compilar e abrir no macOS (edição técnico)

Em `flutter/`, com a `target/release/liblibrustdesk.dylib` já compilada:
`FLUTTER_XCODE_ARCHS=arm64 FLUTTER_XCODE_ONLY_ACTIVE_ARCH=YES flutter build macos --release --dart-define=START_X_DEV_EDITION=technician`,
depois `codesign --force --deep --sign - build/macos/Build/Products/Release/RustDesk.app`
(a assinatura ad-hoc com Hardened Runtime impede o app de abrir localmente).

## Limites conhecidos

- Renomear uma empresa que só tem filiais não renomeia as filiais
  (`CarteiraData.renameGroup` troca só o nome exato). Isso já acontece antes
  desta entrega.
- O status online continua sendo o último estado conhecido (Recentes/Favoritos
  + `queryOnlines`).
