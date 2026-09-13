import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/dashboard_model.dart';
import '../theme.dart';

const _verde = Color(0xFF4CAF50);
const _paleta = [
  BanorteColors.red,
  Color(0xB3EB0029),
  Color(0x73EB0029),
  BanorteColors.darkGray,
  BanorteColors.gray,
  BanorteColors.content4,
];

/// Card compacta del Dashboard (grid de 8 columnas: el cuadrado mide ~80 px).
/// Solo número principal + una visual; el detalle completo se abre al tocar el widget.
Widget buildWidgetCard(WidgetInstance w) {
  final p = _P(w);
  return switch (w.moduleType) {
    ModuleType.savingsGoal => _Meta(p),
    ModuleType.budget => _Presupuesto(p),
    ModuleType.investment => _Inversion(p),
  };
}

/// Lectura tolerante del preview; sin preview cae al `summary` del widget.
class _P {
  _P(this.w) : m = w.preview ?? const {};
  final WidgetInstance w;
  final Map<String, dynamic> m;

  String get valor => ((m['kpi'] as Map?)?['valor'] as String?) ?? w.summary.primaryMetric;
  String get tono => m['tono'] as String? ?? w.summary.statusColor.name;
  double get progreso => ((m['progreso'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
  double get proyectado => ((m['progreso_proyectado'] as num?) ?? progreso).toDouble().clamp(0.0, 1.0);
  String get pct => '${(progreso * 100).round()}%';
  List<double> get serie =>
      [for (final v in ((m['serie'] as Map?)?['valores'] as List?) ?? const []) (v as num).toDouble()];

  String? s(String k) => m[k] as String?;
  num? n(String k) => m[k] as num?;
  List<Map> lista(String k) => ((m[k] as List?) ?? const []).cast<Map>();
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta de ahorro
// ─────────────────────────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  const _Meta(this.p);
  final _P p;

  @override
  Widget build(BuildContext context) {
    const c = BanorteColors.red;
    final serie = p.serie;
    return switch (p.w.shape) {
      // $ahorrado + barra de progreso.
      WidgetShape.square => _DashboardCard(
          color: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.savings_rounded, size: 14, color: Colors.white70),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Metric(p.valor, Colors.white, size: 18),
                  const SizedBox(height: 5),
                  _Barra(p.progreso, Colors.white, height: 5, pista: Colors.white24),
                ],
              ),
            ],
          ),
        ),
      // $ahorrado · % a la izquierda; proyección con línea de meta a la derecha.
      WidgetShape.wide => _DashboardCard(
          child: Row(children: [
            Expanded(flex: 4, child: _Numero(p.valor, p.pct, BanorteColors.darkGray)),
            const SizedBox(width: 8),
            Expanded(
              flex: 5,
              child: serie.length > 1
                  ? _Area(serie, c, meta: p.n('meta_valor')?.toDouble())
                  : Center(child: _Barra(p.progreso, c)),
            ),
          ]),
        ),
      // $ahorrado + anillo doble (hoy / proyectado).
      WidgetShape.tall => _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(p.valor, BanorteColors.darkGray, size: 16),
              const SizedBox(height: 6),
              Expanded(
                child: _AnilloDoble(
                  p.progreso,
                  p.proyectado,
                  c,
                  centro: Text(p.pct,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontSize: 12, color: BanorteColors.darkGray)),
                ),
              ),
            ],
          ),
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Presupuesto
// ─────────────────────────────────────────────────────────────────────────────

class _Presupuesto extends StatelessWidget {
  const _Presupuesto(this.p);
  final _P p;

  @override
  Widget build(BuildContext context) {
    final c = _colorTono(p.tono);
    final desglose = p.lista('desglose');
    return switch (p.w.shape) {
      // Gauge chico del % gastado.
      WidgetShape.square => _DashboardCard(
          color: BanorteColors.darkGray,
          child: Column(children: [
            Row(children: [
              const Icon(Icons.account_balance_wallet_rounded, size: 14, color: Colors.white70),
              const Spacer(),
              _StatusDot(color: c),
            ]),
            Expanded(child: _Gauge(p.progreso, Colors.white, Colors.white24, valor: p.pct, texto: Colors.white)),
          ]),
        ),
      // Balance a la izquierda; mini dona de categorías a la derecha.
      WidgetShape.wide => _DashboardCard(
          child: Row(children: [
            Expanded(flex: 5, child: _Numero(p.valor, '${p.pct} gastado', BanorteColors.darkGray)),
            if (desglose.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(flex: 4, child: _Dona(desglose, centro: p.pct)),
            ],
          ]),
        ),
      // Balance + barras de las 4 categorías principales.
      WidgetShape.tall => _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(p.valor, BanorteColors.darkGray, size: 16),
              const SizedBox(height: 6),
              Expanded(child: desglose.isEmpty ? const SizedBox.shrink() : _Barras(desglose.take(4).toList(), c)),
            ],
          ),
        ),
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inversión
// ─────────────────────────────────────────────────────────────────────────────

class _Inversion extends StatelessWidget {
  const _Inversion(this.p);
  final _P p;

  @override
  Widget build(BuildContext context) {
    const c = _verde;
    final serie = p.serie;
    final instrumentos = p.lista('instrumentos');
    return switch (p.w.shape) {
      // Rendimiento + sparkline.
      WidgetShape.square => _DashboardCard(
          color: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(p.valor, Colors.white, size: 18),
              const SizedBox(height: 4),
              Expanded(child: serie.length > 1 ? _Area(serie, Colors.white, relleno: false) : const SizedBox.shrink()),
            ],
          ),
        ),
      // Monto final y rendimiento a la izquierda; instrumentos a la derecha.
      WidgetShape.wide => _DashboardCard(
          child: Row(children: [
            Expanded(flex: 4, child: _Numero(p.s('total') ?? p.valor, p.valor, BanorteColors.darkGray, subColor: c)),
            if (instrumentos.isNotEmpty) ...[
              const SizedBox(width: 8),
              Expanded(flex: 5, child: _Instrumentos(instrumentos, c)),
            ],
          ]),
        ),
      // Rendimiento + área de crecimiento.
      WidgetShape.tall => _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(p.valor, BanorteColors.darkGray, size: 16),
              const SizedBox(height: 6),
              Expanded(child: serie.length > 1 ? _Area(serie, c) : const SizedBox.shrink()),
            ],
          ),
        ),
    };
  }
}

Color _colorTono(String tono) => switch (tono) {
      'yellow' => BanorteColors.warning,
      'red' => BanorteColors.red,
      _ => _verde,
    };

// ─────────────────────────────────────────────────────────────────────────────
// Piezas reutilizables
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({required this.child, this.color = BanorteColors.white});
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x10323E48), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      );
}

/// Número principal con una línea corta debajo.
class _Numero extends StatelessWidget {
  const _Numero(this.valor, this.sub, this.color, {this.subColor = BanorteColors.content2});
  final String valor;
  final String sub;
  final Color color;
  final Color subColor;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Metric(valor, color, size: 18),
          const SizedBox(height: 2),
          Text(sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: subColor)),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.text, this.color, {this.size = 18});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: size, color: color)),
      );
}

class _Barra extends StatelessWidget {
  const _Barra(this.value, this.color, {this.height = 6, this.pista = BanorteColors.background2});
  final num value;
  final Color color;
  final double height;
  final Color pista;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value.clamp(0, 1).toDouble(),
          minHeight: height,
          color: color,
          backgroundColor: pista,
        ),
      );
}

/// Anillo doble: capa clara = proyectado, capa sólida = hoy.
class _AnilloDoble extends StatelessWidget {
  const _AnilloDoble(this.hoy, this.proyectado, this.color, {required this.centro});
  final double hoy;
  final double proyectado;
  final Color color;
  final Widget centro;
  static const _grosor = 8.0;

  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: 1,
          child: Padding(
            padding: const EdgeInsets.all(_grosor / 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: max(proyectado, hoy),
                  strokeWidth: _grosor,
                  strokeCap: StrokeCap.round,
                  color: color.withValues(alpha: 0.3),
                  backgroundColor: BanorteColors.background2,
                ),
                CircularProgressIndicator(
                  value: hoy,
                  strokeWidth: _grosor,
                  strokeCap: StrokeCap.round,
                  color: color,
                  backgroundColor: Colors.transparent,
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(_grosor + 2),
                    child: FittedBox(fit: BoxFit.scaleDown, child: centro),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Gauge semicircular con el valor dentro del arco.
class _Gauge extends StatelessWidget {
  const _Gauge(this.value, this.color, this.pista, {required this.valor, this.texto = BanorteColors.darkGray});
  final double value;
  final Color color;
  final Color pista;
  final String valor;
  final Color texto;

  @override
  Widget build(BuildContext context) => Center(
        child: AspectRatio(
          aspectRatio: 2,
          child: CustomPaint(
            painter: _ArcoPainter(value, color, pista),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valor,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(fontSize: 14, color: texto)),
              ),
            ),
          ),
        ),
      );
}

class _ArcoPainter extends CustomPainter {
  _ArcoPainter(this.value, this.color, this.pista);
  final double value;
  final Color color;
  final Color pista;

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.height * 0.18;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height - grosor / 2),
      radius: min(size.width / 2 - grosor / 2, size.height - grosor),
    );
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, pi, pi, false, pincel..color = pista);
    if (value > 0) canvas.drawArc(rect, pi, pi * value.clamp(0.0, 1.0), false, pincel..color = color);
  }

  @override
  bool shouldRepaint(_ArcoPainter old) => old.value != value || old.color != color || old.pista != pista;
}

/// Dona de categorías (escalada a la suma) con texto al centro.
class _Dona extends StatelessWidget {
  const _Dona(this.items, {required this.centro});
  final List<Map> items;
  final String centro;

  @override
  Widget build(BuildContext context) {
    final valores = [for (final e in items) max(0.0, (e['pct'] as num? ?? 0).toDouble())];
    final total = valores.fold<double>(0, (a, b) => a + b);
    return LayoutBuilder(builder: (context, box) {
      final d = min(box.maxWidth, box.maxHeight);
      return Center(
        child: SizedBox.square(
          dimension: d,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 1,
                  centerSpaceRadius: d * 0.3,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (var i = 0; i < valores.length; i++)
                      PieChartSectionData(
                        // Mínimo visible por categoría para que los datos extremos no desaparezcan.
                        value: total > 0 ? max(valores[i], total * 0.02) : 1,
                        color: _paleta[i % _paleta.length],
                        radius: d * 0.18,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: d * 0.45,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(centro,
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontSize: 16, color: BanorteColors.darkGray)),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// Instrumentos del portafolio en versión compacta: nombre, % y barra.
class _Instrumentos extends StatelessWidget {
  const _Instrumentos(this.items, this.color);
  final List<Map> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(fontSize: 9, color: BanorteColors.content2);
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final e in items.take(3))
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(e['nombre'] as String? ?? '', style: s, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(e['texto'] as String? ?? '',
                    style: s.copyWith(color: BanorteColors.darkGray, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 2),
              _Barra(e['pct'] as num? ?? 0, color, height: 4),
            ],
          ),
      ],
    );
  }
}

/// Barras verticales por categoría, escaladas a la categoría más alta, con pista de fondo.
class _Barras extends StatelessWidget {
  const _Barras(this.items, this.color);
  final List<Map> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxPct = items.fold<double>(0, (m, e) => max(m, (e['pct'] as num? ?? 0).toDouble()));
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 1,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: maxPct > 0 ? max(0.04, (items[i]['pct'] as num? ?? 0) / maxPct) : 0.04,
                color: color,
                width: 8,
                borderRadius: BorderRadius.circular(4),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: BanorteColors.background2),
              ),
            ]),
        ],
      ),
    );
  }
}

/// Área con gradiente y punto resaltado: el final, o donde la serie alcanza [meta] (con línea punteada).
class _Area extends StatelessWidget {
  const _Area(this.serie, this.color, {this.relleno = true, this.meta});
  final List<double> serie;
  final Color color;
  final bool relleno;
  final double? meta;

  @override
  Widget build(BuildContext context) {
    final ultimo = serie.length - 1;
    final lo = serie.reduce(min), hi = max(serie.reduce(max), meta ?? double.negativeInfinity);
    // Serie plana (datos extremos): margen artificial para que no colapse.
    final rango = hi > lo ? hi - lo : max(hi.abs() * 0.1, 1.0);
    final punto = meta == null ? ultimo : serie.indexWhere((v) => v >= meta!);
    return LineChart(
      LineChartData(
        minY: lo - rango * 0.05,
        maxY: hi + rango * 0.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: const FlTitlesData(show: false),
        extraLinesData: ExtraLinesData(horizontalLines: [
          if (meta != null)
            HorizontalLine(y: meta!, color: BanorteColors.content3, strokeWidth: 1, dashArray: const [3, 3]),
        ]),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < serie.length; i++) FlSpot(i.toDouble(), serie[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(
              checkToShowDot: (spot, _) => spot.x == punto,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 2.5, color: color, strokeWidth: 1.5, strokeColor: Colors.white),
            ),
            belowBarData: BarAreaData(
              show: relleno,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
