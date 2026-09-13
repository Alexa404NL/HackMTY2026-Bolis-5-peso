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
