import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/models/carteira_data.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/peer_tab_model.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../common.dart';
import '../../models/platform_model.dart';
import 'dialog.dart';
import 'peer_card.dart';
import 'peers_view.dart';

/// "Carteira" tab: wallet peers grouped by group name in collapsible
/// sections. Local-only data, see CarteiraModel.
class CarteiraPeersView extends BasePeersView {
  CarteiraPeersView({Key? key, EdgeInsets? menuPadding})
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
    return _CarteiraBody(peerCardBuilder: peerCardBuilder);
  }
}

class _CarteiraBody extends StatefulWidget {
  final PeerCardBuilder peerCardBuilder;

  const _CarteiraBody({Key? key, required this.peerCardBuilder})
      : super(key: key);

  @override
  State<_CarteiraBody> createState() => _CarteiraBodyState();
}

class _CarteiraBodyState extends State<_CarteiraBody> {
  static const _queryInterval = Duration(seconds: 20);
  Timer? _onlineTimer;
  final _collapsed = <String, bool>{};

  @override
  void initState() {
    super.initState();
    final model = gFFI.carteiraModel;
    model.ensureLoaded();
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
    final ids =
        gFFI.carteiraModel.peers.map((p) => p.id).toList(growable: false);
    if (ids.isNotEmpty) {
      bind.queryOnlines(ids: ids);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = gFFI.carteiraModel;
    return ChangeNotifierProvider<Peers>.value(
      value: model.peersModel,
      child: Consumer<Peers>(builder: (context, peersModel, child) {
        final viewPeers = {for (final p in peersModel.peers) p.id: p};
        return Obx(() {
          final search = peerSearchText.value.trim().toLowerCase();
          bool hit(CarteiraPeer p) =>
              search.isEmpty ||
              p.id.toLowerCase().contains(search) ||
              p.alias.toLowerCase().contains(search);
          final children = <Widget>[];
          for (final group in [...model.groups, '']) {
            final ps = model.peers
                .where((p) => p.groupName == group && hit(p))
                .toList();
            if (ps.isEmpty) continue;
            children.add(_buildSection(context, group, ps, viewPeers));
          }
          if (children.isEmpty) {
            if (model.peers.isEmpty) {
              return _buildEmpty(context);
            }
            return Center(
              child: Text(translate('Empty'),
                  style: TextStyle(
                      color: Theme.of(context).tabBarTheme.labelColor)),
            );
          }
          children.add(_buildActions(context));
          return ListView(padding: const EdgeInsets.all(12), children: children);
        });
      }),
    );
  }

  Widget _buildSection(BuildContext context, String group,
      List<CarteiraPeer> peers, Map<String, Peer> viewPeers) {
    final isCollapsed = _collapsed[group] ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _collapsed[group] = !isCollapsed),
          child: Row(
            children: [
              Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 20, color: MyTheme.darkGray),
              Flexible(
                child: Text(
                  group.isEmpty ? translate('Ungrouped') : group,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MyTheme.brandDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(' (${peers.length})',
                  style: const TextStyle(color: MyTheme.darkGray)),
              if (group.isNotEmpty)
                InkWell(
                  onTap: () => _renameGroupDialog(context, group),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Icon(Icons.edit, size: 16, color: MyTheme.darkGray),
                  ),
                ),
            ],
          ),
        ).paddingOnly(bottom: 8, top: 4),
        if (!isCollapsed)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: peers.map((p) {
              final view =
                  viewPeers[p.id] ?? gFFI.carteiraModel.toViewPeer(p);
              return SizedBox(
                width: 220,
                height: 140,
                child: widget.peerCardBuilder(view),
              );
            }).toList(),
          ),
        if (!isCollapsed) const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: () => _addDeviceDialog(context),
          icon: const Icon(Icons.add, size: 18),
          label: Text(translate('Add device')),
        ),
        const SizedBox(width: 8),
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

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline,
            color: Theme.of(context).tabBarTheme.labelColor,
            size: 40,
          ).paddingOnly(bottom: 10),
          _buildActions(context),
        ],
      ),
    );
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
                    InputDecoration(labelText: translate('Group name')),
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
