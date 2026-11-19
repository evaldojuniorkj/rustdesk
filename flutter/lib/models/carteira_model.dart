import 'package:get/get.dart';

import '../common/widgets/peers_view.dart';
import 'carteira_data.dart';
import 'model.dart';
import 'peer_model.dart';
import 'platform_model.dart';

const kOptionCarteiraData = 'carteira-data';

/// Observable wrapper around [CarteiraData] with local persistence via
/// flutter options (RustDesk2.toml). Follows the ab_model.dart pattern.
class CarteiraModel {
  WeakReference<FFI>? parent;

  CarteiraModel(this.parent) {
    peersModel = Peers(
        name: PeersModelName.carteira,
        getInitPeers: null,
        loadEvent: LoadEvent.carteira);
  }

  final peers = <CarteiraPeer>[].obs;
  final groups = <String>[].obs;

  late final Peers peersModel;

  CarteiraData _data = CarteiraData();
  bool _loaded = false;

  void ensureLoaded() {
    if (_loaded) return;
    _loaded = true;
    _data =
        CarteiraData.deserialize(bind.getLocalFlutterOption(k: kOptionCarteiraData));
    _syncObs();
  }

  void _syncObs() {
    peers.value = List.of(_data.peers);
    groups.value = _data.groups;
    peersModel.peers = _data.peers.map(toViewPeer).toList();
  }

  /// Builds a view [Peer] for a wallet entry, merging the last known state
  /// from Recent/Favorites when available.
  Peer toViewPeer(CarteiraPeer cp) {
    final known = knownPeer(cp.id);
    final peer = known != null ? Peer.copy(known) : Peer.fromJson({'id': cp.id});
    if (cp.alias.isNotEmpty) peer.alias = cp.alias;
    return peer;
  }

  Future<void> _save() =>
      bind.setLocalFlutterOption(k: kOptionCarteiraData, v: _data.serialize());

  void addPeer(String id, String alias, String groupName) {
    ensureLoaded();
    _data.addPeer(id, alias, groupName);
    _syncObs();
    _save();
  }

  void removePeer(String id) {
    ensureLoaded();
    _data.removePeer(id);
    _syncObs();
    _save();
  }

  void moveToGroup(String id, String groupName) {
    ensureLoaded();
    _data.moveToGroup(id, groupName);
    _syncObs();
    _save();
  }

  void renameGroup(String oldName, String newName) {
    ensureLoaded();
    _data.renameGroup(oldName, newName);
    _syncObs();
    _save();
  }

  bool contains(String id) {
    ensureLoaded();
    return _data.peerById(id) != null;
  }

  String groupOf(String id) {
    ensureLoaded();
    return _data.peerById(id)?.groupName ?? '';
  }

  /// Imports peers from Recent and Favorites that are not in the wallet yet,
  /// into the ungrouped bucket. Returns how many were imported.
  int importFromRecentAndFavorites() {
    ensureLoaded();
    final ffi = parent?.target;
    if (ffi == null) return 0;
    var added = 0;
    for (final model in [ffi.recentPeersModel, ffi.favoritePeersModel]) {
      for (final p in model.peers) {
        if (_data.peerById(p.id) == null) {
          _data.addPeer(p.id, p.alias, '');
          added++;
        }
      }
    }
    if (added > 0) {
      _syncObs();
      _save();
    }
    return added;
  }

  /// Last known peer (online state etc.) from Recent/Favorites, if present.
  Peer? knownPeer(String id) {
    final ffi = parent?.target;
    if (ffi == null) return null;
    for (final model in [ffi.recentPeersModel, ffi.favoritePeersModel]) {
      for (final p in model.peers) {
        if (p.id == id) return p;
      }
    }
    return null;
  }
}
