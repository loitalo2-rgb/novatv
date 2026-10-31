import 'package:flutter/material.dart';

/// Layout mestre/detalhe usado pela tela "Ao Vivo".
///
/// Em telas largas (desktop/TV) a lista fica à esquerda e o player à direita.
/// Em telas estreitas o player fica no topo e a lista abaixo dele.
class MasterDetailLayout extends StatelessWidget {
  const MasterDetailLayout({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 340,
    this.breakpoint = 900,
  });

  /// Painel de lista (esquerda).
  final Widget master;

  /// Painel de vídeo/detalhe (direita).
  final Widget detail;

  final double masterWidth;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= breakpoint;
        if (wide) {
          return Row(
            children: [
              SizedBox(width: masterWidth, child: master),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.06),
              ),
              Expanded(child: detail),
            ],
          );
        }

        return Column(
          children: [
            SizedBox(
              height: constraints.maxHeight >= 640
                  ? 380
                  : (constraints.maxHeight * 0.45).clamp(220.0, 380.0),
              child: detail,
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            Expanded(child: master),
          ],
        );
      },
    );
  }
}
