import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../common.dart';
import '../../models/model.dart';
import '../../models/platform_model.dart';

/// Start X look of a stock remote toolbar button: its icon plus a Portuguese
/// label. Keyed by the stock tooltip, so the button keeps its own action.
class SessionToolbarLabel extends StatelessWidget {
  final String svg;
  final String label;
  final bool menu;
  final bool outlined;

  const SessionToolbarLabel({
    super.key,
    required this.svg,
    required this.label,
    this.menu = false,
    this.outlined = false,
  });

  static SessionToolbarLabel? of(String tooltip, String? svg) {
    if (svg == null) return null;
    return switch (tooltip) {
      'Control Actions' =>
        SessionToolbarLabel(svg: svg, label: 'Ações', menu: true),
      'Display Settings' =>
        SessionToolbarLabel(svg: svg, label: 'Tela', menu: true),
      'Transfer file' => SessionToolbarLabel(svg: svg, label: 'Arquivos'),
      'Chat' => SessionToolbarLabel(svg: svg, label: 'Chat', menu: true),
      'Start session recording' =>
        SessionToolbarLabel(svg: svg, label: 'Gravar'),
      'Stop session recording' =>
        SessionToolbarLabel(svg: svg, label: 'Gravando'),
      'Close' =>
        SessionToolbarLabel(svg: svg, label: 'Encerrar', outlined: true),
      _ => null,
    };
  }

  /// Replaces the stock filled square; null keeps the stock fill.
  Color? fill(bool hover) => outlined
      ? (hover ? const Color(0x1FF44336) : Colors.transparent)
      : null;

  @override
  Widget build(BuildContext context) {
    final color = !outlined
        ? Colors.white
        : Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFFCA5A5)
            : const Color(0xFFB91C1C);
    return Container(
      padding: const EdgeInsets.only(right: 10),
      decoration: outlined
          ? BoxDecoration(
              border: Border.all(color: color),
              borderRadius: BorderRadius.circular(8))
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(svg,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              width: 32,
              height: 32),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w500)),
          if (menu) Icon(Icons.expand_more, size: 16, color: color),
        ],
      ),
    );
  }
}

/// Same as "Transfer file" in the control actions menu, as its own button.
void openSessionFileTransfer(BuildContext context, String id, FFI ffi) {
  connect(context, id,
      loginMethod: bind.sessionGetCommonSync(
              sessionId: ffi.sessionId, key: 'login_method', param: '') ??
          '',
      isFileTransfer: true,
      connToken: bind.sessionGetConnToken(sessionId: ffi.sessionId));
}
