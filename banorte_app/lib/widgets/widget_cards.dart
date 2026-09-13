import 'package:flutter/material.dart';

import '../models/dashboard_model.dart';
import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoalWidgetCard
// ─────────────────────────────────────────────────────────────────────────────

/// Widget card para metas de ahorro en el Dashboard.
class GoalWidgetCard extends StatelessWidget {
  const GoalWidgetCard({
    super.key,
    required this.widget,
    this.onTap,
    this.onRemove,
  });

  final WidgetInstance widget;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _DashboardCard(
      onTap: onTap,
      onRemove: onRemove,
      accentColor: BanorteColors.red,
      icon: Icons.savings_rounded,
      header: Row(
        children: [
          _ModuleBadge(label: 'Meta de ahorro', color: BanorteColors.red.withValues(alpha: 0.12), textColor: BanorteColors.red),
          const Spacer(),
          _DragHandle(),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(widget.summary.primaryMetric, style: t.displaySmall?.copyWith(fontSize: 28, color: BanorteColors.red)),
          const SizedBox(height: 4),
          Text(widget.summary.secondaryMetric, style: t.bodySmall),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: _parseProgress(widget.summary.primaryMetric),
              minHeight: 6,
              color: BanorteColors.red,
              backgroundColor: BanorteColors.background2,
            ),
          ),
        ],
      ),
    );
  }

  double _parseProgress(String metric) {
    // intenta parsear un porcentaje del primary_metric tipo "45% completado"
    final match = RegExp(r'(\d+(?:\.\d+)?)%').firstMatch(metric);
    if (match == null) return 0.5;
    return (double.tryParse(match.group(1) ?? '50') ?? 50) / 100;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BudgetWidgetCard
// ─────────────────────────────────────────────────────────────────────────────

/// Widget card para presupuesto mensual en el Dashboard.
class BudgetWidgetCard extends StatelessWidget {
  const BudgetWidgetCard({
    super.key,
    required this.widget,
    this.onTap,
    this.onRemove,
  });

  final WidgetInstance widget;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final statusColor = _resolveColor(widget.summary.statusColor);
    return _DashboardCard(
      onTap: onTap,
      onRemove: onRemove,
      accentColor: statusColor,
      icon: Icons.account_balance_wallet_rounded,
      header: Row(
        children: [
          _ModuleBadge(
            label: 'Presupuesto',
            color: statusColor.withValues(alpha: 0.12),
            textColor: statusColor,
          ),
          const Spacer(),
          _StatusDot(color: statusColor),
          const SizedBox(width: 8),
          _DragHandle(),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(widget.summary.primaryMetric,
              style: t.displaySmall?.copyWith(fontSize: 26, color: statusColor)),
          const SizedBox(height: 4),
          Text(widget.summary.secondaryMetric, style: t.bodySmall),
        ],
      ),
    );
  }

  Color _resolveColor(StatusColor sc) => switch (sc) {
        StatusColor.green => const Color(0xFF4CAF50),
        StatusColor.yellow => BanorteColors.warning,
        StatusColor.red => BanorteColors.red,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// InvestmentWidgetCard
// ─────────────────────────────────────────────────────────────────────────────

/// Widget card para portafolio de inversión en el Dashboard.
class InvestmentWidgetCard extends StatelessWidget {
  const InvestmentWidgetCard({
    super.key,
    required this.widget,
    this.onTap,
    this.onRemove,
  });

  final WidgetInstance widget;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const green = Color(0xFF4CAF50);
    return _DashboardCard(
      onTap: onTap,
      onRemove: onRemove,
      accentColor: green,
      icon: Icons.trending_up_rounded,
      header: Row(
        children: [
          _ModuleBadge(label: 'Inversión', color: green.withValues(alpha: 0.12), textColor: green),
          const Spacer(),
          _DragHandle(),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(widget.summary.primaryMetric,
              style: t.displaySmall?.copyWith(fontSize: 26, color: green)),
          const SizedBox(height: 4),
          Text(widget.summary.secondaryMetric, style: t.bodySmall),
          const SizedBox(height: 12),
          // Mini sparkline: simple visual de barras ascendentes
          _MiniSparkline(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Piezas reutilizables
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.child,
    required this.header,
    required this.accentColor,
    required this.icon,
    this.onTap,
    this.onRemove,
  });

  final Widget child;
  final Widget header;
  final Color accentColor;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BanorteColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border(left: BorderSide(color: accentColor, width: 4)),
            boxShadow: const [BoxShadow(color: Color(0x10323E48), blurRadius: 20, offset: Offset(0, 8))],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    header,
                    const SizedBox(height: 12),
                    child,
                  ],
                ),
              ),
              // Botón de eliminar
              if (onRemove != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16, color: BanorteColors.content3),
                    onPressed: onRemove,
                    tooltip: 'Eliminar widget',
                    splashRadius: 16,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleBadge extends StatelessWidget {
  const _ModuleBadge({required this.label, required this.color, required this.textColor});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
      );
}

class _DragHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Icon(Icons.drag_handle_rounded, color: BanorteColors.content4, size: 20);
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// Sparkline decorativa (barras ascendentes simulando crecimiento).
class _MiniSparkline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Alturas relativas de 12 barras simulando curva de crecimiento
    const heights = [0.3, 0.35, 0.38, 0.42, 0.48, 0.52, 0.58, 0.65, 0.72, 0.80, 0.90, 1.0];
    const green = Color(0xFF4CAF50);
    return SizedBox(
      height: 28,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final h in heights)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: FractionallySizedBox(
                  heightFactor: h,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.6 + h * 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Factory: dado un WidgetInstance, devuelve la card correcta
// ─────────────────────────────────────────────────────────────────────────────

Widget buildWidgetCard(WidgetInstance instance, {VoidCallback? onTap, VoidCallback? onRemove}) =>
    switch (instance.moduleType) {
      ModuleType.savingsGoal => GoalWidgetCard(widget: instance, onTap: onTap, onRemove: onRemove),
      ModuleType.budget => BudgetWidgetCard(widget: instance, onTap: onTap, onRemove: onRemove),
      ModuleType.investment => InvestmentWidgetCard(widget: instance, onTap: onTap, onRemove: onRemove),
    };
