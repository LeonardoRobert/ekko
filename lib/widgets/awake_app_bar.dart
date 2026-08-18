import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tenant_provider.dart';

/// AppBar padrao do app -- fundo e logo vem do tenant atual (ver
/// tenant_provider.dart), nao mais fixos Awake/Shallom. O antigo botao
/// de QR Code/Check-in saiu junto com o sistema Escala Awake (ver o
/// plano do scaffold).
class AwakeAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const AwakeAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Essa AppBar so eh usada dentro de telas ja logadas, alcancadas
    // depois do tenant carregar (ver main.dart) -- o .value aqui e
    // seguro.
    final tenant = ref.watch(tenantAtualProvider).value;

    return AppBar(
      backgroundColor: tenant?.corPrimaria,
      leading: leading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tenant?.logoUrl != null) ...[
            Image.network(tenant!.logoUrl!, height: 28),
            const SizedBox(width: 10),
          ],
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
