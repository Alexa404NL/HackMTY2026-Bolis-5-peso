/// Modelo local del Dashboard y sus widgets.
///
/// Representa el estado persistido via MCP (save_dashboard_config / get_dashboard_config).
/// El cliente trabaja con este modelo; el servidor es la fuente de verdad.
library;

import 'dart:math';

enum ModuleType { savingsGoal, budget, investment }

enum StatusColor { green, yellow, red }

/// Forma del widget en el grid de [gridCols] columnas (ancho x alto en celdas).
enum WidgetShape {
  square(2, 2),
  wide(4, 2),
  tall(2, 4);

  const WidgetShape(this.w, this.h);
  final int w, h;
}

const gridCols = 8;

/// Convierte el string del servidor al enum.
ModuleType moduleTypeFrom(String s) => switch (s) {
      'savings_goal' => ModuleType.savingsGoal,
      'budget' => ModuleType.budget,
      'investment' => ModuleType.investment,
      _ => ModuleType.savingsGoal,
    };

StatusColor statusColorFrom(String s) => switch (s) {
      'green' => StatusColor.green,
      'yellow' => StatusColor.yellow,
      'red' => StatusColor.red,
      _ => StatusColor.green,
    };

class WidgetSummary {
  const WidgetSummary({
    required this.primaryMetric,
    required this.secondaryMetric,
    required this.statusColor,
  });

  final String primaryMetric;
  final String secondaryMetric;
  final StatusColor statusColor;

  factory WidgetSummary.fromJson(Map<String, dynamic> j) => WidgetSummary(
        primaryMetric: j['primary_metric'] as String? ?? '',
        secondaryMetric: j['secondary_metric'] as String? ?? '',
        statusColor: statusColorFrom(j['status_color'] as String? ?? 'green'),
      );

  Map<String, dynamic> toJson() => {
        'primary_metric': primaryMetric,
        'secondary_metric': secondaryMetric,
        'status_color': statusColor.name,
      };
}

class WidgetInstance {
  WidgetInstance({
    required this.id,
    required this.moduleType,
    required this.title,
    required this.order,
    required this.moduleDataId,
    required this.summary,
    this.x = -1,
    this.y = -1,
    this.shape = WidgetShape.wide,
    this.preview,
  });

  final String id;
  final ModuleType moduleType;
  final String title;
  int order;
  final int? moduleDataId;
  final WidgetSummary summary;

  /// Celda superior izquierda; -1 = sin colocar (widget legacy).
  int x, y;
  WidgetShape shape;

  /// Datos listos para mostrar que manda el servidor ({kpi, tono, progreso, detalle, serie,
  /// desglose, filas}). null = sin datos del módulo → la card usa [summary].
  final Map<String, dynamic>? preview;

  factory WidgetInstance.fromJson(Map<String, dynamic> j) {
    // Layouts guardados con el grid anterior de 4 columnas: se duplica la posición para conservar el acomodo.
    final escala = ((j['cols'] as num?)?.toInt() ?? 4) < gridCols ? 2 : 1;
    final x = (j['x'] as num?)?.toInt() ?? -1;
    final y = (j['y'] as num?)?.toInt() ?? -1;
    return WidgetInstance(
      id: j['id'] as String,
      moduleType: moduleTypeFrom(j['module_type'] as String? ?? 'savings_goal'),
      title: j['title'] as String? ?? '',
      order: (j['order'] as num?)?.toInt() ?? 0,
      moduleDataId: (j['module_data_id'] as num?)?.toInt(),
      summary: WidgetSummary.fromJson((j['summary'] as Map<String, dynamic>?) ?? {}),
      x: x < 0 ? -1 : x * escala,
      y: y < 0 ? -1 : y * escala,
      shape: WidgetShape.values.asNameMap()[j['shape']] ?? WidgetShape.wide,
      preview: j['preview'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_type': switch (moduleType) {
          ModuleType.savingsGoal => 'savings_goal',
          ModuleType.budget => 'budget',
          ModuleType.investment => 'investment',
        },
        'title': title,
        'order': order,
        'module_data_id': moduleDataId,
        'summary': summary.toJson(),
        'x': x,
        'y': y,
        'shape': shape.name,
        'cols': gridCols,
        'preview': preview,
      };
}

// ─── Lógica del grid (pura, sin Flutter) ─────────────────────────────────────

bool _solapa(int ax, int ay, WidgetShape a, int bx, int by, WidgetShape b) =>
    ax < bx + b.w && bx < ax + a.w && ay < by + b.h && by < ay + a.h;

/// ¿Cabe [s] en (x, y) sin salirse de columnas ni solapar otros widgets colocados?
bool cabe(List<WidgetInstance> ws, int x, int y, WidgetShape s,
        {Set<WidgetInstance> ignorar = const {}}) =>
    x >= 0 &&
    y >= 0 &&
    x + s.w <= gridCols &&
    ws.every((o) => ignorar.contains(o) || o.x < 0 || !_solapa(x, y, s, o.x, o.y, o.shape));

/// Primer hueco (arriba-izquierda) donde cabe [s].
(int, int) primerHueco(List<WidgetInstance> ws, WidgetShape s,
    {Set<WidgetInstance> ignorar = const {}}) {
  for (var y = 0;; y++) {
    for (var x = 0; x + s.w <= gridCols; x++) {
      if (cabe(ws, x, y, s, ignorar: ignorar)) return (x, y);
    }
  }
}

/// Mueve [w] a (x, y). Si el destino lo ocupa exactamente un widget que cabe en el
/// origen de [w], se intercambian. Si no, no cambia nada (rebota) y regresa false.
bool mover(List<WidgetInstance> ws, WidgetInstance w, int x, int y) {
  x = x.clamp(0, gridCols - w.shape.w);
  y = max(0, y);
  if (x == w.x && y == w.y) return false;
  if (cabe(ws, x, y, w.shape, ignorar: {w})) {
    w
      ..x = x
      ..y = y;
    return true;
  }
  final choques =
      ws.where((o) => o != w && o.x >= 0 && _solapa(x, y, w.shape, o.x, o.y, o.shape)).toList();
  if (choques.length != 1) return false;
  final o = choques.single;
  final (ox, oy) = (w.x, w.y);
  if (!cabe(ws, ox, oy, o.shape, ignorar: {w, o}) || _solapa(x, y, w.shape, ox, oy, o.shape)) {
    return false;
  }
  w
    ..x = x
    ..y = y;
  o
    ..x = ox
    ..y = oy;
  return true;
}

/// Cambia la forma de [w]: crece en su lugar si cabe, si no se reubica al primer hueco.
void cambiarForma(List<WidgetInstance> ws, WidgetInstance w, WidgetShape s) {
  final x = min(max(w.x, 0), gridCols - s.w);
  if (w.x >= 0 && cabe(ws, x, w.y, s, ignorar: {w})) {
    w.x = x;
  } else {
    final (hx, hy) = primerHueco(ws, s, ignorar: {w});
    w
      ..x = hx
      ..y = hy;
  }
  w.shape = s;
}

/// Coloca los widgets sin posición (guardados antes del grid) en orden, como [WidgetShape.wide].
void colocarLegacy(List<WidgetInstance> ws) {
  for (final w in [...ws]..sort((a, b) => a.order.compareTo(b.order))) {
    if (w.x >= 0) continue;
    w.shape = WidgetShape.wide;
    final (hx, hy) = primerHueco(ws, w.shape);
    w
      ..x = hx
      ..y = hy;
  }
}

/// Filas ocupadas por el layout.
int filasOcupadas(List<WidgetInstance> ws) =>
    ws.fold(0, (m, w) => max(m, w.y + w.shape.h));
