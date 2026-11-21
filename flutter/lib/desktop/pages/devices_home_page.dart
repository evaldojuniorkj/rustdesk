import 'package:flutter/material.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/widgets/carteira_view.dart';
import 'package:flutter_hbb/common/widgets/peers_view.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_tab_page.dart';
import 'package:flutter_hbb/desktop/pages/support_page.dart';

/// Technician home in the TeamViewer layout: a side menu that switches
/// between the device tree and the support view.
class DevicesHomePage extends StatefulWidget {
  const DevicesHomePage({Key? key}) : super(key: key);

  @override
  State<DevicesHomePage> createState() => _DevicesHomePageState();
}

class _DevicesHomePageState extends State<DevicesHomePage> {
  var _showDevices = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sideMenu(),
        Expanded(
          // The original home stays mounted and goes first: its initState
          // registers services (e.g. 'stop-service') the status bar reads.
          child: IndexedStack(
            index: _showDevices ? 1 : 2,
            children: [
              const DesktopHomePage(),
              _devices(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(child: SupportView()),
                  const Divider(height: 1),
                  const OnlineStatusWidget(),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideMenu() {
    Widget item(
        IconData icon, String label, bool selected, VoidCallback onTap) {
      final color = selected ? Colors.white : MyTheme.brandLight;
      return Material(
        color: selected ? MyTheme.brandMid : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500)),
              ),
            ]),
          ),
        ),
      );
    }

    return Container(
      width: 220,
      color: MyTheme.brandDark,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(8),
            child: Row(children: [
              Icon(Icons.desktop_windows, color: Colors.white),
              SizedBox(width: 10),
              Text('RustDesk',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ]),
          ),
          const Divider(color: Colors.white24),
          item(Icons.devices_outlined, 'Dispositivos', _showDevices,
              () => setState(() => _showDevices = true)),
          const SizedBox(height: 4),
          item(Icons.swap_horiz, 'Suporte remoto', !_showDevices,
              () => setState(() => _showDevices = false)),
          const Spacer(),
          item(Icons.tune, translate('Settings'), false,
              () => DesktopTabPage.onAddSetting()),
        ],
      ),
    );
  }

  Widget _devices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _topBar(),
        Expanded(child: CarteiraPeersView(showRecentAndFavorites: true)),
        const Divider(height: 1),
        const OnlineStatusWidget(),
      ],
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
        const Text('Dispositivos',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 24),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: TextField(
                controller: peerSearchTextController,
                onChanged: (value) => peerSearchText.value = value,
                onSubmitted: (_) => _connect(),
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.search, size: 18),
                  hintText:
                      'Digite um ID para conectar ou um nome para buscar',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _connect, child: Text(translate('Connect'))),
      ]),
    );
  }

  void _connect() {
    final id = peerSearchTextController.text.replaceAll(' ', '');
    if (id.isNotEmpty) connect(context, id);
  }
}
