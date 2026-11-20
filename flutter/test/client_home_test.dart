import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/client_home_page.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Binding extends Fake implements RustdeskImpl {
  bool permanentPasswordSet = false;

  /// True while a remote controller is moving the mouse on this computer.
  bool remoteMouse = false;

  @override
  Future<String> mainGetCommon({required String key, dynamic hint}) async =>
      switch (key) {
        'permanent-password-set' => '$permanentPasswordSet',
        'is-remote-modify-enabled-by-control-permissions' => 'false',
        _ => '',
      };

  @override
  Future<void> mainCheckMouseTime({dynamic hint}) async {}

  @override
  Future<double> mainGetMouseTime({dynamic hint}) async => remoteMouse
      ? DateTime.now().millisecondsSinceEpoch.toDouble()
      : 0;

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

  Future<void> pumpClient(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    gFFI.serverModel.serverId.text = '482 913 027';
    gFFI.serverModel.serverPasswd.text = 'k7m2xq';
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ClientHomeView())));
    await tester.pump();
  }

  testWidgets('mostra o endereço deste computador e nenhuma senha',
      (tester) async {
    await pumpClient(tester);
    expect(find.text('Seu endereço'), findsOneWidget);
    expect(find.text('482 913 027'), findsOneWidget);
    expect(find.text('k7m2xq'), findsNothing);
  });

  testWidgets('Convidar copia uma mensagem com o endereço', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpClient(tester);

    await tester.tap(find.text('Convidar'));
    await tester.pump();
    expect(copied, contains('482 913 027'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('quem acessa remotamente não consegue mexer nesta tela',
      (tester) async {
    binding.remoteMouse = true;
    addTearDown(() => binding.remoteMouse = false);
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpClient(tester);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.text('Seu endereço')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Convidar'), warnIfMissed: false);
    await tester.pump();
    expect(copied, isNull);
    await mouse.removePointer();
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('com senha cadastrada o acesso não supervisionado oferece Desligar',
      (tester) async {
    binding.permanentPasswordSet = true;
    addTearDown(() => binding.permanentPasswordSet = false);
    await pumpClient(tester);
    await tester.pump();
    expect(find.text('Desligar…'), findsOneWidget);
    expect(find.text('Configurar senha…'), findsNothing);
  });
}
