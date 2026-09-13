import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../a2ui/surface.dart';
import '../agent_client.dart';
import '../models/dashboard_model.dart';
import '../screens/budget_screen.dart';
import '../screens/detalle_widget_screen.dart';
import '../screens/investment_screen.dart';
import '../theme.dart';
import '../widgets/add_widget_modal.dart';
import '../widgets/widget_cards.dart';

/// Pantalla principal: Dashboard personalizable con widgets reordenables.
///
/// Flujo:
/// 1. Estado vacío → CTA para agregar el primer widget
/// 2. Modal de selección → navega a la pantalla del módulo elegido
/// 3. El módulo regresa un widget JSON → se agrega a la lista y se persiste
/// 4. Mantener presionado → modo edición: arrastrar en snap grid de 4 columnas,
///    cambiar forma (cuadrado / horizontal / vertical) y eliminar
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  static const _gap = 8.0;
  static const _padding = 20.0;

  final List<WidgetInstance> _widgets = [];
  bool _cargando = false;
  Surface? _goalSurface;

  bool _editando = false;
  String? _arrastrandoId;
  Offset _delta = Offset.zero;
  late final _jiggle = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));

  @override
  void initState() {
    super.initState();
    _cargarDashboard();
  }

  @override
  void dispose() {
    _goalSurface?.dispose();
    _jiggle.dispose();
    super.dispose();
  }

  // ─── Persistencia vía MCP (Dashboard tools) ───────────────────────────────

  Future<void> _cargarDashboard() async {
    setState(() => _cargando = true);
    try {
      final client = AgentClient();
      final msgs = await client.sendTurn(texto: '__get_dashboard__');
      // El servidor devuelve mensajes A2UI; buscamos el updateDataModel con widgets
      for (final m in msgs) {
        if (m['updateDataModel'] case final Map u) {
          final value = u['value'] as Map<String, dynamic>?;
          if (value != null && value['widgets'] is List) {
            final raw = (value['widgets'] as List).cast<Map<String, dynamic>>();
            setState(() {
              _widgets.clear();
              _widgets.addAll(raw.map(WidgetInstance.fromJson));
              colocarLegacy(_widgets);
            });
          }
        }
      }
    } catch (_) {
      // Si el backend no está listo, iniciamos con dashboard vacío
    }
    setState(() => _cargando = false);
  }

  Future<void> _guardarLayout() async {
    try {
      final client = AgentClient();
      for (var i = 0; i < _widgets.length; i++) {
        _widgets[i].order = i;
      }
      final payload = _widgets.map((w) => w.toJson()).toList();
      await client.sendTurn(action: {
        'name': 'save_dashboard_layout',
        'widgets': payload,
      });
    } catch (_) {
      // Error silencioso — el orden local ya se actualizó
    }
  }

  // ─── Agregar widget ────────────────────────────────────────────────────────

  Future<void> _agregarWidget() async {
    final choice = await AddWidgetModal.show(context);
    if (choice == null || !mounted) return;

    switch (choice) {
      case ModuleChoice.savingsGoal:
        await _abrirModuloMeta();
      case ModuleChoice.budget:
        await _abrirModuloBudget();
      case ModuleChoice.investment:
        await _abrirModuloInversion();
    }
  }

  Future<void> _abrirModuloMeta() async {
    // El módulo de metas ya existe — lo abrimos como pantalla
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _GoalModuleScreen(onWidgetSaved: _onWidgetReceived),
      ),
    );
  }

  Future<void> _abrirModuloBudget() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BudgetScreen(onWidgetSaved: _onWidgetReceived),
      ),
    );
  }

  Future<void> _abrirModuloInversion() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvestmentScreen(onWidgetSaved: _onWidgetReceived),
      ),
    );
  }

  void _onWidgetReceived(Map<String, dynamic> widgetJson) {
    final w = WidgetInstance.fromJson({
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      ...widgetJson,
      'order': _widgets.length,
    });
    final (x, y) = primerHueco(_widgets, WidgetShape.square);
    w
      ..shape = WidgetShape.square
      ..x = x
      ..y = y;
    setState(() => _widgets.add(w));
    _guardarLayout();
  }

  // ─── Modo edición ──────────────────────────────────────────────────────────

  void _entrarEdicion() {
    if (_editando) return;
    HapticFeedback.mediumImpact();
    _jiggle.repeat(reverse: true);
    setState(() => _editando = true);
  }

  void _salirEdicion() {
    _jiggle.stop();
    setState(() => _editando = false);
  }

  void _terminarArrastre(WidgetInstance w, double paso) {
    final x = ((w.x * paso + _delta.dx) / paso).round();
    final y = ((w.y * paso + _delta.dy) / paso).round();
    final movido = mover(_widgets, w, x, y);
    setState(() {
      _arrastrandoId = null;
      _delta = Offset.zero;
    });
    if (movido) {
      HapticFeedback.lightImpact();
      _guardarLayout();
    }
  }

  void _cambiarForma(WidgetInstance w, WidgetShape s) {
    if (w.shape == s) return;
    HapticFeedback.selectionClick();
    setState(() => cambiarForma(_widgets, w, s));
    _guardarLayout();
  }

  void _eliminarWidget(WidgetInstance w) {
    setState(() {
      _widgets.remove(w);
      if (_widgets.isEmpty) {
        _editando = false;
        _jiggle.stop();
      }
    });
    _guardarLayout();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: BanorteColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // AppBar manual para full control del diseño
            _buildAppBar(t),
            if (_cargando)
              const LinearProgressIndicator(
                minHeight: 3,
                color: BanorteColors.red,
                backgroundColor: Colors.transparent,
              )
            else
              const SizedBox(height: 3),
            Expanded(
              child: _widgets.isEmpty
                  ? _buildEmptyState(t)
                  : _buildGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: _widgets.isEmpty || _editando
          ? null
          : FloatingActionButton.extended(
              onPressed: _agregarWidget,
              backgroundColor: BanorteColors.red,
              foregroundColor: BanorteColors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Agregar widget',
                style: TextStyle(fontFamily: gotham, fontWeight: FontWeight.w500),
              ),
            ),
    );
  }

  Widget _buildAppBar(TextTheme t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BANORTE',
                  style: TextStyle(
                    fontFamily: gotham,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 2,
                    color: BanorteColors.red,
                  ),
                ),
                const SizedBox(height: 2),
                Text('Mi Dashboard', style: t.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (_editando)
            FilledButton(
              onPressed: _salirEdicion,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 36)),
              child: const Text('Listo'),
            )
          else if (_widgets.isNotEmpty)
            Tooltip(
              message: 'Mantén presionado un widget para editar',
              child: GestureDetector(
                onTap: _entrarEdicion,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BanorteColors.background2,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_with_rounded, size: 14, color: BanorteColors.gray),
                      const SizedBox(width: 4),
                      Text('Editar', style: TextStyle(fontSize: 12, color: BanorteColors.gray)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(TextTheme t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Ilustración decorativa
            _EmptyIllustration(),
            const SizedBox(height: 32),
            Text(
              'Tu dashboard está vacío',
              style: t.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Agrega widgets de tus módulos financieros para '
              'visualizar tu dinero en un solo lugar.',
              style: t.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: _agregarWidget,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar primer widget'),
            ),
            const SizedBox(height: 12),
            // Chips de sugerencia
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _SuggestionChip(
                  icon: Icons.savings_rounded,
                  label: 'Meta de Ahorro',
                  onTap: () async {
                    await _abrirModuloMeta();
                  },
                ),
                _SuggestionChip(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Presupuesto',
                  onTap: () async {
                    await _abrirModuloBudget();
                  },
                ),
                _SuggestionChip(
                  icon: Icons.trending_up_rounded,
                  label: 'Inversión',
                  onTap: () async {
                    await _abrirModuloInversion();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (context, box) {
      final celda = (box.maxWidth - _padding * 2 - _gap * (gridCols - 1)) / gridCols;
      final paso = celda + _gap;
      final filas = filasOcupadas(_widgets) + (_editando ? 2 : 0);
      // El widget arrastrado se pinta al final para quedar encima.
      final orden = [
        ..._widgets.where((w) => w.id != _arrastrandoId),
        ..._widgets.where((w) => w.id == _arrastrandoId),
      ];
      return SingleChildScrollView(
        // ponytail: sin scroll en modo edición (el arrastre es inmediato); agregar auto-scroll si el grid excede la pantalla
        physics: _editando ? const NeverScrollableScrollPhysics() : null,
        padding: const EdgeInsets.fromLTRB(_padding, 8, _padding, 100),
        child: SizedBox(
          height: filas * paso - _gap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [for (final w in orden) _buildCelda(w, paso)],
          ),
        ),
      );
    });
  }

  Widget _buildCelda(WidgetInstance w, double paso) {
    final arrastrando = w.id == _arrastrandoId;
    final signo = _widgets.indexOf(w).isEven ? 1 : -1;
    return AnimatedPositioned(
      key: ValueKey(w.id),
      duration: arrastrando ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: w.x * paso + (arrastrando ? _delta.dx : 0),
      top: w.y * paso + (arrastrando ? _delta.dy : 0),
      width: w.shape.w * paso - _gap,
      height: w.shape.h * paso - _gap,
      // Long-press en ambos modos: entra a edición y arrastra en el mismo gesto.
      child: GestureDetector(
        // Fuera de edición abre el detalle; en edición abre la hoja de forma / eliminar.
        onTap: () => _editando ? _editarWidget(w) : _abrirDetalle(w),
        onLongPressStart: (_) {
          _entrarEdicion();
          setState(() => _arrastrandoId = w.id);
        },
        onLongPressMoveUpdate: (d) => setState(() => _delta = d.offsetFromOrigin),
        onLongPressEnd: (_) => _terminarArrastre(w, paso),
        // En edición el arrastre es inmediato (mouse o dedo).
        onPanStart: _editando ? (_) => setState(() => _arrastrandoId = w.id) : null,
        onPanUpdate: _editando ? (d) => setState(() => _delta += d.delta) : null,
        onPanEnd: _editando ? (_) => _terminarArrastre(w, paso) : null,
        child: AnimatedBuilder(
          animation: _jiggle,
          builder: (context, child) => Transform.rotate(
            angle: _editando && !arrastrando ? signo * (_jiggle.value - 0.5) * 0.02 : 0,
            child: AnimatedScale(
              scale: arrastrando ? 1.05 : 1,
              duration: const Duration(milliseconds: 150),
              child: child,
            ),
          ),
          child: buildWidgetCard(w),
        ),
      ),
    );
  }

  Future<void> _abrirDetalle(WidgetInstance w) async {
    final resultado = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DetalleWidgetScreen(instancia: w)),
    );
    if (!mounted) return;
    if (resultado == 'eliminar') {
      _eliminarWidget(w);
    } else {
      // Lo editado en el detalle (ej. la meta) se refleja al rehidratar el dashboard.
      await _cargarDashboard();
    }
  }

  Future<void> _editarWidget(WidgetInstance w) async {
    final accion = await showModalBottomSheet<Object>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _HojaEdicion(instancia: w),
    );
    if (!mounted) return;
    switch (accion) {
      case final WidgetShape s:
        _cambiarForma(w, s);
      case 'eliminar':
        _eliminarWidget(w);
    }
  }
}

// ─── Controles de edición ────────────────────────────────────────────────────

/// Hoja inferior de edición: regresa la [WidgetShape] elegida o `'eliminar'`.
class _HojaEdicion extends StatelessWidget {
  const _HojaEdicion({required this.instancia});
  final WidgetInstance instancia;

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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: BanorteColors.content5, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 20),
          Text(instancia.title, style: t.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text('Elige la forma del widget', style: t.bodyMedium),
          const SizedBox(height: 16),
          Row(children: [
            for (final (s, icon, label) in const [
              (WidgetShape.square, Icons.crop_square_rounded, 'Cuadrado'),
              (WidgetShape.wide, Icons.crop_16_9_rounded, 'Horizontal'),
              (WidgetShape.tall, Icons.crop_portrait_rounded, 'Vertical'),
            ])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _OpcionForma(
                    icon: icon,
                    label: label,
                    seleccionada: s == instancia.shape,
                    onTap: () => Navigator.pop(context, s),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, 'eliminar'),
            icon: const Icon(Icons.delete_outline_rounded, color: BanorteColors.red),
            label: const Text('Eliminar widget', style: TextStyle(color: BanorteColors.red)),
          ),
        ],
      ),
    );
  }
}

class _OpcionForma extends StatelessWidget {
  const _OpcionForma({required this.icon, required this.label, required this.seleccionada, required this.onTap});
  final IconData icon;
  final String label;
  final bool seleccionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = seleccionada ? BanorteColors.red : BanorteColors.darkGray;
    return Semantics(
      button: true,
      selected: seleccionada,
      child: Material(
        color: seleccionada ? BanorteColors.red.withValues(alpha: 0.1) : BanorteColors.background2,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Icon(icon, color: color),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────

class _EmptyIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo exterior
          Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: BanorteColors.background2,
              shape: BoxShape.circle,
            ),
          ),
          // Círculo medio
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: BanorteColors.content5.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          // Iconos flotantes
          Positioned(
            top: 20,
            right: 24,
            child: _FloatingIcon(icon: Icons.savings_rounded, color: BanorteColors.red),
          ),
          Positioned(
            bottom: 28,
            left: 20,
            child: _FloatingIcon(icon: Icons.account_balance_wallet_rounded, color: BanorteColors.warning),
          ),
          Positioned(
            bottom: 20,
            right: 28,
            child: _FloatingIcon(icon: Icons.trending_up_rounded, color: const Color(0xFF4CAF50)),
          ),
          // Icono central
          const Icon(Icons.dashboard_rounded, size: 40, color: BanorteColors.content3),
        ],
      ),
    );
  }
}

class _FloatingIcon extends StatelessWidget {
  const _FloatingIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: BanorteColors.white,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: BanorteColors.darkGray),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(fontSize: 13, color: BanorteColors.darkGray)),
              ],
            ),
          ),
        ),
      );
}

// ─── Módulo de Metas como pantalla (wrapping el flujo existente) ──────────────

class _GoalModuleScreen extends StatefulWidget {
  const _GoalModuleScreen({this.onWidgetSaved});
  final void Function(Map<String, dynamic>)? onWidgetSaved;

  @override
  State<_GoalModuleScreen> createState() => _GoalModuleScreenState();
}

class _GoalModuleScreenState extends State<_GoalModuleScreen> {
  late Surface _surface = Surface(AgentClient().sendTurn);
  final _intencion = TextEditingController();

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

  @override
  void dispose() {
    _surface.removeListener(_onSurfaceUpdated);
    _surface.dispose();
    _intencion.dispose();
    super.dispose();
  }

  void _empezar([String? texto]) {
    final t = (texto ?? _intencion.text).trim();
    if (t.isNotEmpty) _surface.start(t);
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
        title: Text('Meta de Ahorro', style: t.titleMedium?.copyWith(color: BanorteColors.darkGray)),
        actions: [
          if (!_surface.isEmpty)
            TextButton.icon(
              onPressed: () => setState(() {
                _surface.removeListener(_onSurfaceUpdated);
                _surface.dispose();
                _surface = Surface(AgentClient().sendTurn);
                _surface.addListener(_onSurfaceUpdated);
                _intencion.clear();
              }),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Nueva'),
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
                  ? const LinearProgressIndicator(minHeight: 3, color: BanorteColors.red, backgroundColor: Colors.transparent)
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
                          if (!_surface.isEmpty) SurfaceView(surface: _surface),
                          if (_surface.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(_surface.error!, style: const TextStyle(color: BanorteColors.red)),
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
    const sugerencias = {
      'Viaje': 'Quiero ahorrar para un viaje',
      'Enganche': 'Quiero juntar el enganche de mi casa',
      'Emergencias': 'Quiero un fondo de emergencia',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: BanorteColors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.savings_rounded, color: BanorteColors.red, size: 32),
        ),
        const SizedBox(height: 24),
        Text('Ahorra con\nintención.', style: t.displaySmall),
        const SizedBox(height: 12),
        Text(
          'Cuéntanos para qué quieres ahorrar y generaremos una proyección ajustable.',
          style: t.bodyMedium,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: _intencion,
          enabled: !busy,
          decoration: const InputDecoration(hintText: '¿Para qué quieres ahorrar?'),
          onSubmitted: (_) => _empezar(),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: busy ? null : _empezar, child: const Text('Empezar')),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final MapEntry(key: etiqueta, value: frase) in sugerencias.entries)
              SizedBox(
                width: 160,
                child: Material(
                  color: BanorteColors.white,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: busy ? null : () => _empezar(frase),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(etiqueta,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: BanorteColors.red,
                                  )),
                              const Icon(Icons.north_east_rounded, size: 16, color: BanorteColors.content3),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(frase, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
