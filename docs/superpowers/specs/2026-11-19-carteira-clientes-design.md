# Design — Aba "Carteira" (clientes agrupados) + cores start-loja

Data: 2026-11-19
Status: aprovado (plan mode), em execução na branch `feature/carteira-clientes`

## Intent e porquê

O operador Start X atende uma carteira de clientes via RustDesk customizado
(servidor OSS próprio `hbbs`/`hbbr` na VPS). Hoje os dispositivos aparecem em
listas planas (Recentes, Favoritos), impossibilitando organizar por empresa
cliente. Esta entrega adiciona uma aba **Carteira** com agrupamento local e
aplica a identidade visual do start-loja ao cliente.

## Goals

- Aba "Carteira" com peers agrupados por nome de grupo, seções colapsáveis.
- Adicionar peer por ID, importar de Recentes/Favoritos, mover entre grupos,
  renomear grupo, remover.
- Persistência local (sem sync), sobrevivendo a reinício do app.
- Paleta start-loja (`#0C2451`, `#1F4DA8`, `#2961CE`, `#9ABEFF`, `#F5F8FF`)
  aplicada via tokens em `MyTheme`.

## Non-goals

- Sincronização da carteira entre máquinas operadoras.
- Descoberta automática de clientes (peers entram por importação ou ID manual).
- Status online em tempo real de IDs que nunca apareceram em Recentes (v1
  mostra último estado conhecido).
- Mudanças em Rust/FFI.

## Anti-goals (falha mesmo "funcionando")

- Alterar comportamento das abas existentes (Recentes, Favoritos, etc.).
- Dif grande em arquivos compartilhados — apenas hooks finos (AGENTS.md).
- Depender de servidor Pro ou API externa.

## Approaches consideradas

1. **Grupos locais no cliente (escolhida)** — nova aba + storage em
   `bind.setLocalFlutterOption` (JSON no `RustDesk2.toml`). Zero Rust, funciona
   com o servidor OSS atual. Custo: dados por máquina.
2. **RustDesk Server Pro** — Address Book com tags + sync prontos. Rejeitada:
   licença paga + migração de servidor.
3. **API server customizada** — compatível com endpoints de AB. Rejeitada
   (esforço de backend novo); o model isola persistência para permitir essa
   troca futura sem tocar a UI.

## Como (decidido)

- `flutter/lib/models/carteira_data.dart` — dados e regras puros (Dart +
  `dart:convert`), sem imports Flutter/FFI, para testes em VM.
- `flutter/lib/models/carteira_model.dart` — wrapper GetX observável +
  persistência via `bind.*LocalFlutterOption`, padrão `ab_model.dart`.
- `flutter/lib/common/widgets/carteira_view.dart` — `CarteiraPeersView extends
  BasePeersView`, seções por grupo reutilizando `PeerCard`.
- Hooks: `peer_tab_model.dart` (6ª aba), `peer_tab_page.dart` (1 entrada),
  `peer_card.dart` (1 item de menu "Mover para grupo…").
- Cores: tokens `brandDark/brandMid/brandLight/brandBg/brandWarn` em
  `MyTheme`; painel esquerdo da home passa a `brandDark`.
- i18n: chaves novas ao final de `template.rs` e todos os `src/lang/*.rs`
  (PT traduzido, demais `""`, `it.rs` sempre `""`).

## Limites conhecidos

- Status online de peers adicionados manualmente só aparece após o peer
  constar em Recentes/Favoritos (eventos Rust existentes).
- Grupos são por máquina; exportar/importar config é o caminho de "sync"
  manual hoje.

## O que ficou para o builder

- Detalhes visuais finos das seções (espaçamento, tipografia do header).
- Ícone da aba (proposta: `Icons.work` / `IconFont` equivalente).
