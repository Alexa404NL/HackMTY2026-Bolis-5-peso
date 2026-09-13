import 'package:flutter/material.dart';

import '../a2ui/components.dart';
import '../a2ui/surface.dart';
import '../agent_client.dart';
import '../theme.dart';

/// Pantalla dedicada al módulo de Presupuesto.
///
/// El flujo es idéntico al de Metas: inicia un turno de agente con intención,
/// que arranca la secuencia de tarjetas A2UI de perfilamiento de presupuesto.
/// Al terminar, regresa un [WidgetInstance] (via callback) al Dashboard.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, this.onWidgetSaved});

  /// Llamado cuando el usuario guarda el plan y elige agregarlo al Dashboard.
  /// Recibe el mapa JSON del widget tal como lo devuelve [save_budget_plan].
  final void Function(Map<String, dynamic> widget)? onWidgetSaved;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late Surface _surface = _nueva();

  @override
  void initState() {
    super.initState();
    _surface.addListener(_onSurfaceUpdated);
  }

  void _onSurfaceUpdated() {
    if (_surface.data.containsKey('widget') && widget.onWidgetSaved != null) {
      widget.onWidgetSaved!(_surface.data['widget'] as Map<String, dynamic>);
      _surface.removeListener(_onSurfaceUpdated);
      Navigator.of(context).pop();
    }
  }

  Surface _nueva() => Surface(AgentClient().sendTurn);

  void _reiniciar() => setState(() {
        _surface.removeListener(_onSurfaceUpdated);
        _surface.dispose();
        _surface = _nueva();
        _surface.addListener(_onSurfaceUpdated);
      });

  void _empezar() {
    // El módulo de presupuesto no necesita texto de intención libre;
    // enviamos directamente el turno de arranque del módulo.
    _surface.start('Quiero configurar mi presupuesto mensual');
  }

  @override
  void dispose() {
    _surface.removeListener(_onSurfaceUpdated);
    _surface.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: BanorteColors.background,
      appBar: AppBar(
        backgroundColor: BanorteColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: BanorteColors.darkGray),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Presupuesto Mensual',
          style: t.titleMedium?.copyWith(color: BanorteColors.darkGray),
        ),
        actions: [
          if (!_surface.isEmpty)
            TextButton.icon(
              onPressed: _reiniciar,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reiniciar'),
              style: TextButton.styleFrom(foregroundColor: BanorteColors.gray),
            ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _surface,
          builder: (context, _) => Column(
            children: [
              _surface.busy
                  ? const LinearProgressIndicator(
                      minHeight: 3,
                      color: BanorteColors.red,
                      backgroundColor: Colors.transparent,
                    )
                  : const SizedBox(height: 3),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_surface.isEmpty) _hero(context),
                          if (!_surface.isEmpty)
                            BudgetSurfaceView(
                              surface: _surface,
                              onWidgetSaved: widget.onWidgetSaved,
                            ),
                          if (_surface.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                _surface.error!,
                                style: const TextStyle(color: BanorteColors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final busy = _surface.busy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono decorativo
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: BanorteColors.warning.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.account_balance_wallet_rounded, color: BanorteColors.warning, size: 32),
        ),
        const SizedBox(height: 24),
        Text('Conoce a dónde\nva tu dinero.', style: t.displaySmall),
        const SizedBox(height: 12),
        Text(
          'Te haremos unas preguntas sobre tus ingresos y gastos para '
          'generar un plan de presupuesto personalizado con Banorte.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 32),
        // Highlights del módulo
        _highlight(Icons.bar_chart_rounded, 'Visualiza tus gastos por categoría'),
        const SizedBox(height: 12),
        _highlight(Icons.savings_rounded, 'Calcula tu potencial de ahorro mensual'),
        const SizedBox(height: 12),
        _highlight(Icons.warning_amber_rounded, 'Detecta áreas donde puedes mejorar'),
        const SizedBox(height: 40),
        FilledButton(
          onPressed: busy ? null : _empezar,
          child: const Text('Analizar mi presupuesto'),
        ),
      ],
    );
  }

  Widget _highlight(IconData icon, String texto) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: BanorteColors.background2,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: BanorteColors.darkGray),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}

/// Vista de superficie del módulo de Presupuesto con callback para guardar widget.
class BudgetSurfaceView extends StatelessWidget {
  const BudgetSurfaceView({super.key, required this.surface, this.onWidgetSaved});

  final Surface surface;
  final void Function(Map<String, dynamic>)? onWidgetSaved;

  @override
  Widget build(BuildContext context) =>
      ListenableBuilder(listenable: surface, builder: (context, _) => _build('root'));

  Widget _build(String id) {
    final c = surface.components[id];
    if (c == null) return UnknownComponent('falta el componente "$id"');
    return switch (c['component']) {
      'Column' => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final child in (c['children'] as List).cast<String>())
              Padding(padding: const EdgeInsets.only(bottom: 16), child: _build(child)),
          ],
        ),
      'TarjetaPregunta' => TarjetaPregunta(key: ObjectKey(c), props: c, surface: surface),
      'MensajeAgente' => MensajeAgente(props: c),
      'PlanPresupuesto' => PlanPresupuesto(
          key: ObjectKey(c),
          props: c,
          surface: surface,
          onWidgetSaved: onWidgetSaved,
        ),
      'ResumenPresupuestoGuardado' => ResumenPresupuestoGuardado(props: c),
      final other => UnknownComponent('"$other" no está en el catálogo de Presupuesto'),
    };
  }
}
