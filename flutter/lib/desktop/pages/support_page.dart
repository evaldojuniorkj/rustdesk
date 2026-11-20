import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/desktop_setting_page.dart';
import 'package:flutter_hbb/models/peer_model.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Technician "Suporte remoto": this computer's ID, connecting out and the
/// macOS permissions. No password is shown; access is accepted by click.
class SupportView extends StatefulWidget {
  /// Switches the section to the original RustDesk home.
  final VoidCallback onClassic;

  const SupportView({Key? key, required this.onClassic}) : super(key: key);

  @override
  State<SupportView> createState() => _SupportViewState();
}

class _SupportViewState extends State<SupportView> {
  final _remoteId = TextEditingController();
  // Like the original home: masks this screen from a remote controller's mouse.
  final _block = false.obs;
  var _unattended = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    bind.mainLoadRecentPeers();
    // Also picks up a password set in Settings and permissions granted in
    // System Settings, which notify nothing.
    _timer = periodic_immediate(const Duration(seconds: 1), _refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remoteId.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final set =
        await bind.mainGetCommon(key: 'permanent-password-set') == 'true';
    if (mounted) setState(() => _unattended = set);
  }

  void _connect({bool files = false}) {
    final id = _remoteId.text.replaceAll(' ', '');
    if (id.isNotEmpty) connect(context, id, isFileTransfer: files);
  }

  void _copyId() {
    Clipboard.setData(ClipboardData(text: gFFI.serverModel.serverId.text));
    showToast(translate('Copied'));
  }

  @override
  Widget build(BuildContext context) {
    return buildRemoteBlock(
      block: _block,
      mask: true,
      use: canBeBlocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Wrap(spacing: 20, runSpacing: 20, children: [
                _allowCard(),
                _controlCard(),
                if (isMacOS) _permissionsCard(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(children: [
        const Text('Suporte remoto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Spacer(),
        TextButton.icon(
          onPressed: widget.onClassic,
          icon: const Icon(Icons.history, size: 16),
          label: const Text('Tela clássica'),
        ),
      ]),
    );
  }

  Color get _muted =>
      (Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)
          .withOpacity(0.65);

  Widget _card(String title, List<Widget> children, {bool accent = true}) {
    return SizedBox(
      width: 380,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Theme.of(context).dividerColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (accent) Container(height: 3, color: MyTheme.brandMid),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                for (final child in children) ...[
                  const SizedBox(height: 14),
                  child,
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: _muted));

  Widget _row(IconData icon, String title, String subtitle, [Widget? trailing]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icon, size: 20, color: MyTheme.brandMid),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(fontSize: 13, color: _muted)),
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }

  Widget _allowCard() {
    return _card('Permitir controle remoto', [
      Text(
          'Passe o ID para quem vai acessar este computador. Não tem senha: cada acesso aparece aqui para você aceitar.',
          style: TextStyle(color: _muted)),
      _label('Seu ID'),
      Row(children: [
        Expanded(
          child: ValueListenableBuilder<TextEditingValue>(
            valueListenable: gFFI.serverModel.serverId,
            builder: (context, value, _) => Text(value.text,
                style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: MyTheme.brandMid)),
          ),
        ),
        IconButton(
          tooltip: 'Copiar ID',
          icon: const Icon(Icons.copy, size: 18),
          onPressed: _copyId,
        ),
      ]),
      _unattended
          ? _row(Icons.shield_outlined, 'Acesso não supervisionado ligado',
              'Quem tiver a senha cadastrada entra sem você aceitar.')
          : _row(Icons.shield_outlined, 'Acesso só com a sua aprovação',
              'Ninguém entra sem você clicar em Aceitar.'),
      TextButton(
        onPressed: () => DesktopSettingPage.switch2page(SettingsTabKey.safety),
        child: const Text('Mudar como o acesso é liberado'),
      ),
    ]);
  }

  Widget _controlCard() {
    return _card('Controlar dispositivo remoto', [
      TextField(
        controller: _remoteId,
        onSubmitted: (_) => _connect(),
        decoration: InputDecoration(
          isDense: true,
          labelText: 'ID do dispositivo',
          hintText: 'Ex.: 318 204 557',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ElevatedButton(onPressed: _connect, child: Text(translate('Connect'))),
        OutlinedButton.icon(
          onPressed: () => _connect(files: true),
          icon: const Icon(Icons.swap_vert, size: 16),
          label: Text(translate('Transfer file')),
        ),
      ]),
      _label('Conexões recentes'),
      ListenableBuilder(
        listenable: gFFI.recentPeersModel,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final peer in gFFI.recentPeersModel.peers.take(4))
              _recent(peer),
          ],
        ),
      ),
    ]);
  }

  Widget _recent(Peer peer) {
    final name = peer.alias.isNotEmpty ? peer.alias : peer.hostname;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => connect(context, peer.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Icon(Icons.desktop_windows_outlined,
              size: 18, color: peer.online ? MyTheme.brandMid : _muted),
          const SizedBox(width: 10),
          if (name.isNotEmpty) ...[
            Flexible(
              child: Text(name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
          ],
          Text(formatID(peer.id), style: TextStyle(color: _muted)),
        ]),
      ),
    );
  }

  Widget _permissionsCard() {
    Widget status(bool granted, VoidCallback configure) => granted
        ? const Chip(label: Text('Concedida'), visualDensity: VisualDensity.compact)
        : ElevatedButton(onPressed: configure, child: const Text('Configurar'));

    return _card('Permissões deste computador', accent: false, [
      Text('O macOS pede estas permissões para que alguém controle este computador.',
          style: TextStyle(color: _muted)),
      _row(
          Icons.screenshot_monitor,
          'Gravar a tela',
          'Mostra a tela para quem acessa.',
          status(bind.mainIsCanScreenRecording(prompt: false), () {
            bind.mainIsCanScreenRecording(prompt: true);
            // macOS shows this prompt only once per app; open the pane too.
            launchUrl(Uri.parse(
                'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'));
          })),
      _row(
          Icons.keyboard_outlined,
          'Acessibilidade',
          'Deixa quem acessa usar teclado e mouse.',
          status(bind.mainIsProcessTrusted(prompt: false),
              () => bind.mainIsProcessTrusted(prompt: true))),
      _row(
          Icons.mouse_outlined,
          'Monitorar entrada',
          'Envia atalhos do teclado quando você controla outro computador.',
          status(bind.mainIsCanInputMonitoring(prompt: false),
              () => bind.mainIsCanInputMonitoring(prompt: true))),
    ]);
  }
}
