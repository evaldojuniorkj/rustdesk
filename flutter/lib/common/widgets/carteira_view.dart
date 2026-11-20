import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/carteira_data.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../consts.dart';
import '../../models/platform_model.dart';
import '../formatter/id_formatter.dart';
import 'dialog.dart';
import 'peer_card.dart';
import 'peers_view.dart';

/// "Carteira" tab: client groups (Empresa / Filial) as a tree table.
class CarteiraPeersView extends BasePeersView {
  /// Also lists Recent sessions and Favorites on top (technician home).
  final bool showRecentAndFavorites;

  CarteiraPeersView(
      {Key? key, EdgeInsets? menuPadding, this.showRecentAndFavorites = false})
      : super(
          key: key,
          peerTabIndex: PeerTabIndex.carteira,
          peerCardBuilder: (Peer peer) => CarteiraPeerCard(
            peer: peer,
            menuPadding: menuPadding,
          ),
        );

  @override
  Widget build(BuildContext context) {
    return _CarteiraBody(
        peerCardBuilder: peerCardBuilder,
        showRecentAndFavorites: showRecentAndFavorites);
  }
}

class _CarteiraBody extends StatefulWidget {
  final PeerCardBuilder peerCardBuilder;
  final bool showRecentAndFavorites;

  const _CarteiraBody(
      {Key? key,
      required this.peerCardBuilder,
      required this.showRecentAndFavorites})
      : super(key: key);

  @override
  State<_CarteiraBody> createState() => _CarteiraBodyState();
}

class _CarteiraBodyState extends State<_CarteiraBody> {
  static const _queryInterval = Duration(seconds: 20);
  Timer? _onlineTimer;
  final _collapsed = <String>{};

  @override
  void initState() {
    super.initState();
    final model = gFFI.carteiraModel;
    model.ensureLoaded();
    model.refreshRemote();
    // Refresh last-known online states from Recent/Favorites.
    bind.mainLoadRecentPeers();
    bind.mainLoadFavPeers();
    _queryOnlines();
    _onlineTimer = Timer.periodic(_queryInterval, (_) => _queryOnlines());
  }

  @override
  void dispose() {
    _onlineTimer?.cancel();
    super.dispose();
  }

  void _queryOnlines() {
    final ids = {
      ...gFFI.carteiraModel.peers.map((p) => p.id),
      if (widget.showRecentAndFavorites) ...[
        ...gFFI.recentPeersModel.peers.map((p) => p.id),
        ...gFFI.favoritePeersModel.peers.map((p) => p.id),
      ],
    }.toList(growable: false);
    if (ids.isNotEmpty) {
      bind.queryOnlines(ids: ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = gFFI.carteiraModel;
    // LayoutBuilder stays outside Obx so every observable is read in Obx scope.
    Widget body() => LayoutBuilder(
      builder: (context, constraints) => ChangeNotifierProvider<Peers>.value(
        value: model.peersModel,
        child: Consumer<Peers>(builder: (context, peersModel, child) {
          final viewPeers = {for (final p in peersModel.peers) p.id: p};
          return Obx(() {
            final search = peerSearchText.value.trim().toLowerCase();
            bool hit(CarteiraPeer p) =>
                search.isEmpty ||
                p.id.toLowerCase().contains(search) ||
                p.alias.toLowerCase().contains(search) ||
                p.groupName.toLowerCase().contains(search);
            final groups = <String, Set<String>>{};
            for (final group in model.groups) {
              var parent = '';
              for (final part in group.split(carteiraGroupSeparator)) {
                final path = parent.isEmpty
                    ? part
                    : '$parent$carteiraGroupSeparator$part';
                groups.putIfAbsent(parent, () => {}).add(path);
                parent = path;
              }
            }
            final compact = constraints.maxWidth < 720;
            final busy = model.syncing.value;
            final rows = <Widget>[];
            // '' is the ungrouped bucket; it is also the root key of [groups].
            void addGroup(String path, int depth) {
              final members = model.peers
                  .where((peer) => carteiraGroupContains(path, peer.groupName))
                  .toList();
              if (!members.any(hit)) return;
              final open = search.isNotEmpty || !_collapsed.contains(path);
              final online = members
                  .where((peer) => viewPeers[peer.id]?.online == true)
                  .length;
              // renameGroup only renames exact matches, so a company that
              // only holds filiais gets no rename button.
              final renamable = path.isNotEmpty &&
                  members.any((peer) => peer.groupName == path);
              rows.add(_groupRow(
                  path, depth, online, members.length, open, renamable));
              if (!open) return;
              if (path.isNotEmpty) {
                for (final child in groups[path] ?? const <String>{}) {
                  addGroup(child, depth + 1);
                }
              }
              for (final peer in model.peers) {
                if (peer.groupName == path && hit(peer)) {
                  rows.add(_peerRow(viewPeers[peer.id] ?? model.toViewPeer(peer),
                      depth + 1, compact));
                }
              }
            }

            if (widget.showRecentAndFavorites) {
              bool hitPeer(Peer p) =>
                  search.isEmpty ||
                  p.id.toLowerCase().contains(search) ||
                  p.alias.toLowerCase().contains(search) ||
                  p.hostname.toLowerCase().contains(search);
              // Section keys start with \u0001 so they never clash with a
              // group path in [_collapsed].
              void addSection(String key, String label, IconData icon,
                  List<Peer> peers, PeerTabIndex tab) {
                final matches = peers.where(hitPeer).toList();
                if (matches.isEmpty) return;
                final open = search.isNotEmpty || !_collapsed.contains(key);
                rows.add(_groupRow(key, 0, peers.where((p) => p.online).length,
                    peers.length, open, false,
                    label: label, icon: icon, dropTarget: false));
                if (!open) return;
                for (final peer in matches) {
                  rows.add(_peerRow(peer, 1, compact, tab: tab));
                }
              }

              addSection('\u0001recent', translate('Recent sessions'),
                  Icons.access_time, gFFI.recentPeersModel.peers,
                  PeerTabIndex.recent);
              addSection('\u0001fav', translate('Favorites'),
                  Icons.star_border, gFFI.favoritePeersModel.peers,
                  PeerTabIndex.fav);
            }
            for (final group in groups[''] ?? const <String>{}) {
              addGroup(group, 0);
            }
            addGroup('', 0);

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (kStartXDevEdition == 'technician') _buildAccount(),
                AbsorbPointer(
                  absorbing: busy,
                  child: _buildActions(context),
                ),
                _headerRow(compact),
                if (rows.isEmpty)
                  Center(child: Text(translate('Empty'))).paddingAll(24)
                else
                  AbsorbPointer(absorbing: busy, child: Column(children: rows)),
              ],
            );
          });
        }),
      ),
    );
    if (!widget.showRecentAndFavorites) return body();
    return ListenableBuilder(
      listenable:
          Listenable.merge([gFFI.recentPeersModel, gFFI.favoritePeersModel]),
      builder: (context, _) => body(),
    );
  }

  Color _muted() =>
      (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)
          .withOpacity(0.65);

  BoxDecoration _rowLine() => BoxDecoration(
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)));

  Widget _pill(String text, Color color, {bool dot = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot)
            Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
      );

  Widget _cells(bool compact, Widget name, Widget id, Widget status,
      Widget platform, Widget actions) {
    Widget cell(double width, Widget child) => SizedBox(
        width: width,
        child: Align(alignment: Alignment.centerLeft, child: child));
    return Row(children: [
      Expanded(child: name),
      if (!compact) cell(140, id),
      cell(compact ? 28 : 110, status),
      if (!compact) cell(140, platform),
      SizedBox(
          width: compact ? 48 : 170,
          child: Align(alignment: Alignment.centerRight, child: actions)),
    ]);
  }

  Widget _headerRow(bool compact) {
    final style = TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: _muted());
    Text label(String text) => Text(text.toUpperCase(), style: style);
    return Container(
      height: 36,
      decoration: _rowLine(),
      child: _cells(compact, label(translate('Name')).paddingOnly(left: 8),
          label('ID'),
          compact ? const SizedBox() : label(translate('Status')),
          label(translate('Platform')),
          const SizedBox()),
    );
  }

  Widget _groupRow(String path, int depth, int online, int total, bool open,
      bool renamable,
      {String? label,
      IconData icon = Icons.folder_outlined,
      bool dropTarget = true}) {
    final primary = Theme.of(context).colorScheme.primary;
    label ??= path.isEmpty
        ? translate('Ungrouped')
        : path.split(carteiraGroupSeparator).last;
    void toggle() => setState(() {
          if (!_collapsed.remove(path)) _collapsed.add(path);
        });
    final row = Material(
      color: primary.withOpacity(0.06),
      child: InkWell(
        onTap: toggle,
        child: Container(
          height: 40,
          padding: EdgeInsets.only(left: depth * 24.0),
          decoration: _rowLine(),
          child: Row(children: [
            IconButton(
              tooltip: label,
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: toggle,
              icon: AnimatedRotation(
                turns: open ? 0.25 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.chevron_right),
              ),
            ),
            Icon(icon, size: 18, color: MyTheme.brandMid),
            const SizedBox(width: 8),
            Expanded(
              child: Row(children: [
                Flexible(
                  child: Text(label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                _pill('$online/$total online', primary),
              ]),
            ),
            if (renamable)
              IconButton(
                tooltip: translate('Rename'),
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () => _renameGroupDialog(context, path),
                icon: const Icon(Icons.edit_outlined),
              ),
          ]),
        ),
      ),
    );
    if (!dropTarget) return row;
    return DragTarget<String>(
      onAcceptWithDetails: (details) => _dropOnGroup(path, details.data),
      builder: (context, candidates, _) => candidates.isEmpty
          ? row
          : Container(
              foregroundDecoration: BoxDecoration(
                  color: primary.withOpacity(0.12),
                  border: Border.all(color: primary, width: 2)),
              child: row),
    );
  }

  /// A device dropped on a group moves there, or joins the wallet in it.
  void _dropOnGroup(String path, String id) {
    final model = gFFI.carteiraModel;
    if (!model.contains(id)) {
      model.addPeer(id, model.knownPeer(id)?.alias ?? '', path);
    } else if (model.groupOf(id) != path) {
      model.moveToGroup(id, path);
    }
  }

  Widget _peerRow(Peer peer, int depth, bool compact,
      {PeerTabIndex tab = PeerTabIndex.carteira}) {
    final muted = _muted();
    final host =
        [peer.username, peer.hostname].where((s) => s.isNotEmpty).join('@');
    final detail = compact ? formatID(peer.id) : host;
    void connect() => connectInPeerTab(context, peer, tab);
    BasePeerCard card() => switch (tab) {
          PeerTabIndex.recent => RecentPeerCard(peer: peer),
          PeerTabIndex.fav => FavoritePeerCard(peer: peer),
          _ => CarteiraPeerCard(peer: peer),
        };
    final more = Builder(
      builder: (button) => IconButton(
        tooltip: translate('More'),
        iconSize: 18,
        visualDensity: VisualDensity.compact,
        icon: const Icon(Icons.more_vert),
        onPressed: () {
          final box = button.findRenderObject() as RenderBox;
          final pos = box.localToGlobal(box.size.bottomCenter(Offset.zero));
          showPeerCardMenu(context, card(),
              RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy));
        },
      ),
    );
    final statusColor = peer.online ? Colors.green : muted;
    final name = peer.alias.isEmpty ? formatID(peer.id) : peer.alias;
    final nameCell = Row(children: [
      SizedBox(width: depth * 24.0 + 8),
      Icon(Icons.desktop_windows_outlined, size: 18, color: muted),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500)),
            if (detail.isNotEmpty)
              Text(detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
    ]);
    final feedback = Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.desktop_windows_outlined, size: 16),
          const SizedBox(width: 8),
          Text(name),
        ]),
      ),
    );
    final dragging = Opacity(opacity: 0.4, child: nameCell);
    // Only the name cell drags: with a mouse any 1 px move starts a drag, which
    // would swallow clicks on Connect and ⋮. Touch needs a long press so a
    // plain drag keeps scrolling the list.
    final draggableName = isMobile
        ? LongPressDraggable<String>(
            data: peer.id,
            feedback: feedback,
            childWhenDragging: dragging,
            child: nameCell)
        : Draggable<String>(
            data: peer.id,
            feedback: feedback,
            childWhenDragging: dragging,
            child: nameCell);
    return InkWell(
      // Same as the peer card: a tap connects on mobile.
      onTap: isMobile ? connect : null,
      onDoubleTap: connect,
      child: Container(
        height: 44,
        decoration: _rowLine(),
        child: _cells(
          compact,
          draggableName,
          Text(formatID(peer.id)),
          compact
              ? Tooltip(
                  message: peer.online ? 'Online' : 'Offline',
                  child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle)),
                )
              : _pill(peer.online ? 'Online' : 'Offline', statusColor,
                  dot: true),
          peer.platform.isEmpty
              ? const Text('—')
              : Row(children: [
                  // The platform SVGs are white, drawn for the colored card tile.
                  ColorFiltered(
                      colorFilter: ColorFilter.mode(muted, BlendMode.srcIn),
                      child: getPlatformImage(peer.platform, size: 16)),
                  const SizedBox(width: 6),
                  Flexible(
                      child: Text(peer.platform,
                          overflow: TextOverflow.ellipsis)),
                ]),
          // Compact rows keep only ⋮; its menu already has Connect.
          compact
              ? more
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: connect,
                    style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10)),
                    child: Text(translate('Connect'),
                        overflow: TextOverflow.ellipsis),
                  ),
                  more,
                ]),
        ),
      ),
    );
  }

  Widget _buildAccount() {
    final model = gFFI.carteiraModel;
    final account = model.account.value;
    final busy = model.syncing.value;
    final error = model.syncError.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            if (account == null)
              TextButton.icon(
                onPressed: busy ? null : _showStartXLogin,
                icon: const Icon(Icons.person_outline),
                label: const Text('Entrar com Start X'),
              )
            else ...[
              Text(account),
              TextButton(
                onPressed: busy ? null : model.refreshRemote,
                child: const Text('Atualizar carteira'),
              ),
              TextButton(
                onPressed: busy ? null : model.signOut,
                child: const Text('Sair'),
              ),
            ],
          ],
        ),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(error, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
    );
  }

  void _showStartXLogin() {
    showDialog<void>(
      context: context,
      builder: (_) => const _StartXLoginDialog(),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => _addDeviceDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text(translate('Add device')),
        ),
        TextButton.icon(
          onPressed: () {
            final n = gFFI.carteiraModel.importFromRecentAndFavorites();
            showToast('${translate('Import from recent sessions')}: $n');
          },
          icon: const Icon(Icons.download, size: 18),
          label: Text(translate('Import from recent sessions')),
        ),
      ],
    ).paddingOnly(top: 4, bottom: 16);
  }

  void _addDeviceDialog(BuildContext context) {
    final id = TextEditingController();
    final alias = TextEditingController();
    final group = TextEditingController();
    gFFI.dialogManager.show((setState, close, context) {
      submit() {
        final idText = id.text.trim();
        if (idText.isEmpty) return;
        gFFI.carteiraModel
            .addPeer(idText, alias.text.trim(), group.text.trim());
        close();
      }

      return CustomAlertDialog(
        title: Text(translate('Add device')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: id,
              decoration: const InputDecoration(labelText: 'ID'),
            ),
            TextField(
              controller: alias,
              decoration: InputDecoration(labelText: translate('Alias')),
            ),
            Autocomplete<String>(
              optionsBuilder: (value) {
                final groups = gFFI.carteiraModel.groups;
                final text = value.text.trim().toLowerCase();
                if (text.isEmpty) return groups;
                return groups
                    .where((g) => g.toLowerCase().contains(text))
                    .toList();
              },
              onSelected: (selection) => group.text = selection,
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) =>
                      TextField(
                controller: controller,
                focusNode: focusNode,
                decoration:
                    InputDecoration(labelText: translate('Group name'),
                        hintText: 'Empresa / Filial'),
                onChanged: (v) => group.text = v,
              ),
            ),
          ],
        ),
        actions: [
          dialogButton('Cancel', onPressed: close, isOutline: true),
          dialogButton('OK', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _renameGroupDialog(BuildContext context, String group) {
    renameDialog(
      oldName: group,
      onSubmit: (String newName) async {
        if (newName.isNotEmpty && newName != group) {
          gFFI.carteiraModel.renameGroup(group, newName);
          showToast(translate('Successful'));
        }
      },
    );
  }
}

/// Asks once, right after login, to send this computer's devices to the account.
void _askMergeLocal() {
  final model = gFFI.carteiraModel;
  final count = model.localOnlyCount;
  gFFI.dialogManager.show((setState, close, context) {
    submit() {
      model.mergeLocalIntoAccount();
      close();
    }

    return CustomAlertDialog(
      title: const Text('Levar esta carteira para a conta?'),
      content: Text(count == 1
          ? '1 dispositivo está salvo só neste computador. Envie para a conta e ele aparece em todos os computadores em que você entrar.'
          : '$count dispositivos estão salvos só neste computador. Envie para a conta e eles aparecem em todos os computadores em que você entrar.'),
      actions: [
        dialogButton('Agora não', onPressed: close, isOutline: true),
        dialogButton('Enviar para a conta', onPressed: submit),
      ],
      onSubmit: submit,
      onCancel: close,
    );
  });
}

class _StartXLoginDialog extends StatefulWidget {
  const _StartXLoginDialog();

  @override
  State<_StartXLoginDialog> createState() => _StartXLoginDialogState();
}

class _StartXLoginDialogState extends State<_StartXLoginDialog> {
  final _login = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_login.text.trim().isEmpty || _password.text.isEmpty) return;
    final model = gFFI.carteiraModel;
    await model.signIn(_login.text, _password.text);
    if (mounted && model.account.value != null) {
      Navigator.of(context).pop();
      if (model.localOnlyCount > 0) _askMergeLocal();
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = gFFI.carteiraModel;
    return Obx(() => AlertDialog(
          title: const Text('Entrar com Start X'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _login,
                autofocus: true,
                enabled: !model.syncing.value,
                decoration: const InputDecoration(labelText: 'E-mail ou usuário'),
              ),
              TextField(
                controller: _password,
                obscureText: true,
                enabled: !model.syncing.value,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              if (model.syncError.value case final error?) Text(error),
            ],
          ),
          actions: [
            TextButton(
              onPressed: model.syncing.value ? null : () => Navigator.of(context).pop(),
              child: Text(translate('Cancel')),
            ),
            FilledButton(
              onPressed: model.syncing.value ? null : _submit,
              child: const Text('Entrar'),
            ),
          ],
        ));
  }
}
