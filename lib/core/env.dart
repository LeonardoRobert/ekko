/// Configuracoes de ambiente do app.
///
/// Preencha estes valores com os dados do seu projeto Supabase
/// (Settings > API) e do seu app OneSignal (Settings > Keys & IDs).
///
/// Voce pode tanto substituir os defaultValue abaixo diretamente,
/// quanto rodar o app passando --dart-define, exemplo:
///
/// flutter run \
///   --dart-define=SUPABASE_URL=https://seuprojeto.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=sua-anon-key \
///   --dart-define=ONESIGNAL_APP_ID=seu-onesignal-app-id
class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yeimskdsftqkbvpafaxe.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InllaW1za2RzZnRxa2J2cGFmYXhlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcxNTc0OTAsImV4cCI6MjEwMjczMzQ5MH0.BN2-bWwR6AXswVZkln9Sa0vKmm1FVftwPiECCN79krc',
  );

  static const oneSignalAppId = String.fromEnvironment(
    'ONESIGNAL_APP_ID',
    defaultValue: 'SEU_ONESIGNAL_APP_ID', // TODO: preencher
  );

  /// Slug da igreja dona DESSE build especifico (ex: 'shallom').
  /// Cada igreja cliente ganha o proprio build/app dedicado (App
  /// Store/Play Store exigem isso -- ver guideline 4.2.6 da Apple),
  /// mas todos compartilham o mesmo codigo-fonte e o mesmo projeto
  /// Supabase: e' esse slug que diz pro app QUAL linha da tabela
  /// `tenants` carregar (cores, logo, modulos ativos) na inicializacao.
  static const tenantSlug = String.fromEnvironment(
    'TENANT_SLUG',
    defaultValue: 'demo', // TODO: preencher por build
  );
}
