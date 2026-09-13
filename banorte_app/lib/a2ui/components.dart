import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme.dart';
import 'surface.dart';

String mxn(num v) {
  final s = v.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return '\$$b';
}

String _capital(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// --- Piezas visuales (estilo de `reference ui/`) ---------------------------------

class BanorteCard extends StatelessWidget {
  const BanorteCard({super.key, required this.child, this.color = BanorteColors.white});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: Color(0x14323E48), blurRadius: 32, offset: Offset(0, 12))],
        ),
        child: child,
      );
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = BanorteColors.background2, this.textColor = BanorteColors.darkGray});

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor),
        ),
      );
}

class ArrowButton extends StatelessWidget {
  const ArrowButton({super.key, this.color = BanorteColors.background2, this.onTap});

  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const SizedBox.square(
            dimension: 40,
            child: Icon(Icons.north_east, size: 18, color: BanorteColors.darkGray),
          ),
        ),
      );
}

class OptionPill extends StatelessWidget {
  const OptionPill({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: BanorteColors.background2,
        shape: const StadiumBorder(side: BorderSide(color: BanorteColors.content5)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          hoverColor: BanorteColors.red.withValues(alpha: 0.08),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      );
}

class UnknownComponent extends StatelessWidget {
  const UnknownComponent(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) =>
      Pill('⚠ $message', color: BanorteColors.alert.withValues(alpha: 0.15), textColor: BanorteColors.darkGray);
}

// --- Catálogo banorte-ahorro/v1 --------------------------------------------------

class MensajeAgente extends StatelessWidget {
  const MensajeAgente({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: BanorteColors.red, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(props['texto'] as String? ?? '', style: Theme.of(context).textTheme.bodyMedium)),
        ],
      );
}

class TarjetaPregunta extends StatefulWidget {
  const TarjetaPregunta({super.key, required this.props, required this.surface});

  final Map<String, dynamic> props;
  final Surface surface;

  @override
  State<TarjetaPregunta> createState() => _TarjetaPreguntaState();
}

class _TarjetaPreguntaState extends State<TarjetaPregunta> {
  final _monto = TextEditingController();

  @override
  void dispose() {
    _monto.dispose();
    super.dispose();
  }

  void _responder(Object? valor) => widget.surface.dispatch(
        widget.props['id'] as String,
        widget.props['action'] as Map<String, dynamic>,
        {'campo': widget.props['campo'], 'valor': valor},
      );

  void _enviarMonto() {
    final texto = _monto.text.trim();
    if (texto.isNotEmpty) _responder(texto);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.props;
    final t = Theme.of(context).textTheme;
    final paso = p['paso'] as int;
    final total = p['total'] as int;
    final opciones = (p['opciones'] as List?)?.cast<Map<String, dynamic>>();
    final busy = widget.surface.busy;

    return BanorteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Pill('Pregunta $paso de $total'), const Spacer(), const ArrowButton()]),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: paso / total,
              minHeight: 4,
              color: BanorteColors.red,
              backgroundColor: BanorteColors.background2,
            ),
          ),
          const SizedBox(height: 24),
          Text(p['pregunta'] as String, style: t.headlineMedium),
          if (p['error'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${p['error']}', style: const TextStyle(color: BanorteColors.red)),
            ),
          const SizedBox(height: 24),
          if (opciones != null)
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final o in opciones)
                  OptionPill(label: o['etiqueta'] as String, onTap: busy ? null : () => _responder(o['valor'])),
              ],
            )
          else ...[
            TextField(
              controller: _monto,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontFamily: gotham,
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: BanorteColors.darkGray,
              ),
              decoration: const InputDecoration(prefixText: '\$ ', hintText: '0'),
              onSubmitted: (_) => _enviarMonto(),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: busy ? null : _enviarMonto, child: const Text('Continuar')),
          ],
        ],
      ),
    );
  }
}

class ProyeccionAhorro extends StatefulWidget {
  const ProyeccionAhorro({super.key, required this.props, required this.surface});

  final Map<String, dynamic> props;
  final Surface surface;

  @override
  State<ProyeccionAhorro> createState() => _ProyeccionAhorroState();
}

class _ProyeccionAhorroState extends State<ProyeccionAhorro> {
  late double _mensual = (widget.props['aportacion_periodica'] as num).toDouble();
  late double _plazo = (widget.props['plazo_meses'] as num).toDouble();
  late final double _maxMensual = (math.max(20000, _mensual * 2) / 500).ceil() * 500;

  void _editar(String campo, num valor) => widget.surface.dispatch(
        widget.props['id'] as String,
        widget.props['accionEditar'] as Map<String, dynamic>,
        {
          'cambios': [
            {'campo': campo, 'valor': valor},
          ],
        },
      );

  static const _otrosColores = [BanorteColors.darkGray, BanorteColors.content3];

  @override
  Widget build(BuildContext context) {
    final p = widget.props;
    final t = Theme.of(context).textTheme;
    final multi = p['component'] == 'ProyeccionAhorroMulti';
    final escenarios = (p['escenarios'] as List).cast<Map<String, dynamic>>();
    final elegido = escenarios.firstWhere((e) => e['perfil'] == p['perfil_elegido'], orElse: () => escenarios.first);
    final meta = p['monto_meta'] as num;
    final saldo = elegido['saldo_final'] as num;
    final mesMeta = elegido['mes_meta'];
    final guardada = p['guardada'] == true;
    final busy = widget.surface.busy;

    var i = 0;
    final colores = {
      for (final e in escenarios) e['perfil']: identical(e, elegido) ? BanorteColors.red : _otrosColores[i++ % 2],
    };

    return BanorteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Pill(p['objetivo'] as String),
                    Pill(multi ? '3 escenarios' : 'Proyección simple'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const ArrowButton(),
            ],
          ),
          const SizedBox(height: 20),
          Text('Saldo proyectado', style: t.bodySmall),
          const SizedBox(height: 4),
          Text(mxn(saldo), style: t.displaySmall),
          const SizedBox(height: 8),
          Text(
            mesMeta == null
                ? 'Te faltarían ${mxn(meta - saldo)} para tu meta de ${mxn(meta)}.'
                : 'Alcanzas tu meta de ${mxn(meta)} en el mes $mesMeta.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(height: 220, child: _grafica(escenarios, elegido, colores, meta)),
          if (multi) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                for (final e in escenarios)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: colores[e['perfil']], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_capital(e['perfil'] as String)} · ${((e['tasa'] as num) * 100).round()}% anual',
                        style: t.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _Control(
            etiqueta: 'Ahorro mensual',
            valor: mxn(_mensual),
            slider: Slider(
              value: _mensual.clamp(0, _maxMensual),
              max: _maxMensual,
              divisions: _maxMensual ~/ 500,
              onChanged: busy ? null : (v) => setState(() => _mensual = v),
              onChangeEnd: (v) => _editar('aportacion_periodica', v.round()),
            ),
          ),
          _Control(
            etiqueta: 'Plazo',
            valor: '${_plazo.round()} meses',
            slider: Slider(
              value: _plazo.clamp(3, 120),
              min: 3,
              max: 120,
              divisions: 117,
              onChanged: busy ? null : (v) => setState(() => _plazo = v),
              onChangeEnd: (v) => _editar('plazo_meses', v.round()),
            ),
          ),
          const SizedBox(height: 8),
          if (guardada)
            const OutlinedButton(onPressed: null, child: Text('Meta guardada ✓'))
          else
            FilledButton(
              onPressed: busy
                  ? null
                  : () => widget.surface.dispatch(p['id'] as String, p['accionGuardar'] as Map<String, dynamic>),
              child: const Text('Guardar meta'),
            ),
        ],
      ),
    );
  }

  Widget _grafica(List<Map<String, dynamic>> escenarios, Map<String, dynamic> elegido, Map<Object?, Color> colores,
      num meta) {
    final maxSerie = escenarios.expand((e) => (e['serie'] as List).cast<num>()).reduce(math.max);
    final plazo = (widget.props['plazo_meses'] as num).toDouble();
    const etiqueta = TextStyle(fontSize: 11, color: BanorteColors.content2);
    String corto(double v) =>
        v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)}M' : (v >= 1e3 ? '${(v / 1e3).round()}k' : '${v.round()}');
    const sinTitulos = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: math.max(meta, maxSerie) * 1.12,
        minX: 0,
        maxX: plazo,
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: BanorteColors.background2, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: sinTitulos,
          rightTitles: sinTitulos,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(corto(v), style: etiqueta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: math.max(1, (plazo / 6).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}m', style: etiqueta),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: meta.toDouble(),
              color: BanorteColors.success,
              strokeWidth: 2,
              dashArray: const [6, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BanorteColors.success),
                labelResolver: (_) => 'Meta',
              ),
            ),
          ],
        ),
        lineBarsData: [
          // el escenario elegido va al final para que quede encima
          for (final e in [...escenarios.where((e) => !identical(e, elegido)), elegido])
            LineChartBarData(
              spots: [
                for (final (mes, y) in (e['serie'] as List).cast<num>().indexed) FlSpot(mes.toDouble(), y.toDouble()),
              ],
              isCurved: true,
              color: colores[e['perfil']],
              barWidth: identical(e, elegido) ? 4 : 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: identical(e, elegido),
                color: BanorteColors.red.withValues(alpha: 0.08),
              ),
            ),
        ],
      ),
    );
  }
}

class _Control extends StatelessWidget {
  const _Control({required this.etiqueta, required this.valor, required this.slider});

  final String etiqueta;
  final String valor;
  final Widget slider;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [Text(etiqueta, style: t.bodyMedium), const Spacer(), Text(valor, style: t.titleMedium)]),
        slider,
      ],
    );
  }
}

class ResumenMetaGuardada extends StatelessWidget {
  const ResumenMetaGuardada({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final p = props;
    const claro = TextStyle(color: Color(0xB3FFFFFF), fontSize: 14);
    const fuerte = TextStyle(fontFamily: gotham, color: BanorteColors.white, fontSize: 16, fontWeight: FontWeight.w500);
    final mesMeta = p['mes_meta'];
    Widget fila(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Text(k, style: claro), const Spacer(), Text(v, style: fuerte)]),
        );

    return BanorteCard(
      color: BanorteColors.darkGray,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: BanorteColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: BanorteColors.white),
              ),
              const Spacer(),
              Pill('Meta #${p['goal_id']}', color: const Color(0x26FFFFFF), textColor: BanorteColors.white),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Meta guardada',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: BanorteColors.white),
          ),
          const SizedBox(height: 4),
          Text(p['objetivo'] as String, style: claro),
          const SizedBox(height: 16),
          fila('Meta', mxn(p['monto_meta'] as num)),
          fila('Plazo', '${p['plazo_meses']} meses'),
          fila('Ahorro mensual', mxn(p['aportacion_periodica'] as num)),
          fila('Saldo proyectado', mxn(p['saldo_final'] as num)),
          const SizedBox(height: 8),
          Text(
            mesMeta == null ? 'Ajusta tu ahorro para alcanzar la meta a tiempo.' : 'Llegas a tu meta en el mes $mesMeta.',
            style: claro,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlanPresupuesto
// ─────────────────────────────────────────────────────────────────────────────

class PlanPresupuesto extends StatelessWidget {
  const PlanPresupuesto({
    super.key,
    required this.props,
    required this.surface,
    this.onWidgetSaved,
  });

  final Map<String, dynamic> props;
  final Surface surface;
  final void Function(Map<String, dynamic>)? onWidgetSaved;

  static const _categoryColors = [
    Color(0xFFEB0029), // red
    Color(0xFFFFA400), // amber
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFF9C27B0), // purple
    Color(0xFF00BCD4), // cyan
  ];

  @override
  Widget build(BuildContext context) {
    final p = props;
    final t = Theme.of(context).textTheme;
    final guardado = p['guardado'] == true;
    final busy = surface.busy;

    final ingreso = (p['ingreso_mensual'] as num).toDouble();
    final balance = (p['balance_disponible'] as num).toDouble();
    final totalGastos = (p['total_gastos'] as num).toDouble();
    final margen = (p['margen_ahorro_sugerido'] as num).toDouble();
    final categorias = (p['categorias'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final statusColorStr = p['status_color'] as String? ?? 'green';
    final statusColor = switch (statusColorStr) {
      'red' => BanorteColors.red,
      'yellow' => BanorteColors.warning,
      _ => const Color(0xFF4CAF50),
    };
    final statusLabel = switch (statusColorStr) {
      'red' => 'Déficit — revisa tus gastos',
      'yellow' => 'Ajustado — hay margen de mejora',
      _ => 'Saludable — ¡vas bien!',
    };

    return BanorteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill('Presupuesto Mensual', color: BanorteColors.warning.withValues(alpha: 0.15), textColor: BanorteColors.warning),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Métrica principal: balance
          Text('Balance disponible', style: t.bodySmall),
          const SizedBox(height: 4),
          Text(
            mxn(balance),
            style: t.displaySmall?.copyWith(color: statusColor),
          ),
          const SizedBox(height: 4),
          Text(statusLabel, style: t.bodySmall?.copyWith(color: statusColor)),
          const SizedBox(height: 24),
          // Desglose de categorías
          if (categorias.isNotEmpty) ...[
            Text('Distribución de gastos', style: t.bodySmall),
            const SizedBox(height: 12),
            ...List.generate(categorias.length, (i) {
              final cat = categorias[i];
              final pct = (cat['porcentaje'] as num).toDouble();
              final monto = (cat['monto'] as num).toDouble();
              final color = _categoryColors[i % _categoryColors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(cat['nombre'] as String, style: t.bodySmall)),
                        Text(mxn(monto), style: t.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text('${pct.toStringAsFixed(1)}%', style: t.bodySmall?.copyWith(color: BanorteColors.content3)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 4,
                        color: color,
                        backgroundColor: BanorteColors.background2,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 8),
          // Resumen: ingresos, gastos, ahorro sugerido
          _ResumenFila('Ingresos', mxn(ingreso), BanorteColors.darkGray),
          _ResumenFila('Gastos totales', mxn(totalGastos), BanorteColors.red),
          _ResumenFila('Ahorro sugerido', mxn(margen), const Color(0xFF4CAF50)),
          const SizedBox(height: 24),
          if (guardado)
            const OutlinedButton(onPressed: null, child: Text('Plan guardado ✓'))
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BanorteColors.warning),
              onPressed: busy
                  ? null
                  : () => surface.dispatch(
                        p['id'] as String,
                        p['accionGuardar'] as Map<String, dynamic>,
                      ),
              child: const Text('Guardar plan de presupuesto'),
            ),
        ],
      ),
    );
  }
}

class _ResumenFila extends StatelessWidget {
  const _ResumenFila(this.label, this.valor, this.color);
  final String label;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const Spacer(),
            Text(valor, style: TextStyle(fontFamily: gotham, fontSize: 14, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// ResumenPresupuestoGuardado
// ─────────────────────────────────────────────────────────────────────────────

class ResumenPresupuestoGuardado extends StatelessWidget {
  const ResumenPresupuestoGuardado({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final p = props;
    final t = Theme.of(context).textTheme;
    const claro = TextStyle(color: Color(0xB3FFFFFF), fontSize: 14);
    const fuerte = TextStyle(fontFamily: gotham, color: BanorteColors.white, fontSize: 16, fontWeight: FontWeight.w500);

    Widget fila(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Text(k, style: claro), const Spacer(), Text(v, style: fuerte)]),
        );

    return BanorteCard(
      color: const Color(0xFF2D6A4F), // Verde oscuro
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: BanorteColors.success, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: BanorteColors.white),
              ),
              const Spacer(),
              Pill('Plan #${p['budget_id']}', color: const Color(0x26FFFFFF), textColor: BanorteColors.white),
            ],
          ),
          const SizedBox(height: 20),
          Text('Plan guardado', style: t.headlineMedium?.copyWith(color: BanorteColors.white)),
          const SizedBox(height: 4),
          Text('Presupuesto Mensual', style: claro),
          const SizedBox(height: 16),
          fila('Ingreso mensual', mxn((p['ingreso_mensual'] as num?) ?? 0)),
          fila('Gastos totales', mxn((p['total_gastos'] as num?) ?? 0)),
          fila('Balance disponible', mxn((p['balance_disponible'] as num?) ?? 0)),
          fila('Ahorro sugerido', mxn((p['margen_ahorro_sugerido'] as num?) ?? 0)),
          const SizedBox(height: 8),
          const Text('Tu plan de presupuesto ha sido guardado en tu Dashboard.', style: claro),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PlanInversion
// ─────────────────────────────────────────────────────────────────────────────

class PlanInversion extends StatelessWidget {
  const PlanInversion({
    super.key,
    required this.props,
    required this.surface,
    this.onWidgetSaved,
  });

  final Map<String, dynamic> props;
  final Surface surface;
  final void Function(Map<String, dynamic>)? onWidgetSaved;

  @override
  Widget build(BuildContext context) {
    final p = props;
    final t = Theme.of(context).textTheme;
    final guardado = p['guardado'] == true;
    final busy = surface.busy;

    final montoFinal = (p['monto_final_proyectado'] as num).toDouble();
    final capitalAportado = (p['capital_aportado_total'] as num).toDouble();
    final rendPct = (p['rendimiento_porcentual'] as num).toDouble();
    final rendTotal = (p['rendimiento_estimado_total'] as num).toDouble();
    final plazo = (p['plazo_meses'] as num).toInt();
    final perfil = _capital(p['perfil_riesgo'] as String? ?? 'conservador');
    final instrumentos = (p['instrumentos'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final serie = (p['serie_mensual'] as List?)?.cast<num>() ?? [];

    const green = Color(0xFF4CAF50);
    final signo = rendPct >= 0 ? '+' : '';

    return BanorteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill('Inversión · $perfil', color: green.withValues(alpha: 0.12), textColor: green),
              const Spacer(),
              const ArrowButton(),
            ],
          ),
          const SizedBox(height: 20),
          Text('Valor final proyectado', style: t.bodySmall),
          const SizedBox(height: 4),
          Text(mxn(montoFinal), style: t.displaySmall?.copyWith(color: green)),
          const SizedBox(height: 4),
          Text('$signo${rendPct.toStringAsFixed(1)}% en $plazo meses', style: t.bodySmall?.copyWith(color: green)),
          const SizedBox(height: 24),
          // Gráfica de crecimiento
          if (serie.isNotEmpty) ...[
            SizedBox(height: 160, child: _GraficaCrecimiento(serie: serie, monto: capitalAportado)),
            const SizedBox(height: 16),
          ],
          // Distribución del portafolio
          if (instrumentos.isNotEmpty) ...[
            Text('Distribución del portafolio', style: t.bodySmall),
            const SizedBox(height: 12),
            ...instrumentos.asMap().entries.map((e) {
              final inst = e.value;
              final colors = [BanorteColors.red, BanorteColors.warning, green];
              final color = colors[e.key % colors.length];
              final pct = (inst['porcentaje'] as num).toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(inst['nombre'] as String, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(
                      '${pct.toStringAsFixed(0)}% · ${((inst['rendimiento_anual'] as num) * 100).toStringAsFixed(1)}% anual',
                      style: t.bodySmall?.copyWith(color: BanorteColors.content2),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
          ],
          // Resumen
          _ResumenFila('Capital aportado', mxn(capitalAportado), BanorteColors.darkGray),
          _ResumenFila('Ganancia estimada', mxn(rendTotal), green),
          const SizedBox(height: 24),
          if (guardado)
            const OutlinedButton(onPressed: null, child: Text('Inversión guardada ✓'))
          else
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: green),
              onPressed: busy
                  ? null
                  : () => surface.dispatch(
                        p['id'] as String,
                        p['accionGuardar'] as Map<String, dynamic>,
                      ),
              child: const Text('Guardar plan de inversión'),
            ),
        ],
      ),
    );
  }
}

class _GraficaCrecimiento extends StatelessWidget {
  const _GraficaCrecimiento({required this.serie, required this.monto});

  final List<num> serie;
  final double monto;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4CAF50);
    final maxY = serie.reduce(math.max).toDouble() * 1.1;
    const etiqueta = TextStyle(fontSize: 10, color: BanorteColors.content2);
    String corto(double v) =>
        v >= 1e6 ? '${(v / 1e6).toStringAsFixed(1)}M' : (v >= 1e3 ? '${(v / 1e3).round()}k' : '${v.round()}');
    const sinTitulos = AxisTitles(sideTitles: SideTitles(showTitles: false));

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        minX: 0,
        maxX: (serie.length - 1).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: BanorteColors.background2, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: sinTitulos,
          rightTitles: sinTitulos,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (v, _) => Text(corto(v), style: etiqueta),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: math.max(1, (serie.length / 4).ceilToDouble()),
              getTitlesWidget: (v, _) => Text('${v.toInt()}m', style: etiqueta),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: monto,
              color: BanorteColors.content4,
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style: const TextStyle(fontSize: 10, color: BanorteColors.content3),
                labelResolver: (_) => 'Capital',
              ),
            ),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (final (i, y) in serie.indexed) FlSpot(i.toDouble(), y.toDouble())],
            isCurved: true,
            color: green,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: green.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ResumenInversionGuardada
// ─────────────────────────────────────────────────────────────────────────────

class ResumenInversionGuardada extends StatelessWidget {
  const ResumenInversionGuardada({super.key, required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final p = props;
    final t = Theme.of(context).textTheme;
    const claro = TextStyle(color: Color(0xB3FFFFFF), fontSize: 14);
    const fuerte = TextStyle(fontFamily: gotham, color: BanorteColors.white, fontSize: 16, fontWeight: FontWeight.w500);
    final rendPct = (p['rendimiento_porcentual'] as num?)?.toDouble() ?? 0;
    final signo = rendPct >= 0 ? '+' : '';

    Widget fila(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Text(k, style: claro), const Spacer(), Text(v, style: fuerte)]),
        );

    return BanorteCard(
      color: const Color(0xFF1B4332), // Verde muy oscuro
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                child: const Icon(Icons.trending_up_rounded, color: BanorteColors.white),
              ),
              const Spacer(),
              Pill('Inversión #${p['investment_id']}', color: const Color(0x26FFFFFF), textColor: BanorteColors.white),
            ],
          ),
          const SizedBox(height: 20),
          Text('Inversión guardada', style: t.headlineMedium?.copyWith(color: BanorteColors.white)),
          const SizedBox(height: 4),
          Text('Perfil: ${_capital(p['perfil_riesgo'] as String? ?? '')}', style: claro),
          const SizedBox(height: 16),
          fila('Capital inicial', mxn((p['monto_inversion'] as num?) ?? 0)),
          fila('Aportación mensual', mxn((p['aportacion_mensual'] as num?) ?? 0)),
          fila('Plazo', '${(p['plazo_meses'] as num?)?.toInt() ?? 0} meses'),
          fila('Monto final proyectado', mxn((p['monto_final_proyectado'] as num?) ?? 0)),
          fila('Rendimiento', '$signo${rendPct.toStringAsFixed(1)}%'),
          const SizedBox(height: 8),
          const Text('Tu plan de inversión ha sido guardado en tu Dashboard.', style: claro),
        ],
      ),
    );
  }
}
