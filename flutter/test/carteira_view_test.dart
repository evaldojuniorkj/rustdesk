import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/carteira_view.dart';
import 'package:flutter_hbb/common/widgets/peer_card.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/generated_bridge.dart';
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

  Future<void> pumpCarteira(WidgetTester tester) async {
    final overlayKeyState = OverlayKeyState();
    gFFI.dialogManager.setOverlayState(overlayKeyState);
    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<PeerTabModel>.value(
        value: gFFI.peerTabModel,
        child: Overlay(
          key: overlayKeyState.key,
          initialEntries: [
            OverlayEntry(
                builder: (_) => Scaffold(body: CarteiraPeersView())),
          ],
        ),
      ),
    ));
    await tester.pump();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('card reflete mudança de status online do peersModel',
      (tester) async {
    final model = gFFI.carteiraModel;
    model.addPeer('t-online-1', 'Caixa Online', 'Loja Online');
    await pumpCarteira(tester);
    expect(find.text('Caixa Online'), findsOneWidget);
    expect(
        find.byWidgetPredicate((w) =>
            w is Tooltip && w.message == 'Online'),
        findsNothing);

    model.peersModel.peers
        .firstWhere((p) => p.id == 't-online-1')
        .online = true;
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    model.peersModel.notifyListeners();
    await tester.pump();

    expect(find.byWidgetPredicate((w) => w is Tooltip && w.message == 'Online'),
        findsOneWidget);
    await unmount(tester);
  });

  testWidgets('seção de grupo colapsa ao tocar no cabeçalho', (tester) async {
    final model = gFFI.carteiraModel;
    model.addPeer('t-collapse-1', 'Caixa Colapso', 'Grupo Colapso');
    await pumpCarteira(tester);
    expect(find.text('Caixa Colapso'), findsOneWidget);

    await tester.tap(find.text('Grupo Colapso'));
    await tester.pump();
    expect(find.text('Caixa Colapso'), findsNothing);

    await tester.tap(find.text('Grupo Colapso'));
    await tester.pump();
    expect(find.text('Caixa Colapso'), findsOneWidget);
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
    expect(find.text('Add device'), findsNothing);
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
