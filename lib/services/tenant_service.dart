import '../models/tenant_model.dart';
import 'supabase_service.dart';

class TenantService {
  final _client = SupabaseService.client;

  /// Busca a igreja dona deste build, pelo slug configurado em
  /// `Env.tenantSlug`. Lanca excecao se o slug nao existir ou estiver
  /// desativado (`ativo = false`) -- ver `tenant_provider.dart` pra
  /// como isso vira uma tela de erro amigavel.
  Future<TenantModel> buscarTenantAtual(String slug) async {
    final data = await _client
        .from('tenants')
        .select()
        .eq('slug', slug)
        .eq('ativo', true)
        .single();
    return TenantModel.fromMap(data);
  }
}
