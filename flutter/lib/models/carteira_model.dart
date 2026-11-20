import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;

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
  static const _apiHost = 'api.devstartx.vps-kinghost.net';
  final account = RxnString();
  final syncError = RxnString();
  final syncing = false.obs;
  String? _token;
  int _revision = 0;

  Future<Map<String, dynamic>> _request(String method, String path,
      {String? token, Map<String, dynamic>? body}) async {
    final client = http.Client();
    try {
      final request = http.Request(method, Uri.https(_apiHost, path))
        ..followRedirects = false
        ..headers['Accept'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await client.send(request).then(http.Response.fromStream)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 204) return {};
      if (response.statusCode == 401) {
        throw const FormatException('Confira seu login ou entre novamente.');
      }
      if (response.statusCode == 403) {
        throw const FormatException('Use uma conta interna do Start X.');
      }
      if (response.statusCode == 409) {
        throw const FormatException('A carteira mudou em outro computador. Atualize e tente novamente.');
      }
      if (response.statusCode != 200) {
        throw const FormatException('Serviço da Carteira indisponível.');
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
    } finally {
      client.close();
    }
  }

  Future<void> _runSync(Future<void> Function() action) async {
    if (syncing.value) return;
    syncing.value = true;
    syncError.value = null;
    try {
      await action();
    } on FormatException catch (error) {
      syncError.value = error.message;
    } catch (_) {
      syncError.value = 'Não foi possível sincronizar com o Start X.';
    } finally {
      syncing.value = false;
    }
  }

  void _applyRemote(Map<String, dynamic> remote) {
    final revision = remote['revisao'] as int;
    final devices = remote['dispositivos'] as List<dynamic>;
    _data = CarteiraData.deserialize(jsonEncode({'peers': devices}));
    _revision = revision;
    _syncObs();
  }

  Future<void> signIn(String login, String password) => _runSync(() async {
        final session = await _request('POST', '/auth/entrar',
            body: {'login': login.trim(), 'senha': password});
        final token = session['token'] as String;
        try {
          final remote = await _request('GET', '/suporte/carteira', token: token);
          final user = session['usuario'] as Map<String, dynamic>;
          _applyRemote(remote);
          _token = token;
          account.value = user['nome'] as String? ?? login;
        } catch (_) {
          try {
            await _request('POST', '/auth/sair', token: token);
          } catch (_) {
            // The unused session expires on the server.
          }
          rethrow;
        }
      });

  Future<void> refreshRemote() async {
    final token = _token;
    if (token == null) return;
    await _runSync(() async {
      _applyRemote(await _request('GET', '/suporte/carteira', token: token));
    });
  }

  Future<void> signOut() async {
    final token = _token;
    if (token == null) return;
    await _runSync(() async {
      _token = null;
      account.value = null;
      _loaded = false;
      ensureLoaded();
      await _request('POST', '/auth/sair', token: token);
    });
  }

  void _change(void Function(CarteiraData data) apply) {
    ensureLoaded();
    final token = _token;
    if (token == null) {
      apply(_data);
      _syncObs();
      _save();
      return;
    }
    _runSync(() async {
      final edited = CarteiraData.deserialize(_data.serialize());
      apply(edited);
      final result = await _request('PUT', '/suporte/carteira', token: token,
          body: {
            'revisao': _revision,
            'dispositivos': edited.peers.map((peer) => peer.toJson()).toList(),
          });
      _applyRemote(result);
    });
  }

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

  void addPeer(String id, String alias, String groupName) =>
      _change((data) => data.addPeer(id, alias, groupName));

  void removePeer(String id) => _change((data) => data.removePeer(id));

  void moveToGroup(String id, String groupName) =>
      _change((data) => data.moveToGroup(id, groupName));

  void renameGroup(String oldName, String newName) =>
      _change((data) => data.renameGroup(oldName, newName));

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
    final pending = <String, String>{};
    for (final model in [ffi.recentPeersModel, ffi.favoritePeersModel]) {
      for (final p in model.peers) {
        if (_data.peerById(p.id) == null) pending.putIfAbsent(p.id, () => p.alias);
      }
    }
    if (pending.isNotEmpty) {
      _change((data) {
        pending.forEach((id, alias) {
          if (data.peerById(id) == null) data.addPeer(id, alias, '');
        });
      });
    }
    return pending.length;
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
