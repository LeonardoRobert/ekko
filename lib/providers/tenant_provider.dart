import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/env.dart';
import '../models/tenant_model.dart';
import '../services/tenant_service.dart';

final tenantServiceProvider = Provider<TenantService>((ref) => TenantService());

/// Carrega a igreja dona deste build UMA vez, na inicializacao do app
/// (antes do login -- diferente do tema antigo do awake_app, que so
/// sabia a cor certa depois de logar e ver o perfil). `main.dart`
/// espera esse provider carregar antes de montar o MaterialApp de
/// verdade.
final tenantAtualProvider = FutureProvider<TenantModel>((ref) {
  return ref.watch(tenantServiceProvider).buscarTenantAtual(Env.tenantSlug);
});
