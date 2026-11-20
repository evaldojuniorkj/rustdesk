import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/support_page.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Binding extends Fake implements RustdeskImpl {
  bool permanentPasswordSet = false;
  final connected = <String>[];

  @override
  Future<String> mainGetCommon({required String key, dynamic hint}) async =>
      switch (key) {
        'permanent-password-set' => '$permanentPasswordSet',
        'is-remote-modify-enabled-by-control-permissions' => 'false',
        _ => '',
      };

  /// The first call `connect` makes; never completes, so no window opens.
  @override
  Future<String> mainHandleRelayId({required String id, dynamic hint}) {
    connected.add(id);
    return Completer<String>().future;
  }

  @override
  Future<void> mainLoadRecentPeers({dynamic hint}) async {}

  @override
  bool mainIsCanScreenRecording({required bool prompt, dynamic hint}) => true;

  @override
  bool mainIsProcessTrusted({required bool prompt, dynamic hint}) => true;

  @override
  bool mainIsCanInputMonitoring({required bool prompt, dynamic hint}) => true;

  @override
  Future<void> mainCheckMouseTime({dynamic hint}) async {}

  @override
  Future<double> mainGetMouseTime({dynamic hint}) async => 0;

  @override
  String getLocalFlutterOption({required String k, dynamic hint}) => '';

  @override
  Future<void> setLocalFlutterOption(
      {required String k, required String v, dynamic hint}) async {}

  @override
  String translate({required String name, required String locale, dynamic hint}) =>
      name;

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

  Future<void> pumpSupport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    gFFI.serverModel.serverId.text = '482 913 027';
    gFFI.serverModel.serverPasswd.text = 'k7m2xq';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SupportView(onClassic: () {}))));
    // Runs the first refresh, which periodic_immediate defers by zero time.
    await tester.pump(Duration.zero);
    await tester.pump();
  }

  testWidgets('mostra o ID deste computador e nenhuma senha', (tester) async {
    await pumpSupport(tester);
    expect(find.text('482 913 027'), findsOneWidget);
    expect(find.text('Acesso só com a sua aprovação'), findsOneWidget);
    expect(find.text('k7m2xq'), findsNothing);
  });

  testWidgets('com senha cadastrada avisa o acesso não supervisionado',
      (tester) async {
    binding.permanentPasswordSet = true;
    addTearDown(() => binding.permanentPasswordSet = false);
    await pumpSupport(tester);
    expect(find.text('Acesso não supervisionado ligado'), findsOneWidget);
    expect(find.text('Acesso só com a sua aprovação'), findsNothing);
  });

  testWidgets('conecta pelo ID digitado e pelas 4 sessões mais recentes',
      (tester) async {
    gFFI.recentPeersModel.peers = [
      for (var i = 1; i <= 5; i++)
        Peer.fromJson({'id': '10000000$i', 'alias': 'Caixa $i'}),
    ];
    addTearDown(() => gFFI.recentPeersModel.peers = []);
    binding.connected.clear();
    await pumpSupport(tester);

    expect(find.text('Caixa 4'), findsOneWidget);
    expect(find.text('Caixa 5'), findsNothing);

    await tester.enterText(find.byType(TextField), '318 204 557');
    await tester.tap(find.text('Connect'));
    await tester.tap(find.text('Caixa 2'));
    await tester.pump();
    expect(binding.connected, ['318204557', '100000002']);
  });
}
