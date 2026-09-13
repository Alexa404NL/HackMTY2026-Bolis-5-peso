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

/// Card del Dashboard. Pinta el `preview` que manda el servidor (ya formateado),
/// con un layout propio por módulo × forma.
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

  Map get _kpi => (m['kpi'] as Map?) ?? const {};
  String get valor => _kpi['valor'] as String? ?? w.summary.primaryMetric;
  String get etiqueta => _kpi['etiqueta'] as String? ?? '';
  String get detalle => m['detalle'] as String? ?? w.summary.secondaryMetric;
  String get tono => m['tono'] as String? ?? w.summary.statusColor.name;
  double get progreso => ((m['progreso'] as num?) ?? 0).toDouble().clamp(0.0, 1.0);
  double get proyectado => ((m['progreso_proyectado'] as num?) ?? progreso).toDouble().clamp(0.0, 1.0);
  String get pct => '${(progreso * 100).round()}%';
  List<double> get serie =>
      [for (final v in ((m['serie'] as Map?)?['valores'] as List?) ?? const []) (v as num).toDouble()];
  List<String> get etiquetasSerie =>
      [for (final e in ((m['serie'] as Map?)?['etiquetas'] as List?) ?? const []) e as String];

  String? s(String k) => m[k] as String?;
  List<Map> lista(String k) => ((m[k] as List?) ?? const []).cast<Map>();

  Widget? chip({bool sobreColor = false}) {
    final c = m['chip'] as Map?;
    return c == null ? null : _Chip(c['texto'] as String? ?? '', c['tono'] as String? ?? 'green', sobreColor: sobreColor);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Meta de ahorro — dato principal: ahorrado hoy
// ─────────────────────────────────────────────────────────────────────────────

class _Meta extends StatelessWidget {
  const _Meta(this.p);
  final _P p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const c = BanorteColors.red;
    final meta = p.s('meta_texto');

    switch (p.w.shape) {
      // Estilo "Dream Laptop": $hoy / $meta, nombre, % completado y barra.
      case WidgetShape.square:
        return _DashboardCard(
          color: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Metric(p.valor, Colors.white, size: 30),
              if (meta != null)
                Text('/ $meta', style: const TextStyle(fontFamily: gotham, fontSize: 15, color: Colors.white60)),
              const Spacer(),
              Text(p.w.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontFamily: gotham, fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              Text('${p.pct} completado', style: const TextStyle(fontSize: 12, color: Colors.white70)),
              const SizedBox(height: 8),
              _Barra(p.progreso, Colors.white, height: 8, pista: Colors.white24),
            ],
          ),
        );

      // Barra de dinero: sólido = hoy, claro = proyectado, ▲ en la meta.
      case WidgetShape.wide:
        final proyectado = p.s('proyectado_texto');
        return _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Expanded(child: _Caps(p.w.title)), ?p.chip()]),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(child: _Metric(p.valor, BanorteColors.darkGray, size: 28)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(meta == null ? p.detalle : 'de $meta · ${p.pct}',
                          style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _BarraMeta(p.progreso, p.proyectado, c),
              const SizedBox(height: 6),
              Row(children: [
                Flexible(child: _Leyenda(c, 'Hoy ${p.valor}')),
                const SizedBox(width: 10),
                if (proyectado != null) Flexible(child: _Leyenda(c.withValues(alpha: 0.3), 'Proyectado $proyectado')),
                const Spacer(),
                if (meta != null) ...[
                  const Icon(Icons.flag_rounded, size: 13, color: BanorteColors.darkGray),
                  const SizedBox(width: 2),
                  Text(meta,
                      style: t.bodySmall
                          ?.copyWith(fontSize: 11, color: BanorteColors.darkGray, fontWeight: FontWeight.w600)),
                ],
              ]),
            ],
          ),
        );

      // Anillo doble (hoy sólido sobre proyectado claro) + filas.
      case WidgetShape.tall:
        return _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Caps(p.w.title),
              const SizedBox(height: 8),
              _Metric(p.valor, BanorteColors.darkGray, size: 34),
              if (meta != null) Text('de $meta', style: t.bodySmall),
              const SizedBox(height: 8),
              Expanded(
                child: _AnilloDoble(
                  p.progreso,
                  p.proyectado,
                  c,
                  centro: Text(p.pct, style: t.displaySmall?.copyWith(fontSize: 24, color: BanorteColors.darkGray)),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 10, runSpacing: 2, children: [
                const _Leyenda(c, 'Hoy'),
                _Leyenda(c.withValues(alpha: 0.3), 'Proyectado ${(p.proyectado * 100).round()}%'),
              ]),
              const SizedBox(height: 6),
              for (final f in p.lista('filas').take(2)) _Fila(f['etiqueta'] as String, f['texto'] as String),
            ],
          ),
        );
    }
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
    final t = Theme.of(context).textTheme;
    final c = _colorTono(p.tono);
    final desglose = p.lista('desglose');

    switch (p.w.shape) {
      // Disponible + chip de estado + mini barras de las categorías principales.
      case WidgetShape.square:
        return _DashboardCard(
          color: BanorteColors.darkGray,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: _Caps('Disponible', color: Colors.white60)),
                _StatusDot(color: c),
              ]),
              const SizedBox(height: 6),
              _Metric(p.valor, Colors.white, size: 28),
              ?p.chip(sobreColor: true),
              const Spacer(),
              if (desglose.isNotEmpty) _MiniBarras(desglose.take(4).toList(), Colors.white),
            ],
          ),
        );

      // Balance a la izquierda; dona de las 6 categorías con % gastado a la derecha.
      case WidgetShape.wide:
        final gastos = p.s('gastos_texto');
        return _DashboardCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Flexible(child: _Caps('Presupuesto')),
                      const SizedBox(width: 6),
                      _StatusDot(color: c),
                    ]),
                    const SizedBox(height: 6),
                    _Metric(p.valor, BanorteColors.darkGray, size: 28),
                    ?p.chip(),
                    const Spacer(),
                    Text(gastos != null ? 'Gastas $gastos' : p.detalle,
                        style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (desglose.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _Dona(desglose, centro: p.pct)),
                      const SizedBox(height: 4),
                      for (final (i, e) in desglose.take(2).indexed)
                        _Leyenda(_paleta[i], '${e['corto'] ?? ''} ${e['texto'] ?? ''}'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );

      // Aprobado: número + chip + barras por categoría + filas.
      case WidgetShape.tall:
        return _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [const Expanded(child: _Caps('Presupuesto')), _StatusDot(color: c)]),
              const SizedBox(height: 10),
              _Metric(p.valor, BanorteColors.darkGray, size: 34),
              Text(p.etiqueta, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              ?p.chip(),
              const SizedBox(height: 12),
              Expanded(
                child: desglose.isEmpty
                    ? Align(alignment: Alignment.topLeft, child: Text(p.detalle, style: t.bodySmall, maxLines: 3))
                    : _Barras(desglose.take(4).toList(), c),
              ),
              const SizedBox(height: 10),
              for (final f in p.lista('filas').take(2)) _Fila(f['etiqueta'] as String, f['texto'] as String),
            ],
          ),
        );
    }
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
    final t = Theme.of(context).textTheme;
    const c = _verde;
    final serie = p.serie;

    switch (p.w.shape) {
      // % de rendimiento + monto final + sparkline a todo el ancho.
      case WidgetShape.square:
        return _DashboardCard(
          color: c,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Caps('Inversión', color: Colors.white70),
              const SizedBox(height: 4),
              _Metric(p.valor, Colors.white, size: 30),
              Text(p.detalle,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Expanded(
                child: serie.length > 1
                    ? _Area(serie, const [], Colors.white, ejes: false, relleno: false)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );

      // Monto final + chip a la izquierda; instrumentos del portafolio a la derecha.
      case WidgetShape.wide:
        final instrumentos = p.lista('instrumentos');
        final aportado = p.lista('filas').firstOrNull;
        return _DashboardCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Caps('Inversión'),
                    const SizedBox(height: 6),
                    _Metric(p.s('total') ?? p.valor, BanorteColors.darkGray, size: 28),
                    _Chip(p.valor, p.tono),
                    const Spacer(),
                    if (aportado != null)
                      Text('${aportado['etiqueta']} ${aportado['texto']}',
                          style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (instrumentos.isNotEmpty) ...[
                const SizedBox(width: 12),
                Expanded(flex: 5, child: _Instrumentos(instrumentos, c)),
              ],
            ],
          ),
        );

      // Aprobado: número + chip + área con meses + filas.
      case WidgetShape.tall:
        return _DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Caps('Inversión'),
              const SizedBox(height: 10),
              _Metric(p.valor, BanorteColors.darkGray, size: 34),
              Text(p.etiqueta, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              ?p.chip(),
              const SizedBox(height: 12),
              Expanded(
                child: serie.length > 1
                    ? _Area(serie, p.etiquetasSerie, c)
                    : Align(alignment: Alignment.topLeft, child: Text(p.detalle, style: t.bodySmall, maxLines: 3)),
              ),
              const SizedBox(height: 10),
              for (final f in p.lista('filas').take(2)) _Fila(f['etiqueta'] as String, f['texto'] as String),
            ],
          ),
        );
    }
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Color(0x10323E48), blurRadius: 20, offset: Offset(0, 8))],
        ),
        child: child,
      );
}

/// Encabezado en mayúsculas estilo "USERS".
class _Caps extends StatelessWidget {
  const _Caps(this.text, {this.color = BanorteColors.content2});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600, color: color));
}

class _Chip extends StatelessWidget {
  const _Chip(this.texto, this.tono, {this.sobreColor = false});
  final String texto;
  final String tono;
  final bool sobreColor;

  @override
  Widget build(BuildContext context) {
    final c = _colorTono(tono);
    final fg = sobreColor ? Colors.white : c;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sobreColor ? Colors.white.withValues(alpha: 0.22) : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            switch (tono) {
              'green' => Icons.north_east_rounded,
              'red' => Icons.south_east_rounded,
              _ => Icons.east_rounded,
            },
            size: 12,
            color: fg,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda(this.color, this.texto);
  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
          ),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.text, this.color, {this.size = 24});
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
  const _Barra(this.value, this.color, {this.height = 8, this.pista = BanorteColors.background2});
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

/// Barra de dinero de la meta: pista, proyectado (claro) y ahorrado hoy (sólido).
class _BarraMeta extends StatelessWidget {
  const _BarraMeta(this.hoy, this.proyectado, this.color);
  final double hoy;
  final double proyectado;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth;
          Widget capa(double f, Color c) => Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: w * f,
                child: DecoratedBox(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99))),
              );
          return Stack(children: [
            capa(1, BanorteColors.background2),
            capa(max(proyectado, hoy), color.withValues(alpha: 0.3)),
            capa(hoy > 0 ? min(1.0, max(hoy, 14 / w)) : 0, color),
          ]);
        }),
      );
}

/// Anillo doble: capa clara = proyectado, capa sólida = hoy.
class _AnilloDoble extends StatelessWidget {
  const _AnilloDoble(this.hoy, this.proyectado, this.color, {required this.centro});
  final double hoy;
  final double proyectado;
  final Color color;
  final Widget centro;
  static const _grosor = 16.0;

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
                  sectionsSpace: 1.5,
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

/// 4 barras simples para el cuadrado de presupuesto, relativas a la mayor.
class _MiniBarras extends StatelessWidget {
  const _MiniBarras(this.items, this.color);
  final List<Map> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxPct = items.fold<double>(0, (m, e) => max(m, (e['pct'] as num? ?? 0).toDouble()));
    return SizedBox(
      height: 58,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final e in items)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: maxPct > 0 ? max(0.08, (e['pct'] as num? ?? 0) / maxPct) : 0.08,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(((e['corto'] as String?) ?? '').toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(fontSize: 9, letterSpacing: 0.4, color: color.withValues(alpha: 0.7))),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Instrumentos del portafolio: nombre, % y barra.
class _Instrumentos extends StatelessWidget {
  const _Instrumentos(this.items, this.color);
  final List<Map> items;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11);
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
                    style: s?.copyWith(color: BanorteColors.darkGray, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 3),
              _Barra(e['pct'] as num? ?? 0, color, height: 6),
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
    const estilo = TextStyle(fontSize: 10, letterSpacing: 0.5, color: BanorteColors.content3);
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 1,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (v, meta) => SideTitleWidget(
                meta: meta,
                child: Text(((items[v.toInt()]['corto'] as String?) ?? '').toUpperCase(), style: estilo),
              ),
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < items.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: maxPct > 0 ? max(0.04, (items[i]['pct'] as num? ?? 0) / maxPct) : 0.04,
                color: color,
                width: 12,
                borderRadius: BorderRadius.circular(6),
                backDrawRodData: BackgroundBarChartRodData(show: true, toY: 1, color: BanorteColors.background2),
              ),
            ]),
        ],
      ),
    );
  }
}

/// Área con gradiente, punto final resaltado y etiquetas de mes (primero / medio / último).
class _Area extends StatelessWidget {
  const _Area(this.serie, this.etiquetas, this.color, {this.ejes = true, this.relleno = true});
  final List<double> serie;
  final List<String> etiquetas;
  final Color color;
  final bool ejes;
  final bool relleno;

  @override
  Widget build(BuildContext context) {
    final ultimo = serie.length - 1;
    final lo = serie.reduce(min), hi = serie.reduce(max);
    // Serie plana (datos extremos): margen artificial para que no colapse.
    final rango = hi > lo ? hi - lo : max(hi.abs() * 0.1, 1.0);
    const estilo = TextStyle(fontSize: 10, letterSpacing: 0.5, color: BanorteColors.content3);
    final marcas = {0, ultimo ~/ 2, ultimo};
    return LineChart(
      LineChartData(
        minY: lo - rango * 0.05,
        maxY: hi + rango * 0.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: ejes && etiquetas.length == serie.length,
              reservedSize: 20,
              interval: 1,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (v != i || !marcas.contains(i)) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                  child: Text(etiquetas[i].toUpperCase(), style: estilo),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < serie.length; i++) FlSpot(i.toDouble(), serie[i])],
            isCurved: true,
            preventCurveOverShooting: true,
            color: color,
            barWidth: relleno ? 2.5 : 2,
            dotData: FlDotData(
              checkToShowDot: (spot, _) => spot.x == ultimo,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 3.5, color: color, strokeWidth: 2, strokeColor: Colors.white),
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

class _Fila extends StatelessWidget {
  const _Fila(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: BanorteColors.background2))),
      child: Row(children: [
        Expanded(child: Text(label, style: s, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(value, style: s?.copyWith(color: BanorteColors.darkGray, fontWeight: FontWeight.w600)),
      ]),
    );
  }
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
