/// Modelo local del Dashboard y sus widgets.
///
/// Representa el estado persistido via MCP (save_dashboard_config / get_dashboard_config).
/// El cliente trabaja con este modelo; el servidor es la fuente de verdad.
library;

enum ModuleType { savingsGoal, budget, investment }

enum DisplayMode { compactSummary, chartPreview, progressTracker }

enum StatusColor { green, yellow, red }

/// Convierte el string del servidor al enum.
ModuleType moduleTypeFrom(String s) => switch (s) {
      'savings_goal' => ModuleType.savingsGoal,
      'budget' => ModuleType.budget,
      'investment' => ModuleType.investment,
      _ => ModuleType.savingsGoal,
    };

DisplayMode displayModeFrom(String s) => switch (s) {
      'chart_preview' => DisplayMode.chartPreview,
      'progress_tracker' => DisplayMode.progressTracker,
      _ => DisplayMode.compactSummary,
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
        'status_color': switch (statusColor) {
          StatusColor.green => 'green',
          StatusColor.yellow => 'yellow',
          StatusColor.red => 'red',
        },
      };
}

class WidgetInstance {
  WidgetInstance({
    required this.id,
    required this.moduleType,
    required this.title,
    required this.order,
    required this.displayMode,
    required this.moduleDataId,
    required this.summary,
  });

  final String id;
  final ModuleType moduleType;
  final String title;
  int order;
  final DisplayMode displayMode;
  final int? moduleDataId;
  final WidgetSummary summary;

  factory WidgetInstance.fromJson(Map<String, dynamic> j) => WidgetInstance(
        id: j['id'] as String,
        moduleType: moduleTypeFrom(j['module_type'] as String? ?? 'savings_goal'),
        title: j['title'] as String? ?? '',
        order: (j['order'] as num?)?.toInt() ?? 0,
        displayMode: displayModeFrom(j['display_mode'] as String? ?? 'compact_summary'),
        moduleDataId: (j['module_data_id'] as num?)?.toInt(),
        summary: WidgetSummary.fromJson((j['summary'] as Map<String, dynamic>?) ?? {}),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'module_type': switch (moduleType) {
          ModuleType.savingsGoal => 'savings_goal',
          ModuleType.budget => 'budget',
          ModuleType.investment => 'investment',
        },
        'title': title,
        'order': order,
        'display_mode': switch (displayMode) {
          DisplayMode.compactSummary => 'compact_summary',
          DisplayMode.chartPreview => 'chart_preview',
          DisplayMode.progressTracker => 'progress_tracker',
        },
        'module_data_id': moduleDataId,
        'summary': summary.toJson(),
      };
}
