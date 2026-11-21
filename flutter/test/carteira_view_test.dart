import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/carteira_view.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Binding extends Fake implements RustdeskImpl {
  final Map<String, String> options = {};
  final List<List<String>> queriedOnlineIds = [];

  @override
  String getLocalFlutterOption({required String k, dynamic hint}) =>
      options[k] ?? '';

  @override
  Future<void> setLocalFlutterOption(
      {required String k, required String v, dynamic hint}) async {
    options[k] = v;
  }

  @override
  String translate({required String name, required String locale, dynamic hint}) =>
      name.replaceAll('{', '').replaceAll('}', '');

  @override
  String mainGetLocalOption({required String key, dynamic hint}) => '';

  @override
  String mainGetBuildinOption({required String key, dynamic hint}) => '';

  @override
  bool isDisableAb({dynamic hint}) => false;

  @override
  bool isDisableAccount({dynamic hint}) => false;

  @override
  bool isDisableGroupPanel({dynamic hint}) => false;

  @override
  Future<bool> optionSynced({dynamic hint}) async => false;

  @override
  Future<void> mainLoadRecentPeers({dynamic hint}) async {}

  @override
  Future<void> mainLoadFavPeers({dynamic hint}) async {}

  @override
  Future<void> queryOnlines({required List<String> ids, dynamic hint}) async {
    queriedOnlineIds.add(ids);
  }

  @override
  Future<bool> mainIsUsingPublicServer({dynamic hint}) async => false;
}

void main() {
  late _Binding binding;

  setUpAll(() async {
    isTest = true;
    binding = _Binding();
    platformFFI.setBindingForTesting(binding);
    await initGlobalFFI();
  });

  setUp(() {
    peerSearchText.value = '';
  });

  Future<void> pumpCarteira(WidgetTester tester,
      {bool showRecentAndFavorites = false}) async {
    final overlayKeyState = OverlayKeyState();
    gFFI.dialogManager.setOverlayState(overlayKeyState);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<PeerTabModel>.value(
        value: gFFI.peerTabModel,
        child: Overlay(
          key: overlayKeyState.key,
          initialEntries: [
            OverlayEntry(
                builder: (_) => Scaffold(
                    body: CarteiraPeersView(
                        showRecentAndFavorites: showRecentAndFavorites))),
          ],
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('linha mostra status online e sistema desconhecido',
      (tester) async {
    final model = gFFI.carteiraModel;
    model.addPeer('t-online-1', 'Caixa Online', 'Loja Online');
    await pumpCarteira(tester);
    expect(find.text('Caixa Online'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Online'), findsNothing);

    model.peersModel.peers
        .firstWhere((p) => p.id == 't-online-1')
        .online = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    model.peersModel.notifyListeners();
    await tester.pump();

    expect(find.text('Online'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('árvore mostra empresa e filial, recolhe e a busca reabre',
      (tester) async {
    const longAlias = 'Caixa Sul com um nome bem comprido para cortar';
    final model = gFFI.carteiraModel;
    model.addPeer('t-tree-1', 'Caixa Norte', 'Grupo Norte / Filial Centro');
    model.addPeer('t-tree-2', longAlias, 'Grupo Sul');
    await pumpCarteira(tester);
    expect(find.text('Grupo Norte'), findsOneWidget);
    expect(find.text('Filial Centro'), findsOneWidget);
    expect(find.text('Caixa Norte'), findsOneWidget);
    expect(find.text(longAlias), findsOneWidget);

    await tester.tap(find.byTooltip('Grupo Norte'));
    await tester.pump();
    expect(find.text('Filial Centro'), findsNothing);
    expect(find.text('Caixa Norte'), findsNothing);
    expect(find.text(longAlias), findsOneWidget);

    peerSearchText.value = 'Caixa Norte';
    await tester.pump();
    expect(find.text('Caixa Norte'), findsOneWidget);
    expect(find.text(longAlias), findsNothing);
    await unmount(tester);
  });

  testWidgets('Dispositivos mostra Conexões recentes e Favoritos no topo',
      (tester) async {
    gFFI.recentPeersModel.peers = [
      Peer.fromJson({'id': 't-rec-1', 'alias': 'Caixa Recente'})
    ];
    gFFI.favoritePeersModel.peers = [
      Peer.fromJson({'id': 't-fav-1', 'alias': 'Caixa Favorita'})
    ];
    addTearDown(() {
      gFFI.recentPeersModel.peers = [];
      gFFI.favoritePeersModel.peers = [];
    });

    await pumpCarteira(tester, showRecentAndFavorites: true);
    expect(find.text('Recent sessions'), findsOneWidget);
    expect(find.text('Caixa Recente'), findsOneWidget);
    expect(find.text('Favorites'), findsOneWidget);
    expect(find.text('Caixa Favorita'), findsOneWidget);
    await unmount(tester);

    await pumpCarteira(tester);
    expect(find.text('Recent sessions'), findsNothing);
    expect(find.text('Caixa Recente'), findsNothing);
    await unmount(tester);
  });

  testWidgets('Adicionar à carteira pergunta o grupo e já coloca nele',
      (tester) async {
    await pumpCarteira(tester);
    showCarteiraGroupDialog(
        Peer.fromJson({'id': 't-add-1', 'alias': 'Caixa Nova'}));
    await tester.pump();
    expect(find.text('Add to wallet'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'New group'), 'Cliente Novo');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(gFFI.carteiraModel.contains('t-add-1'), isTrue);
    expect(gFFI.carteiraModel.groupOf('t-add-1'), 'Cliente Novo');
    await unmount(tester);
  });

  testWidgets('arrastar um dispositivo para outro grupo muda o grupo dele',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final model = gFFI.carteiraModel;
    model.addPeer('t-dnd-1', 'Caixa Arrastada', 'Grupo Origem');
    model.addPeer('t-dnd-2', 'Caixa Destino', 'Grupo Destino');
    await pumpCarteira(tester);

    final gesture = await tester.startGesture(
        tester.getCenter(find.text('Caixa Arrastada')),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Grupo Destino')));
    await tester.pump();
    await gesture.up();
    // Lets the row's double-tap timer expire before the tree is disposed.
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.groupOf('t-dnd-1'), 'Grupo Destino');
    await unmount(tester);
  });

  testWidgets('arrastar a partir do botão Conectar não move o dispositivo',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final model = gFFI.carteiraModel;
    model.addPeer('t-btn-1', 'Caixa do Botão', 'Grupo Botão');
    model.addPeer('t-btn-2', 'Caixa Alvo', 'Grupo Alvo');
    await pumpCarteira(tester);

    final row = find
        .ancestor(of: find.text('Caixa do Botão'), matching: find.byType(InkWell))
        .first;
    final gesture = await tester.startGesture(
        tester.getCenter(find.descendant(of: row, matching: find.text('Connect'))),
        kind: PointerDeviceKind.mouse);
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Grupo Alvo')));
    await tester.pump();
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));
    expect(model.groupOf('t-btn-1'), 'Grupo Botão');
    await unmount(tester);
  });

  testWidgets('Nova rede e Nova filial nascem vazias, e Excluir tira a vazia',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCarteira(tester);

    await tester.tap(find.text('Nova rede'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome da rede'), 'Rede Sem Máquina');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Rede Sem Máquina'), findsOneWidget);

    Finder menuOf(String group) => find.descendant(
        of: find
            .ancestor(of: find.text(group), matching: find.byType(InkWell))
            .first,
        matching: find.byTooltip('Opções do grupo'));
    await tester.tap(menuOf('Rede Sem Máquina'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Nova filial'));
    await tester.pump(const Duration(milliseconds: 300));
    // The dialog opens only after the menu route has finished closing.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
        find.widgetWithText(TextField, 'Nome da filial'), 'Filial Vazia');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Filial Vazia'), findsOneWidget);
    expect(gFFI.carteiraModel.groups,
        contains('Rede Sem Máquina / Filial Vazia'));

    await tester.tap(menuOf('Filial Vazia'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Excluir'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Filial Vazia'), findsNothing);
    expect(find.text('Rede Sem Máquina'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('em tela de celular a linha mostra o nome sem estourar',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    gFFI.carteiraModel
        .addPeer('t-phone-1', 'Caixa do celular', 'Empresa Celular / Filial');
    await pumpCarteira(tester);
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.text('Caixa do celular')).width,
        greaterThan(40));
    await unmount(tester);
  });

  testWidgets('busca sem resultado mostra vazio de busca, não o estado de carteira vazia',
      (tester) async {
    final model = gFFI.carteiraModel;
    model.addPeer('t-search-1', 'Caixa Busca', 'Grupo Busca');
    await pumpCarteira(tester);
    expect(find.text('Caixa Busca'), findsOneWidget);

    peerSearchText.value = 'zzz-sem-match';
    await tester.pump();
    expect(find.text('Caixa Busca'), findsNothing);
    expect(find.text('Empty'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dialog de adicionar dispositivo sugere grupos existentes',
      (tester) async {
    final model = gFFI.carteiraModel;
    model.addPeer('t-auto-1', 'Caixa Auto', 'Padaria Sugestao');
    await pumpCarteira(tester);

    await tester.scrollUntilVisible(find.text('Add device'), 120,
        scrollable: find.byType(Scrollable).first);
    await tester.pump();
    await tester.tap(find.text('Add device'));
    await tester.pump();
    final groupField = find.widgetWithText(TextField, 'Group name');
    expect(groupField, findsOneWidget);
    await tester.enterText(groupField, 'Pada');
    await tester.pump();
    expect(find.text('Padaria Sugestao'), findsWidgets);
    await unmount(tester);
  });
}
