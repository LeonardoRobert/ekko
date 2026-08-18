import 'package:flutter/material.dart';

/// Representa UMA igreja cliente da e-kko. church. Cada build do app e'
/// dedicado a um tenant so (`Env.tenantSlug`), mas todos os tenants
/// vivem no mesmo projeto Supabase -- essa linha e' o que diferencia um
/// app do outro (cores, logo, quais modulos aparecem).
class TenantModel {
  final String id;
  final String slug;
  final String nome;
  final Color corPrimaria;
  final Color corDestaque;
  final String? logoUrl;
  final List<String> modulosAtivos;
  final bool ativo;

  const TenantModel({
    required this.id,
    required this.slug,
    required this.nome,
    required this.corPrimaria,
    required this.corDestaque,
    required this.logoUrl,
    required this.modulosAtivos,
    required this.ativo,
  });

  factory TenantModel.fromMap(Map<String, dynamic> map) {
    return TenantModel(
      id: map['id'] as String,
      slug: map['slug'] as String,
      nome: map['nome'] as String,
      corPrimaria: _corDeHex(map['cor_primaria'] as String),
      corDestaque: _corDeHex(map['cor_destaque'] as String),
      logoUrl: map['logo_url'] as String?,
      modulosAtivos: (map['modulos_ativos'] as List?)?.cast<String>() ?? const [],
      ativo: map['ativo'] as bool? ?? true,
    );
  }

  /// Converte '#RRGGBB' (como fica salvo no banco) pra Color. Aceita
  /// tambem sem o '#' na frente, por seguranca.
  static Color _corDeHex(String hex) {
    final limpo = hex.replaceFirst('#', '');
    return Color(int.parse('FF$limpo', radix: 16));
  }
}
