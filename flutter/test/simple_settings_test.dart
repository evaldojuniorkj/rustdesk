import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/desktop/pages/simple_settings_page.dart';
import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Binding extends Fake implements RustdeskImpl {
  bool permanentPasswordSet = false;
  final options = <String, String>{
    'custom-rendezvous-server': 'id.exemplo.com.br:21116',
    'relay-server': 'relay.exemplo.com.br:21117',
  };

  @override
  Future<String> mainGetCommon({required String key, dynamic hint}) async =>
      key == 'permanent-password-set' ? '$permanentPasswordSet' : '';

  @override
  String mainGetOptionSync({required String key, dynamic hint}) =>
      options[key] ?? '';

  @override
  Future<void> mainSetOption(
          {required String key, required String value, dynamic hint}) async =>
      options[key] = value;

  @override
  Future<String> mainGetVersion({dynamic hint}) async => '1.4.4';

  @override
  Future<String> mainGetLangs({dynamic hint}) async => '[]';

  @override
  bool mainIsOptionFixed({required String key, dynamic hint}) => false;

  @override
  bool mainIsInstalled({dynamic hint}) => false;

  @override
  bool isCustomClient({dynamic hint}) => false;

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

  Future<void> openTab(WidgetTester tester, String tab) async {
    tester.view.physicalSize = const Size(1100, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: MyTheme.lightTheme,
        home: Scaffold(
            body: SimpleSettingsView(key: UniqueKey(), onAdvanced: () {}))));
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  bool switchValue(WidgetTester tester, String label) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, label))
      .value;

  testWidgets('acesso não supervisionado segue a senha permanente',
      (tester) async {
    await openTab(tester, 'Segurança');
    expect(switchValue(tester, 'Acesso não supervisionado'), isFalse);
    expect(find.text('Cadastrada'), findsNothing);

    binding.permanentPasswordSet = true;
    addTearDown(() => binding.permanentPasswordSet = false);
    await openTab(tester, 'Segurança');
    expect(switchValue(tester, 'Acesso não supervisionado'), isTrue);
    expect(find.text('Cadastrada'), findsOneWidget);
  });

  testWidgets('desligar uma permissão grava a opção do RustDesk',
      (tester) async {
    await openTab(tester, 'Segurança');
    expect(switchValue(tester, 'Transferir arquivos'), isTrue);

    await tester.tap(find.text('Transferir arquivos'));
    await tester.pumpAndSettle();
    expect(binding.options['enable-file-transfer'], 'N');
    expect(switchValue(tester, 'Transferir arquivos'), isFalse);
  });

  testWidgets('Rede mostra os servidores sem deixar editar', (tester) async {
    await openTab(tester, 'Rede');
    for (final server in ['id.exemplo.com.br:21116', 'relay.exemplo.com.br:21117']) {
      final field =
          tester.widget<TextField>(find.widgetWithText(TextField, server));
      expect(field.readOnly, isTrue);
    }
  });
}
