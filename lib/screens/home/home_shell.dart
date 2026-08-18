import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/erro_amigavel.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../calendar/calendar_screen.dart';
import '../financeiro/financeiro_screen.dart';
import '../home/inicio_screen.dart';
import '../pages/nossos_conteudos_screen.dart';
import '../profile/profile_screen.dart';

/// Estrutura principal do app com navegacao por abas.
///
/// Motor generico (e-kko. church) -- navegacao unica de 5 abas
/// (Inicio/Calendario/Conteudos/Contribua/Perfil), sem os modulos
/// exclusivos do Awake (Escala/Metas/QR) que existiam no app original
/// da Shallom. Cores ainda fixas nesta rodada (ShallomColors) -- virar
/// config por tenant e' trabalho de uma fase futura, ver o plano em
/// C:\Users\leona\.claude\plans\vivid-snacking-mist.md.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _tourMostrado = false;

  void _mostrarTourSeNecessario() {
    if (_tourMostrado) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || profile.tourVisto) return;

    _tourMostrado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrirTour();
    });
  }

  Future<void> _abrirTour() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bem-vindo(a)!'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ItemTour(
              icon: Icons.home_outlined,
              texto: 'Início — seus próximos eventos da semana, prontos pra compartilhar.',
            ),
            _ItemTour(
              icon: Icons.calendar_month,
              texto: 'Calendário — veja os próximos eventos e a programação da semana.',
            ),
            _ItemTour(
              icon: Icons.ondemand_video_outlined,
              texto: 'Conteúdos — vídeos e materiais da igreja.',
            ),
            _ItemTour(
              icon: Icons.volunteer_activism,
              texto: 'Contribua — dízimos, ofertas e como ajudar.',
            ),
            _ItemTour(icon: Icons.person, texto: 'Perfil — seus dados e treinamentos.'),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Entendi!'),
          ),
        ],
      ),
    );

    await ref.read(authServiceProvider).marcarTourVisto();
    ref.invalidate(currentProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    // Mantem a subscription do Realtime viva durante toda a sessao --
    // ver o comentario em profileRealtimeProvider (auth_provider.dart).
    ref.watch(profileRealtimeProvider);

    return profileAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(
        body: Center(child: Text('Erro ao carregar perfil: ${mensagemDeErroAmigavel(err)}')),
      ),
      data: (profile) {
        _mostrarTourSeNecessario();

        const screens = [
          InicioScreen(),
          CalendarScreen(),
          NossosConteudosScreen(),
          FinanceiroScreen(),
          ProfileScreen(),
        ];

        const itens = [
          (Icons.home_outlined, 'Início'),
          (Icons.calendar_month, 'Calendário'),
          (Icons.ondemand_video_outlined, 'Conteúdos'),
          (Icons.attach_money, 'Contribua'),
          (Icons.person, 'Perfil'),
        ];
        final corFundo = ShallomColors.azul;
        final corSelecionada = AwakeColors.navy;
        final corNaoSelecionada = AwakeColors.offWhite;

        return Scaffold(
          body: IndexedStack(index: _currentIndex, children: screens),
          bottomNavigationBar: ColoredBox(
            color: corFundo,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: List.generate(itens.length, (index) {
                    final (icon, label) = itens[index];
                    return Expanded(
                      child: _NavItem(
                        icon: icon,
                        label: label,
                        selected: _currentIndex == index,
                        corSelecionada: corSelecionada,
                        corNaoSelecionada: corNaoSelecionada,
                        onTap: () => setState(() => _currentIndex = index),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ItemTour extends StatelessWidget {
  final IconData icon;
  final String texto;
  const _ItemTour({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color corSelecionada;
  final Color corNaoSelecionada;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.corSelecionada,
    required this.corNaoSelecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? corSelecionada : corNaoSelecionada;
    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
