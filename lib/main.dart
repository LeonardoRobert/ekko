import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/env.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'models/tenant_model.dart';
import 'providers/tenant_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.initialize();
  await NotificationService.initialize();
  await initializeDateFormatting('pt_BR', null);

  runApp(const ProviderScope(child: EkkoApp()));
}

class EkkoApp extends ConsumerStatefulWidget {
  const EkkoApp({super.key});

  @override
  ConsumerState<EkkoApp> createState() => _EkkoAppState();
}

class _EkkoAppState extends ConsumerState<EkkoApp> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Quando a pessoa clica no link de recuperacao de senha do e-mail,
    // o Supabase dispara esse evento -- a gente aproveita pra levar
    // direto pra tela de definir a nova senha.
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        ref.read(routerProvider).go('/redefinir-senha');
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantAtualProvider);

    // O tenant (igreja dona deste build) precisa carregar ANTES de
    // montar o app de verdade -- e' dele que vem cor primaria/destaque,
    // diferente do awake_app original, que so sabia a cor certa depois
    // do login (via perfil). Enquanto carrega/da erro, mostra uma casca
    // minima em vez do app -- sem tema de tenant nao da pra montar o
    // ThemeData certo.
    return tenantAsync.when(
      loading: () => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (err, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Não foi possível carregar a configuração desta igreja '
                '(slug "${Env.tenantSlug}"). Confirme se o tenant existe '
                'e está ativo na tabela `tenants`.\n\nErro: $err',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
      data: (tenant) => _EkkoAppComTenant(tenant: tenant),
    );
  }
}

class _EkkoAppComTenant extends ConsumerWidget {
  final TenantModel tenant;
  const _EkkoAppComTenant({required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final preferenciaTema = ref.watch(themeModeProvider);

    // 3 opcoes (Claro/Escuro/Mais escuro), controladas manualmente pela
    // pessoa (ver Perfil) -- nao segue o tema do sistema. Como o
    // ThemeMode nativo do Flutter so tem claro/escuro/sistema, resolve
    // o ThemeData na mao aqui e forca o MaterialApp a sempre usar
    // "theme" (nunca "darkTheme" por conta propria).
    final temaResolvido = switch (preferenciaTema) {
      PreferenciaTema.claro =>
        AppTheme.light(corPrimaria: tenant.corPrimaria, corDestaque: tenant.corDestaque),
      PreferenciaTema.escuro =>
        AppTheme.dark(corPrimaria: tenant.corPrimaria, corDestaque: tenant.corDestaque),
      PreferenciaTema.maisEscuro =>
        AppTheme.amoled(corPrimaria: tenant.corPrimaria, corDestaque: tenant.corDestaque),
    };

    return MaterialApp.router(
      title: tenant.nome,
      debugShowCheckedModeBanner: false,
      theme: temaResolvido,
      darkTheme: temaResolvido,
      themeMode: ThemeMode.light,
      // Sem isso, os componentes prontos do proprio Flutter (calendario
      // do seletor de data, seletor de hora, etc) aparecem em ingles
      // por padrao, mesmo com o resto do app em portugues.
      locale: const Locale('pt', 'BR'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      routerConfig: router,
    );
  }
}
