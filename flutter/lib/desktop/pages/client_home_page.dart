import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/utils/multi_window_manager.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer home in the AnyDesk layout.
class ClientHomePage extends StatelessWidget {
  const ClientHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The original home stays mounted and goes first: its initState starts
    // services the app needs, including the one the status bar reads.
    return IndexedStack(
      index: 1,
      children: [
        const DesktopHomePage(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Expanded(child: ClientHomeView()),
            Divider(height: 1),
            OnlineStatusWidget(),
          ],
        ),
      ],
    );
  }
}

class ClientHomeView extends StatefulWidget {
  const ClientHomeView({Key? key}) : super(key: key);

  @override
  State<ClientHomeView> createState() => _ClientHomeViewState();
}

class _ClientHomeViewState extends State<ClientHomeView> {
  static const _tabs = ['Início', 'Sessões recentes', 'Favoritos'];
  final _remoteId = TextEditingController();
  // Like the original home: masks this screen from a remote controller's
  // mouse, so an accepted session cannot set an unattended password.
  final _block = false.obs;
  var _tab = 0;
  var _unattended = false;

  @override
  void initState() {
    super.initState();
    _loadUnattended();
  }

  @override
  void dispose() {
    _remoteId.dispose();
    super.dispose();
  }

  Future<void> _loadUnattended() async {
    final set =
        await bind.mainGetCommon(key: 'permanent-password-set') == 'true';
    if (mounted) setState(() => _unattended = set);
  }

  void _connect({bool files = false}) {
    final id = _remoteId.text.replaceAll(' ', '');
    if (id.isNotEmpty) connect(context, id, isFileTransfer: files);
  }

  void _selectTab(int tab) => setState(() => _tab = tab);

  void _invite() {
    final id = gFFI.serverModel.serverId.text;
    Clipboard.setData(ClipboardData(
        text: 'Para me dar suporte pelo RustDesk, use o endereço $id.'));
    showToast('Convite copiado. Cole no WhatsApp ou no e-mail do técnico.');
  }

  /// Unattended access is the permanent password: set it, or clear it.
  void _configureUnattended() {
    if (!_unattended) {
      setPasswordDialog(notEmptyCallback: _loadUnattended);
      return;
    }
    gFFI.dialogManager.show((setState, close, context) {
      submit() async {
        final ok = await bind.mainSetPermanentPasswordWithResult(password: '');
        close();
        if (!ok) showToast(translate('Failed'));
        _loadUnattended();
      }

      return CustomAlertDialog(
        title: const Text('Desligar o acesso não supervisionado?'),
        content: const Text(
            'A senha é apagada e cada acesso volta a esperar você clicar em Aceitar.'),
        actions: [
          dialogButton('Cancelar', onPressed: close, isOutline: true),
          dialogButton('Desligar', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  void _askMacPermissions() {
    if (!bind.mainIsCanScreenRecording(prompt: false)) {
      bind.mainIsCanScreenRecording(prompt: true);
      // macOS shows this prompt only once per app; open the settings pane too.
      launchUrl(Uri.parse(
          'x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture'));
    } else if (!bind.mainIsProcessTrusted(prompt: false)) {
      bind.mainIsProcessTrusted(prompt: true);
    } else if (!bind.mainIsCanInputMonitoring(prompt: false)) {
      bind.mainIsCanInputMonitoring(prompt: true);
    } else {
      showToast('As permissões já estão liberadas.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = (theme.textTheme.bodyMedium?.color ?? Colors.grey)
        .withOpacity(0.65);
    return buildRemoteBlock(
        block: _block,
        mask: true,
        use: canBeBlocked,
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _addressBar(theme),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
            children: [
              _myAddress(muted),
              const SizedBox(height: 20),
              Wrap(spacing: 28, children: [
                for (final (i, label) in _tabs.indexed)
                  InkWell(
                    onTap: () => _selectTab(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(label,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: i == _tab
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: i == _tab ? MyTheme.brandMid : muted)),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(_tabs[_tab], style: TextStyle(fontSize: 13, color: muted)),
              Divider(height: 12, thickness: 1, color: muted),
              const SizedBox(height: 8),
              if (_tab == 0)
                _tiles()
              else
                SizedBox(
                  height: 420,
                  child: _tab == 1 ? RecentPeersView() : FavoritePeersView(),
                ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _addressBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.dividerColor))),
      child: Row(children: [
        const Icon(Icons.desktop_windows_outlined, color: MyTheme.brandMid),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: _remoteId,
            onSubmitted: (_) => _connect(),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Digite o endereço remoto',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: translate('Transfer file'),
                  icon: const Icon(Icons.swap_vert, size: 18),
                  onPressed: () => _connect(files: true),
                ),
                IconButton(
                  tooltip: translate('Connect'),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  onPressed: _connect,
                ),
              ]),
            ),
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: translate('Settings'),
          icon: const Icon(Icons.menu),
          onPressed: () => DesktopTabPage.onAddSetting(),
        ),
      ]),
    );
  }

  Widget _myAddress(Color muted) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        const Text('Seu endereço', style: TextStyle(fontSize: 18)),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: gFFI.serverModel.serverId,
          builder: (context, value, _) => Text(value.text,
              style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: MyTheme.brandMid)),
        ),
        Tooltip(
          message:
              'Este é o endereço deste computador no RustDesk. Passe ele para o técnico.',
          child: Icon(Icons.info_outline, size: 20, color: muted),
        ),
        IconButton(
          tooltip: 'Acesso não supervisionado',
          icon: Icon(_unattended ? Icons.lock : Icons.lock_open, size: 20),
          onPressed: _configureUnattended,
        ),
        OutlinedButton.icon(
          onPressed: _invite,
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Convidar'),
        ),
      ],
    );
  }

  Widget _tiles() {
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _tile(MyTheme.brandDark, Colors.white, 'Precisa de ajuda?',
          'Passe seu endereço ao técnico da Start X e clique em Aceitar quando o pedido aparecer. Não precisa de senha.'),
      if (isWindows && !bind.isDisableInstallation() && !bind.mainIsInstalled())
        _tile(MyTheme.brandWarn, Colors.black87, 'Instalar o RustDesk', null,
            action: 'Instalar neste computador…', onTap: () async {
          // Installing restarts the app; close session windows first.
          await rustDeskWinManager.closeAllSubWindows();
          bind.mainGotoInstall();
        }),
      _tile(
          MyTheme.brandMid,
          Colors.white,
          'Acesso não supervisionado',
          _unattended
              ? 'Ligado. Quem tiver a senha entra sem você aceitar.'
              : 'Para computadores sem ninguém na frente, como servidores.',
          action: _unattended ? 'Desligar…' : 'Configurar senha…',
          onTap: _configureUnattended),
      if (isMacOS)
        _tile(Colors.grey.shade300, Colors.black87, 'Permissões do macOS',
            'Libere Gravar a tela e Acessibilidade para o técnico ver e controlar este computador.',
            action: 'Configurar…', onTap: _askMacPermissions),
    ]);
  }

  Widget _tile(Color background, Color foreground, String title, String? text,
      {String? action, VoidCallback? onTap}) {
    return Container(
      width: 230,
      height: 170,
      padding: const EdgeInsets.all(16),
      color: background,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                color: foreground, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: text == null
              ? const SizedBox()
              : Text(text,
                  overflow: TextOverflow.fade,
                  style:
                      TextStyle(color: foreground, fontSize: 13, height: 1.35)),
        ),
        if (action != null)
          InkWell(
            onTap: onTap,
            child: Text(action,
                style: TextStyle(
                    color: foreground,
                    decoration: TextDecoration.underline,
                    decorationColor: foreground)),
          ),
      ]),
    );
  }
}
