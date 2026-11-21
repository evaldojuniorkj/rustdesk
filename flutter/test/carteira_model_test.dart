import 'dart:convert';

import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/carteira_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body) => http.Response(jsonEncode(body), 200);

final _login = _json({
  'token': 't1',
  'usuario': {'nome': 'Ana'}
});

class _Binding extends Fake implements RustdeskImpl {
  final Map<String, String> options = {};

  /// The real bridges write options asynchronously.
  bool slowWrites = false;

  @override
  String getLocalFlutterOption({required String k, dynamic hint}) =>
      options[k] ?? '';

  @override
  Future<void> setLocalFlutterOption(
      {required String k, required String v, dynamic hint}) async {
    if (slowWrites) await Future<void>.delayed(Duration.zero);
    options[k] = v;
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('CarteiraModel', () {
    late _Binding binding;

    setUp(() {
      binding = _Binding();
      platformFFI.setBindingForTesting(binding);
    });

    test('addPeer persiste e recarrega em nova instância', () {
      final m = CarteiraModel(null);
      m.addPeer('123', 'Caixa 1', 'Padaria');

      final m2 = CarteiraModel(null);
      m2.ensureLoaded();
      expect(m2.peers.single.id, '123');
      expect(m2.peers.single.alias, 'Caixa 1');
      expect(m2.groups, ['Padaria']);
    });

    test('moveToGroup e renameGroup atualizam observáveis e persistem', () {
      final m = CarteiraModel(null);
      m.addPeer('1', 'A', 'Velho');
      m.addPeer('2', 'B', '');

      m.moveToGroup('2', 'Velho');
      expect(m.groups, ['Velho']);
      expect(m.groupOf('2'), 'Velho');

      m.renameGroup('Velho', 'Novo');
      expect(m.groups, ['Novo']);
      expect(m.groupOf('1'), 'Novo');
      expect(m.groupOf('2'), 'Novo');

      final m2 = CarteiraModel(null);
      m2.ensureLoaded();
      expect(m2.groups, ['Novo']);
      expect(m2.peers.length, 2);
    });

    test('removePeer e contains refletem a carteira', () {
      final m = CarteiraModel(null);
      expect(m.contains('1'), isFalse);
      m.addPeer('1', 'A', '');
      expect(m.contains('1'), isTrue);
      m.removePeer('1');
      expect(m.contains('1'), isFalse);
      expect(m.peers, isEmpty);
    });

    test('login fica salvo e volta numa nova abertura do app', () async {
      final m = CarteiraModel(null);
      await http.runWithClient(
          () => m.signIn('ana', 'segredo'),
          () => MockClient((req) async => req.url.path == '/suporte/entrar'
              ? _login
              : _json({'revisao': 1, 'dispositivos': []})));
      expect(m.account.value, 'Ana');

      final m2 = CarteiraModel(null);
      await http.runWithClient(() async {
        m2.ensureLoaded();
        expect(m2.account.value, 'Ana');
        await _settle();
      }, () => MockClient((req) async => _json({'revisao': 1, 'dispositivos': []})));
    });

    test('criar conta entra nela e o e-mail repetido é explicado', () async {
      Map<String, dynamic>? sent;
      final m = CarteiraModel(null);
      await http.runWithClient(
          () => m.signUp('Ana', 'ana@teste.local', 'segredo-forte'),
          () => MockClient((req) async {
                if (req.url.path == '/suporte/contas') {
                  sent = jsonDecode(req.body) as Map<String, dynamic>;
                  return _login;
                }
                return _json({'revisao': 0, 'dispositivos': []});
              }));
      expect(sent, {'nome': 'Ana', 'email': 'ana@teste.local', 'senha': 'segredo-forte'});
      expect(m.account.value, 'Ana');
      expect(binding.options[kOptionCarteiraSession], contains('t1'));

      final outro = CarteiraModel(null);
      await http.runWithClient(
          () => outro.signUp('Ana', 'ana@teste.local', 'segredo-forte'),
          () => MockClient((req) async => http.Response('{}', 409)));
      expect(outro.syncError.value, 'Já existe uma conta com este e-mail.');
    });

    test('token recusado pelo servidor sai da conta', () async {
      binding.slowWrites = true;
      binding.options[kOptionCarteiraSession] =
          jsonEncode({'token': 'velho', 'account': 'Ana'});
      final m = CarteiraModel(null);
      await http.runWithClient(() async {
        m.ensureLoaded();
        expect(m.account.value, 'Ana');
        await m.refreshRemote();
        await _settle();
      }, () => MockClient((req) async => http.Response('', 401)));
      expect(m.account.value, isNull);

      await _settle();
      final m2 = CarteiraModel(null);
      m2.ensureLoaded();
      expect(m2.account.value, isNull);
    });

    test('sessão salva mostra a carteira da conta, nunca a deste computador',
        () async {
      CarteiraModel(null).addPeer('L', 'Caixa Local', 'Loja');
      binding.options[kOptionCarteiraSession] =
          jsonEncode({'token': 't1', 'account': 'Ana'});
      final m = CarteiraModel(null);
      await http.runWithClient(() async {
        m.ensureLoaded();
        expect(m.peers, isEmpty);
        await _settle();
      }, () => MockClient((req) async => _json({
            'revisao': 3,
            'dispositivos': [
              {'id': 'R', 'alias': 'Caixa da Conta', 'group': 'Loja'}
            ]
          })));
      expect(m.peers.map((p) => p.id), ['R']);
    });

    test('levar a carteira local para a conta junta só o que falta', () async {
      final m = CarteiraModel(null);
      m.addPeer('A', 'Caixa A', 'Loja');
      m.addPeer('B', 'Caixa B', 'Loja');
      Map<String, dynamic>? sent;
      final server = MockClient((req) async {
        if (req.url.path == '/suporte/entrar') return _login;
        if (req.method == 'PUT') {
          sent = jsonDecode(req.body) as Map<String, dynamic>;
          return _json({'revisao': 2, 'dispositivos': sent!['dispositivos']});
        }
        return _json({
          'revisao': 1,
          'dispositivos': [
            {'id': 'A', 'alias': 'Caixa A da conta', 'group': 'Loja'}
          ]
        });
      });

      await http.runWithClient(() async {
        await m.signIn('ana', 'segredo');
        expect(m.localOnlyCount, 1);
        await m.mergeLocalIntoAccount();
      }, () => server);

      final ids = (sent!['dispositivos'] as List).map((d) => d['id']);
      expect(ids, containsAll(['A', 'B']));
      expect(m.peers.map((p) => p.id), containsAll(['A', 'B']));
      expect(m.peers.firstWhere((p) => p.id == 'A').alias, 'Caixa A da conta');
      expect(m.localOnlyCount, 0);
    });
  });
}
