import 'package:flutter_hbb/generated_bridge.dart';
import 'package:flutter_hbb/models/carteira_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_test/flutter_test.dart';

class _Binding extends Fake implements RustdeskImpl {
  final Map<String, String> options = {};

  @override
  String getLocalFlutterOption({required String k, dynamic hint}) =>
      options[k] ?? '';

  @override
  Future<void> setLocalFlutterOption(
      {required String k, required String v, dynamic hint}) async {
    options[k] = v;
  }
}

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
  });
}
