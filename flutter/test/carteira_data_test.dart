import 'package:flutter_hbb/models/carteira_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CarteiraData', () {
    test('addPeer cria peer no grupo informado', () {
      final data = CarteiraData();
      data.addPeer('123456789', 'Caixa 1', 'Padaria Central');
      expect(data.peers.single.id, '123456789');
      expect(data.peers.single.alias, 'Caixa 1');
      expect(data.peers.single.groupName, 'Padaria Central');
      expect(data.groups, ['Padaria Central']);
    });

    test('addPeer sem grupo deixa o peer sem grupo', () {
      final data = CarteiraData();
      data.addPeer('123456789', 'Caixa 1', '');
      expect(data.peers.single.groupName, '');
      expect(data.groups, isEmpty);
    });

    test('addPeer com id existente atualiza sem duplicar', () {
      final data = CarteiraData();
      data.addPeer('123', 'A', 'G1');
      data.addPeer('123', 'B', 'G2');
      expect(data.peers.length, 1);
      expect(data.peers.single.alias, 'B');
      expect(data.peers.single.groupName, 'G2');
      expect(data.groups, ['G2']);
    });

    test('moveToGroup muda o grupo do peer', () {
      final data = CarteiraData();
      data.addPeer('123', 'A', 'G1');
      data.moveToGroup('123', 'G2');
      expect(data.peers.single.groupName, 'G2');
      expect(data.groups, ['G2']);
    });

    test('renameGroup migra todos os peers do grupo', () {
      final data = CarteiraData();
      data.addPeer('1', 'A', 'Velho');
      data.addPeer('2', 'B', 'Velho');
      data.addPeer('3', 'C', 'Outro');
      data.renameGroup('Velho', 'Novo');
      expect(data.peersInGroup('Novo').map((p) => p.id), ['1', '2']);
      expect(data.peersInGroup('Velho'), isEmpty);
      expect(data.groups, ['Novo', 'Outro']);
    });

    test('removePeer remove o peer e grupo vazio some', () {
      final data = CarteiraData();
      data.addPeer('1', 'A', 'G1');
      data.addPeer('2', 'B', 'G2');
      data.removePeer('1');
      expect(data.peers.map((p) => p.id), ['2']);
      expect(data.groups, ['G2']);
    });

    test('roundtrip serialize/deserialize preserva tudo', () {
      final data = CarteiraData();
      data.addPeer('1', 'Caixa 1', 'Padaria');
      data.addPeer('2', 'Notebook', '');
      final restored = CarteiraData.deserialize(data.serialize());
      expect(restored.peers.length, 2);
      expect(restored.peers[0].id, '1');
      expect(restored.peers[0].alias, 'Caixa 1');
      expect(restored.peers[0].groupName, 'Padaria');
      expect(restored.peers[1].groupName, '');
      expect(restored.groups, ['Padaria']);
    });

    test('rede e filial nascem vazias, sem dispositivo, e voltam salvas', () {
      final data = CarteiraData();
      data.addGroup('Padaria Pão Quente');
      data.addGroup('Padaria Pão Quente / Filial Centro');
      expect(data.groups, ['Padaria Pão Quente', 'Padaria Pão Quente / Filial Centro']);
      expect(data.peers, isEmpty);
      expect(CarteiraData.deserialize(data.serialize()).groups, data.groups);
    });

    test('renomear a rede leva as filiais e os dispositivos dela', () {
      final data = CarteiraData();
      data.addGroup('Rede Velha / Filial Vazia');
      data.addPeer('1', 'Caixa', 'Rede Velha / Filial Cheia');
      data.renameGroup('Rede Velha', 'Rede Nova');
      expect(data.groups, ['Rede Nova / Filial Cheia', 'Rede Nova / Filial Vazia']);
    });

    test('excluir tira só o grupo vazio', () {
      final data = CarteiraData();
      data.addGroup('Rede / Vazia');
      data.addPeer('1', 'Caixa', 'Rede / Cheia');
      data.removeGroup('Rede / Vazia');
      data.removeGroup('Rede / Cheia');
      expect(data.groups, ['Rede / Cheia']);
    });

    test('deserialize com json inválido retorna carteira vazia', () {
      expect(CarteiraData.deserialize('não é json').peers, isEmpty);
      expect(CarteiraData.deserialize('{"peers": 42}').peers, isEmpty);
      expect(CarteiraData.deserialize('').peers, isEmpty);
    });
  });
}
