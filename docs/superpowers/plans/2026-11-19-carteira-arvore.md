# Carteira em árvore — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trocar o painel lateral + grade de cartões da aba Carteira por uma tabela em árvore (grupos › filiais › dispositivos).

**Architecture:** Só o corpo de `_CarteiraBodyState` muda. Uma função nova em `peer_card.dart` reaproveita o menu do `CarteiraPeerCard`. Modelo, dados, persistência e sync Start X ficam intocados.

**Tech Stack:** Flutter (Material), GetX `Obx`, Provider `Peers`.

**Spec:** `docs/superpowers/specs/2026-11-19-carteira-arvore-design.md`

## Global Constraints

- AGENTS.md: diff mínimo; em arquivo compartilhado (`peer_card.dart`) só adição, nenhuma linha existente alterada.
- Nenhuma chave i18n nova. Cabeçalhos: `translate('Name')`, `'ID'`, `translate('Status')`, `translate('Platform')`. Status: `'Online'`/`'Offline'` como o tooltip atual do card (não são chaves). Demais: `Ungrouped`, `Empty`, `Connect`, `Rename`, `More`.
- Não fazer commit: `carteira_view.dart`, `carteira_model.dart` e o teste têm trabalho não commitado do usuário (login Start X). O usuário decide o commit.
- Preservar: `_buildAccount`, `_StartXLoginDialog`, `_buildActions`, `_addDeviceDialog`, `_renameGroupDialog`, o timer de `queryOnlines`, `AbsorbPointer` durante `syncing`.

## Review Focus

- Filial cuja empresa não tem dispositivo direto: a linha da empresa precisa existir (coberto no teste da árvore).
- Dispositivo adicionado só por ID (sem plataforma conhecida): Sistema mostra `—` e Status `Offline` (coberto no teste de status).
- Nome muito longo em janela estreita: corta com reticências, sem overflow (coberto no teste da árvore com alias longo).
- Busca com grupo recolhido: o resultado aparece mesmo assim (coberto no teste da árvore).
- Tema escuro: cores só via `Theme`/`MyTheme` (checagem manual).

---

### Task 1: Tabela em árvore na aba Carteira

**Files:**
- Modify: `flutter/lib/common/widgets/carteira_view.dart` (corpo de `build`; `_groupTile` sai, entram as linhas da árvore)
- Modify (só adição, fim do arquivo): `flutter/lib/common/widgets/peer_card.dart`
- Test: `flutter/test/carteira_view_test.dart`

**Interfaces:**
- Produces: `Future<void> showCarteiraPeerMenu(BuildContext context, Peer peer, RelativeRect position)` em `peer_card.dart`. Monta os itens com `CarteiraPeerCard(peer: peer)._buildPopupMenuEntry(context)` e chama `mod_menu.showMenu(context:, position:, items:, elevation: 8)`.
- Consumes: `connectInPeerTab(context, peer, PeerTabIndex.carteira)`, `carteiraGroupContains`, `carteiraGroupSeparator`, `getPlatformImage`, `formatID`.

- [ ] **Step 1: Reescrever os testes ligados ao painel lateral e ao cartão**

Substituir `'card reflete mudança de status online do peersModel'` por `'linha mostra status online e sistema desconhecido'`:
- `addPeer('t-online-1', 'Caixa Online', 'Loja Online')`, pump → `find.text('Offline')` findsOneWidget, `find.text('—')` findsOneWidget, `find.text('Online')` findsNothing.
- marcar `online = true` no `peersModel` e notificar → `find.text('Online')` findsOneWidget.

Substituir `'selecionar grupo na lateral filtra os dispositivos'` por `'árvore mostra empresa e filial, recolhe e a busca reabre'`:
- `addPeer('t-tree-1', 'Caixa Norte', 'Grupo Norte / Filial Centro')`, `addPeer('t-tree-2', 'Caixa Sul com um nome bem comprido para cortar', 'Grupo Sul')`.
- Pump → `Grupo Norte`, `Filial Centro`, `Caixa Norte` e o alias longo aparecem (tudo aberto por padrão).
- Tocar `find.byTooltip('Grupo Norte')` (a seta) → `Filial Centro` e `Caixa Norte` findsNothing; alias longo continua.
- `peerSearchText.value = 'Caixa Norte'` → `Caixa Norte` findsOneWidget, alias longo findsNothing.

Os testes de busca vazia (`Empty`) e do diálogo Adicionar ficam como estão.

- [ ] **Step 2: Rodar e ver falhar**

Run: `cd flutter && flutter test test/carteira_view_test.dart`
Expected: os dois testes novos falham (painel lateral ainda presente, sem `Offline`/`—`).

- [ ] **Step 3: Implementar**

- `peer_card.dart`: adicionar `showCarteiraPeerMenu` no fim do arquivo.
- `carteira_view.dart`: trocar `_selectedGroup`/`_expandedGroups` por `final _collapsed = <String>{}` (caminho do grupo; `''` = Sem grupo). O `build` monta um `ListView` com `_buildAccount` (técnico), `_buildActions`, cabeçalho de colunas e as linhas. Colunas: Nome (`Expanded`), ID (140), Status (110), Sistema (140), ações (110). Linha de grupo = seta com `tooltip` igual ao nome do grupo, ícone de pasta, nome, chip `x/y online`, ⋮ com Renomear (não aparece em Sem grupo). Linha de dispositivo = `InkWell` com `onDoubleTap` → `connectInPeerTab`, nome (`alias`, senão `formatID(id)`) + `username@hostname` em cinza, ID, Status, Sistema (`getPlatformImage` + `platform`, ou `—`), botão Conectar (só online) e ⋮ via `showCarteiraPeerMenu`. Busca ativa força tudo aberto e esconde grupos sem resultado; sem resultado → `translate('Empty')`. Indentação 24 px por nível.

- [ ] **Step 4: Rodar e ver passar**

Run: `cd flutter && flutter test test/carteira_view_test.dart && flutter analyze lib/common/widgets/carteira_view.dart lib/common/widgets/peer_card.dart`
Expected: todos os testes passam; analyze sem erros novos.

- [ ] **Step 5: Revisar a superfície de regressão e entregar sem commit**

`git diff --stat` deve mostrar só os três arquivos acima (mais estes docs). Em `peer_card.dart`, nenhuma linha removida.
