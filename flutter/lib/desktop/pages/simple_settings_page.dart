import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/carteira_view.dart';
import 'package:flutter_hbb/common/widgets/dialog.dart';
import 'package:flutter_hbb/consts.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/state_model.dart';
import 'package:get/get.dart';

/// Settings of the Start X editions; [onAdvanced] opens the original page.
class SimpleSettingsView extends StatefulWidget {
  final VoidCallback onAdvanced;

  const SimpleSettingsView({Key? key, required this.onAdvanced})
      : super(key: key);

  @override
  State<SimpleSettingsView> createState() => _SimpleSettingsViewState();
}

class _SimpleSettingsViewState extends State<SimpleSettingsView> {
  static final _tabs = [
    ('Geral', Icons.tune),
    ('Segurança', Icons.shield_outlined),
    ('Rede', Icons.lan_outlined),
    // The Start X account holds the technicians' wallet only.
    if (!kStartXCustomerEdition) ('Conta', Icons.person_outline),
    ('Sobre', Icons.info_outline),
  ];
  var _tab = 'Geral';
  // As in the original Security tab: an installed app asks for admin rights
  // (or the unlock PIN) before access options change.
  var _locked = bind.mainIsInstalled();
  var _unattended = false;
  var _support = false;
  late final _langs = bind.mainGetLangs();
  late final _version = bind.mainGetVersion();

  @override
  void initState() {
    super.initState();
    _loadUnattended();
    _loadSupport();
  }

  Future<void> _loadUnattended() async {
    final set =
        await bind.mainGetCommon(key: 'permanent-password-set') == 'true';
    if (mounted) setState(() => _unattended = set);
  }

  Future<void> _loadSupport() async {
    final set = await bind.mainGetCommon(key: 'support-password-set') == 'true';
    if (mounted) setState(() => _support = set);
  }

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        width: 200,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (label, icon) in _tabs) _navItem(label, icon),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onAdvanced,
                  icon: const Icon(Icons.settings_outlined, size: 18),
                  label: const Text('Configurações avançadas'),
                ),
              ]),
        ),
      ),
      const VerticalDivider(width: 1),
      Expanded(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(padding: const EdgeInsets.all(24), children: [
              Text(_tab,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ...switch (_tab) {
                'Segurança' => _security(),
                'Rede' => _network(),
                'Conta' => _account(),
                'Sobre' => _about(),
                _ => _general(),
              },
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _navItem(String label, IconData icon) => ListTile(
        dense: true,
        selected: label == _tab,
        selectedColor: MyTheme.brandMid,
        selectedTileColor: MyTheme.brandMid.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: Icon(icon, size: 20),
        minLeadingWidth: 0,
        title: Text(label, style: const TextStyle(fontSize: 14)),
        onTap: () => setState(() => _tab = label),
      );

  Widget _card(List<Widget> children) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: RoundedRectangleBorder(
            side: BorderSide(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: children),
      );

  Widget _optionSwitch(String label, String key,
      {String? subtitle, bool local = false, bool? fake}) {
    final value = fake ??
        (local ? mainGetLocalBoolOptionSync(key) : mainGetBoolOptionSync(key));
    // Server options are the access options, behind the security lock.
    final locked = !local && _locked;
    return SwitchListTile(
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      onChanged: fake != null || locked || isOptionFixed(key)
          ? null
          : (v) async {
              await (local
                  ? mainSetLocalBoolOption(key, v)
                  : mainSetBoolOption(key, v));
              if (mounted) setState(() {});
            },
    );
  }

  Widget _unlockButton() => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _unlock,
            icon: const Icon(Icons.security_sharp, size: 18),
            label: Text(translate('Unlock Security Settings')),
          ),
        ),
      );

  Future<void> _unlock() async {
    unlock() => setState(() => _locked = false);
    final pin = bind.mainGetUnlockPin();
    if (pin.isEmpty || isUnlockPinDisabled()) {
      if (await callMainCheckSuperUserPermission() && mounted) unlock();
    } else {
      checkUnlockPinDialog(pin, unlock);
    }
  }

  List<Widget> _general() => [
        _card([
          ListTile(
            title: const Text('Tema'),
            trailing: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'light', label: Text('Claro')),
                ButtonSegment(value: 'dark', label: Text('Escuro')),
                ButtonSegment(value: 'system', label: Text('Sistema')),
              ],
              selected: {MyTheme.getThemeModePreference().toShortString()},
              showSelectedIcon: false,
              onSelectionChanged: isOptionFixed(kCommConfKeyTheme)
                  ? null
                  : (selected) async {
                      await MyTheme.changeDarkMode(
                          MyTheme.themeModeFromString(selected.first));
                      setState(() {});
                    },
            ),
          ),
          ListTile(
            title: const Text('Idioma'),
            trailing: SizedBox(width: 240, child: _language()),
          ),
          _optionSwitch('Abrir sessões em abas', kOptionOpenNewConnInTabs,
              subtitle: 'Cada computador acessado vira uma aba na mesma janela.',
              local: true),
        ]),
      ];

  Widget _language() => FutureBuilder<String>(
      future: _langs,
      builder: (context, snapshot) {
        final langs = jsonDecode(snapshot.data ?? '[]') as List<dynamic>;
        final keys = <String>[defaultOptionLang, for (final l in langs) l[0]];
        final values = <String>[
          translate('Default'),
          for (final l in langs) l[1]
        ];
        final current = bind.mainGetLocalOption(key: kCommConfKeyLang);
        return ComboBox(
          keys: keys,
          values: values,
          initialKey: keys.contains(current) ? current : defaultOptionLang,
          enabled: !isOptionFixed(kCommConfKeyLang),
          onChanged: (key) async {
            await bind.mainSetLocalOption(key: kCommConfKeyLang, value: key);
            reloadAllWindows();
            bind.mainChangeLanguage(lang: key);
          },
        );
      });

  List<Widget> _security() {
    final mode = bind.mainGetOptionSync(key: kOptionAccessMode);
    // The original page's access mode overrides each permission.
    final fake = mode == 'full' ? true : (mode == 'view' ? false : null);
    final canSetPassword = !_locked && !isChangePermanentPasswordDisabled();
    return [
      if (_locked) _unlockButton(),
      _card([
        ListTile(
          title: const Text('Acesso com aprovação'),
          subtitle: const Text(
              'Sem senha, como no AnyDesk: quem pede acesso espera você clicar em Aceitar.'),
          trailing: _pill('Sempre ligado'),
        ),
        if (_support) ..._supportUnattended(canSetPassword),
        if (!_support)
        SwitchListTile(
          title: const Text('Acesso não supervisionado'),
          subtitle: const Text(
              'Para computadores sem ninguém na frente, como servidores. Quem tiver a senha entra sem esperar aceite.'),
          value: _unattended,
          onChanged: canSetPassword ? (_) => _toggleUnattended() : null,
        ),
        if (!_support && _unattended)
          ListTile(
            title: const Text('Senha do acesso não supervisionado'),
            subtitle: const Text(
                'Só quem tiver esta senha entra sem aceite.'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _pill('Cadastrada'),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: canSetPassword
                    ? () => setPasswordDialog(notEmptyCallback: _loadUnattended)
                    : null,
                icon: const Icon(Icons.lock, size: 16),
                label: const Text('Trocar senha'),
              ),
            ]),
          ),
      ]),
      const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Text('Quem acessar este computador pode',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      _card([
        _optionSwitch('Usar teclado e mouse', kOptionEnableKeyboard, fake: fake),
        _optionSwitch('Usar a área de transferência', kOptionEnableClipboard,
            fake: fake),
        _optionSwitch('Transferir arquivos', kOptionEnableFileTransfer,
            fake: fake),
        _optionSwitch('Ouvir o áudio', kOptionEnableAudio, fake: fake),
        _optionSwitch('Reiniciar o computador', kOptionEnableRemoteRestart,
            fake: fake),
      ]),
    ];
  }

  /// Builds with the support password are unattended from install; turning it
  /// off only switches access to click-to-accept, keeping both passwords.
  List<Widget> _supportUnattended(bool canSetPassword) {
    final on = bind.mainGetOptionSync(key: kOptionApproveMode) != 'click';
    return [
      SwitchListTile(
        title: const Text('Acesso não supervisionado'),
        subtitle: const Text(
            'O técnico da Start X entra com a senha do suporte, sem esperar você aceitar.'),
        value: on,
        onChanged: canSetPassword
            ? (v) async {
                await bind.mainSetOption(
                    key: kOptionApproveMode, value: v ? '' : 'click');
                if (mounted) setState(() {});
              }
            : null,
      ),
      if (on)
        ListTile(
          title: const Text('Senha própria (opcional)'),
          subtitle:
              const Text('Uma segunda senha, que funciona junto com a do suporte.'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (_unattended) ...[_pill('Cadastrada'), const SizedBox(width: 8)],
            OutlinedButton.icon(
              onPressed: canSetPassword
                  ? () => setPasswordDialog(notEmptyCallback: _loadUnattended)
                  : null,
              icon: const Icon(Icons.lock, size: 16),
              label: Text(_unattended ? 'Trocar senha' : 'Criar senha'),
            ),
            if (_unattended)
              TextButton(
                onPressed: canSetPassword ? _removeOwnPassword : null,
                child: const Text('Remover'),
              ),
          ]),
        ),
    ];
  }

  void _removeOwnPassword() {
    gFFI.dialogManager.show((setState, close, context) {
      submit() async {
        final ok = await bind.mainSetPermanentPasswordWithResult(password: '');
        close();
        if (!ok) showToast(translate('Failed'));
        _loadUnattended();
      }

      return CustomAlertDialog(
        title: const Text('Remover a senha própria?'),
        content: const Text('A senha do suporte continua funcionando.'),
        actions: [
          dialogButton('Cancelar', onPressed: close, isOutline: true),
          dialogButton('Remover', onPressed: submit),
        ],
        onSubmit: submit,
        onCancel: close,
      );
    });
  }

  /// Unattended access is the permanent password: set it, or clear it.
  void _toggleUnattended() {
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

  List<Widget> _network() => [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Os servidores desta edição vêm configurados pela Start X.'),
        ),
        _card([
          _server('Servidor de ID', 'custom-rendezvous-server'),
          _server('Servidor relay', 'relay-server'),
          const ListTile(
            dense: true,
            leading: Icon(Icons.lock, size: 16),
            minLeadingWidth: 0,
            title: Text('Só a Start X muda estes campos.'),
          ),
        ]),
        if (_locked) _unlockButton(),
        _card([
          _optionSwitch('Aceitar conexão direta por IP', kOptionDirectServer,
              subtitle: 'Mais rápido na mesma rede; deixe desligado se não souber.'),
        ]),
      ];

  Widget _server(String label, String key) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: TextFormField(
          initialValue: bind.mainGetOptionSync(key: key),
          readOnly: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.lock, size: 18),
            border: const OutlineInputBorder(),
          ),
        ),
      );

  List<Widget> _account() {
    final model = gFFI.carteiraModel;
    return [
      Obx(() {
        final account = model.account.value;
        final busy = model.syncing.value;
        final error = model.syncError.value;
        return _card([
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (account == null) ...[
                    const Text(
                        'Entre na sua conta para guardar a carteira na nuvem e usar os mesmos grupos em todos os computadores.'),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed:
                          busy ? null : () => showStartXLoginDialog(context),
                      icon: const Icon(Icons.login, size: 18),
                      label: const Text('Entrar na conta'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                        'Não tem conta? Crie a sua na janela de entrar, em "Criar conta".',
                        style: TextStyle(fontSize: 13)),
                  ] else ...[
                    Text(account,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                        'A carteira desta conta aparece igual em todo computador em que você entrar.'),
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : model.refreshRemote,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Sincronizar agora'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : model.signOut,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Sair'),
                      ),
                    ]),
                  ],
                  if (busy) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(error,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                ]),
          ),
        ]);
      }),
    ];
  }

  List<Widget> _about() => [
        _card([
          ListTile(
            title: const Text('Versão'),
            subtitle: FutureBuilder<String>(
              future: _version,
              builder: (context, snapshot) => Text(
                  'RustDesk ${snapshot.data ?? ''} · edição ${kStartXCustomerEdition ? 'cliente' : 'técnico'}'),
            ),
          ),
          Obx(() {
            final status = stateGlobal.svcStatus.value;
            return ListTile(
              title: const Text('Servidor'),
              subtitle: Text(translate(switch (status) {
                SvcStatus.ready => 'Ready',
                SvcStatus.connecting => 'connecting_status',
                SvcStatus.notReady => 'not_ready_status',
              })),
              trailing:
                  status == SvcStatus.ready ? _pill('Online') : null,
            );
          }),
        ]),
      ];
}

Widget _pill(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: TextStyle(
              color: Colors.green.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    );
