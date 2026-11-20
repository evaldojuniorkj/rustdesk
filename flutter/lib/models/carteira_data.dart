import 'dart:convert';

const carteiraGroupSeparator = ' / ';

bool carteiraGroupContains(String group, String path) =>
    path == group ||
    (group.isNotEmpty && path.startsWith('$group$carteiraGroupSeparator'));

class CarteiraPeer {
  final String id;
  String alias;
  String groupName;

  CarteiraPeer(this.id, this.alias, this.groupName);

  Map<String, dynamic> toJson() => {'id': id, 'alias': alias, 'group': groupName};

  static CarteiraPeer? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final alias = json['alias'];
    final group = json['group'];
    return CarteiraPeer(
      id,
      alias is String ? alias : '',
      group is String ? group : '',
    );
  }
}

/// Pure data + rules for the "Carteira" (wallet) tab: peers grouped locally.
/// No Flutter/FFI imports so it can be unit-tested on the VM.
class CarteiraData {
  final List<CarteiraPeer> peers = [];

  List<String> get groups {
    final names = peers.map((p) => p.groupName).where((g) => g.isNotEmpty).toSet().toList();
    names.sort();
    return names;
  }

  List<CarteiraPeer> peersInGroup(String group) =>
      peers.where((p) => p.groupName == group).toList();

  CarteiraPeer? peerById(String id) {
    for (final p in peers) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPeer(String id, String alias, String groupName) {
    final existing = peerById(id);
    if (existing != null) {
      existing.alias = alias;
      existing.groupName = groupName;
      return;
    }
    peers.add(CarteiraPeer(id, alias, groupName));
  }

  void removePeer(String id) {
    peers.removeWhere((p) => p.id == id);
  }

  void moveToGroup(String id, String groupName) {
    peerById(id)?.groupName = groupName;
  }

  void renameGroup(String oldName, String newName) {
    for (final p in peers) {
      if (p.groupName == oldName) p.groupName = newName;
    }
  }

  String serialize() => jsonEncode({'peers': peers.map((p) => p.toJson()).toList()});

  static CarteiraData deserialize(String json) {
    final data = CarteiraData();
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) return data;
      final list = decoded['peers'];
      if (list is! List) return data;
      for (final entry in list) {
        final peer = CarteiraPeer.fromJson(entry);
        if (peer != null) data.peers.add(peer);
      }
    } catch (_) {
      // invalid json -> empty wallet
    }
    return data;
  }
}
