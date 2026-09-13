import 'package:flutter/material.dart';

import '../a2ui/components.dart';
import '../a2ui/surface.dart';
import '../agent_client.dart';
import '../theme.dart';

/// Pantalla dedicada al módulo de Inversiones.
///
/// Inicia el flujo de perfilamiento de inversión con tarjetas A2UI y al
/// finalizar ofrece guardar el plan y agregar el widget al Dashboard.
class InvestmentScreen extends StatefulWidget {
  const InvestmentScreen({super.key, this.onWidgetSaved});

  /// Llamado cuando el usuario guarda el plan y elige agregarlo al Dashboard.
  final void Function(Map<String, dynamic> widget)? onWidgetSaved;

  @override
  State<InvestmentScreen> createState() => _InvestmentScreenState();
}

class _InvestmentScreenState extends State<InvestmentScreen> {
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
    _surface.start('Quiero empezar a invertir con Banorte');
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
          'Portafolio de Inversión',
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
                            InvestmentSurfaceView(
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

    // Tarjetas de perfiles
    const perfiles = [
      (
        icono: Icons.shield_rounded,
        nombre: 'Conservador',
        desc: 'CETES + Renta Fija',
        rendimiento: '+9.5% anual',
        color: Color(0xFF4CAF50),
      ),
      (
        icono: Icons.balance_rounded,
        nombre: 'Moderado',
        desc: 'Mixto balanceado',
        rendimiento: '+10.8% anual',
        color: BanorteColors.warning,
      ),
      (
        icono: Icons.trending_up_rounded,
        nombre: 'Agresivo',
        desc: 'Renta Variable',
        rendimiento: '+12.1% anual',
        color: BanorteColors.red,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.trending_up_rounded, color: Color(0xFF4CAF50), size: 32),
        ),
        const SizedBox(height: 24),
        Text('Haz crecer\ntu dinero.', style: t.displaySmall),
        const SizedBox(height: 12),
        Text(
          'Descubre el portafolio de inversión ideal para tu perfil '
          'y simula cómo crece tu capital con instrumentos Banorte.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 28),
        // Preview de perfiles de riesgo
        Row(
          children: [
            for (final p in perfiles)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _perfilCard(p.icono, p.nombre, p.desc, p.rendimiento, p.color),
                ),
              ),
          ],
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: busy ? null : _empezar,
          child: const Text('Descubrir mi perfil'),
        ),
      ],
    );
  }

  Widget _perfilCard(IconData icon, String nombre, String desc, String rend, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BanorteColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BanorteColors.content5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(nombre, style: const TextStyle(fontFamily: gotham, fontSize: 12, fontWeight: FontWeight.w700)),
          Text(desc, style: const TextStyle(fontSize: 11, color: BanorteColors.gray)),
          const SizedBox(height: 4),
          Text(rend, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

/// Vista de superficie del módulo de Inversión con callback para guardar widget.
class InvestmentSurfaceView extends StatelessWidget {
  const InvestmentSurfaceView({super.key, required this.surface, this.onWidgetSaved});

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
      'PlanInversion' => PlanInversion(
          key: ObjectKey(c),
          props: c,
          surface: surface,
          onWidgetSaved: onWidgetSaved,
        ),
      'ResumenInversionGuardada' => ResumenInversionGuardada(props: c),
      final other => UnknownComponent('"$other" no está en el catálogo de Inversión'),
    };
  }
}
