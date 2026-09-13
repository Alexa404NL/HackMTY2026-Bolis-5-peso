import 'package:flutter/material.dart';

import '../theme.dart';

/// Modal de selección de módulo para agregar al Dashboard.
///
/// Se presenta como un bottom sheet con las 3 opciones de módulo.
/// Al seleccionar uno, cierra el modal y regresa la selección al caller.
class AddWidgetModal extends StatelessWidget {
  const AddWidgetModal({super.key});

  static Future<ModuleChoice?> show(BuildContext context) {
    return showModalBottomSheet<ModuleChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWidgetModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        color: BanorteColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pill handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: BanorteColors.content5,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('¿Qué quieres agregar?', style: t.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Elige un módulo. Te guiaremos paso a paso para configurar tu widget.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 24),
          _ModuleOptionCard(
            icon: Icons.savings_rounded,
            title: 'Meta de Ahorro',
            subtitle: 'Simula y monitorea tu objetivo de ahorro',
            accentColor: BanorteColors.red,
            onTap: () => Navigator.pop(context, ModuleChoice.savingsGoal),
          ),
          const SizedBox(height: 12),
          _ModuleOptionCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Presupuesto Mensual',
            subtitle: 'Visualiza y controla tus ingresos y gastos',
            accentColor: BanorteColors.warning,
            onTap: () => Navigator.pop(context, ModuleChoice.budget),
          ),
          const SizedBox(height: 12),
          _ModuleOptionCard(
            icon: Icons.trending_up_rounded,
            title: 'Portafolio de Inversión',
            subtitle: 'Proyecta el crecimiento de tu dinero',
            accentColor: const Color(0xFF4CAF50),
            onTap: () => Navigator.pop(context, ModuleChoice.investment),
          ),
        ],
      ),
    );
  }
}

enum ModuleChoice { savingsGoal, budget, investment }

class _ModuleOptionCard extends StatelessWidget {
  const _ModuleOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Material(
      color: BanorteColors.background2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: BanorteColors.content3),
            ],
          ),
        ),
      ),
    );
  }
}

// Exportamos la elección como tipo público para que DashboardScreen la use
extension ModuleChoiceExt on ModuleChoice {
  String get name => switch (this) {
        ModuleChoice.savingsGoal => 'savingsGoal',
        ModuleChoice.budget => 'budget',
        ModuleChoice.investment => 'investment',
      };
}

/// Tipo público para que el dashboard acceda a la elección sin conocer el enum interno.
