import 'package:flutter/material.dart';

import '../../models/carteira_data.dart';

const _none = '\u0000none';
const _new = '\u0000new';

/// What [CarteiraGroupPicker] chose: a network and a branch, either existing or
/// typed as new.
class CarteiraGroupChoice {
  String network;
  String branch;
  final networkName = TextEditingController();
  final branchName = TextEditingController();

  CarteiraGroupChoice._(this.network, this.branch);

  /// Starts on [current] (`Network / Branch`, `Network` or ''), or, with no
  /// current group, on the first network and its first branch.
  factory CarteiraGroupChoice(List<String> groups, {String? current}) {
    if (current != null) {
      final parts = current.split(carteiraGroupSeparator);
      return CarteiraGroupChoice._(current.isEmpty ? _none : parts.first,
          parts.length > 1 ? parts.sublist(1).join(carteiraGroupSeparator) : _none);
    }
    final networks = carteiraNetworks(groups);
    if (networks.isEmpty) return CarteiraGroupChoice._(_none, _none);
    final branches = carteiraBranches(groups, networks.first);
    return CarteiraGroupChoice._(
        networks.first, branches.isEmpty ? _none : branches.first);
  }

  static String _clean(TextEditingController c) =>
      c.text.replaceAll('/', '-').trim();

  String get _networkPath => network == _new ? _clean(networkName) : network;

  /// False while a "new" field is still blank.
  bool get ready =>
      (network != _new || _networkPath.isNotEmpty) &&
      (network == _none || branch != _new || _clean(branchName).isNotEmpty);

  /// The group path to put the device in.
  String get path {
    if (network == _none) return '';
    final root = _networkPath;
    if (branch == _none) return root;
    return '$root$carteiraGroupSeparator${branch == _new ? _clean(branchName) : branch}';
  }

  /// The groups typed as new, saved even if the device later leaves them.
  List<String> get newGroups => [
        if (network == _new) _networkPath,
        if (network != _none && branch == _new) path,
      ];
}

List<String> carteiraNetworks(List<String> groups) =>
    groups.map((g) => g.split(carteiraGroupSeparator).first).toSet().toList()..sort();

List<String> carteiraBranches(List<String> groups, String network) => groups
    .where((g) => g.startsWith('$network$carteiraGroupSeparator'))
    .map((g) => g.substring(network.length + carteiraGroupSeparator.length))
    .toSet()
    .toList()
  ..sort();

/// Network and branch dropdowns, each with an option to type a new one.
class CarteiraGroupPicker extends StatefulWidget {
  final CarteiraGroupChoice choice;
  final List<String> groups;

  const CarteiraGroupPicker(
      {super.key, required this.choice, required this.groups});

  @override
  State<CarteiraGroupPicker> createState() => _CarteiraGroupPickerState();
}

class _CarteiraGroupPickerState extends State<CarteiraGroupPicker> {
  @override
  Widget build(BuildContext context) {
    final choice = widget.choice;
    final networks = carteiraNetworks(widget.groups);
    final branches = choice.network == _new
        ? const <String>[]
        : carteiraBranches(widget.groups, choice.network);
    DropdownMenuItem<String> item(String value, String label) =>
        DropdownMenuItem(value: value, child: Text(label, overflow: TextOverflow.ellipsis));
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('carteira-rede'),
          initialValue: choice.network,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Rede'),
          items: [
            for (final n in networks) item(n, n),
            item(_none, 'Sem rede'),
            item(_new, '+ Nova rede…'),
          ],
          onChanged: (value) => setState(() {
            choice.network = value ?? _none;
            final first = carteiraBranches(widget.groups, choice.network);
            choice.branch = first.isEmpty ? _none : first.first;
          }),
        ),
        if (choice.network == _new)
          TextField(
            controller: choice.networkName,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome da nova rede'),
          ),
        if (choice.network != _none)
          KeyedSubtree(
            key: const Key('carteira-filial'),
            child: DropdownButtonFormField<String>(
              // A new key per network resets the field to the new branch list.
              key: ValueKey('carteira-filial-${choice.network}'),
              initialValue: choice.branch,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Filial'),
              items: [
                for (final b in branches) item(b, b),
                item(_none, 'Direto na rede'),
                item(_new, '+ Nova filial…'),
              ],
              onChanged: (value) =>
                  setState(() => choice.branch = value ?? _none),
            ),
          ),
        if (choice.network != _none && choice.branch == _new)
          TextField(
            controller: choice.branchName,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome da nova filial'),
          ),
      ],
    );
  }
}
