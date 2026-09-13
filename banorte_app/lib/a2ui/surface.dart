import 'package:flutter/material.dart';

import 'components.dart';

typedef SendTurn = Future<List<Map<String, dynamic>>> Function({String? texto, Map<String, dynamic>? action});

/// Superficie A2UI v0.9 (subset): componentes por id + data model.
/// El cliente no decide qué mostrar: solo pinta lo que el agente manda y regresa acciones.
class Surface extends ChangeNotifier {
  Surface(this._send);

  final SendTurn _send;
  String? surfaceId;
  final components = <String, Map<String, dynamic>>{};
  Map<String, dynamic> data = {};
  bool busy = false;
  String? error;

  bool get isEmpty => !components.containsKey('root');

  void apply(List<Map<String, dynamic>> messages) {
    for (final m in messages) {
      if (m['createSurface'] case final Map c) {
        surfaceId = c['surfaceId'] as String?;
        components.clear();
      } else if (m['updateComponents'] case final Map u) {
        for (final c in (u['components'] as List).cast<Map<String, dynamic>>()) {
          components[c['id'] as String] = c;
        }
      } else if (m['updateDataModel'] case final Map u) {
        final path = (u['path'] as String? ?? '/').split('/').where((s) => s.isNotEmpty).toList();
        if (path.isEmpty) {
          data = Map<String, dynamic>.from(u['value'] as Map);
        } else {
          var node = data;
          for (final k in path.take(path.length - 1)) {
            node = node.putIfAbsent(k, () => <String, dynamic>{}) as Map<String, dynamic>;
          }
          node[path.last] = u['value'];
        }
      }
    }
    notifyListeners();
  }

  /// Resuelve bindings `{"path": "/a/b"}` contra el data model.
  Object? resolve(Object? value) {
    if (value is Map && value.length == 1 && value['path'] is String) {
      Object? node = data;
      for (final k in (value['path'] as String).split('/').where((s) => s.isNotEmpty)) {
        node = node is Map ? node[k] : null;
      }
      return node;
    }
    if (value is Map) return value.map((k, v) => MapEntry(k as String, resolve(v)));
    return value;
  }

  Future<void> start(String texto) => _turn(() => _send(texto: texto));

  /// Cierre del loop: la interacción con un componente generado regresa al agente como `action`.
  Future<void> dispatch(String sourceComponentId, Map<String, dynamic> action,
      [Map<String, dynamic> extra = const {}]) {
    final event = action['event'] as Map<String, dynamic>;
    return _turn(() => _send(action: {
          'name': event['name'],
          'surfaceId': surfaceId,
          'sourceComponentId': sourceComponentId,
          'timestamp': DateTime.now().toUtc().toIso8601String(),
          'context': {...resolve(event['context'] ?? const {}) as Map<String, dynamic>, ...extra},
        }));
  }

  Future<void> _turn(Future<List<Map<String, dynamic>>> Function() call) async {
    if (busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      apply(await call());
    } catch (e) {
      error = '$e';
    }
    busy = false;
    notifyListeners();
  }
}

/// Catálogo `banorte-ahorro/v1`: nombre de componente → widget.
class SurfaceView extends StatelessWidget {
  const SurfaceView({super.key, required this.surface});

  final Surface surface;

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
      'MensajeAgente' => MensajeAgente(props: c),
      'TarjetaPregunta' => TarjetaPregunta(key: ObjectKey(c), props: c, surface: surface),
      'ProyeccionAhorroSimple' || 'ProyeccionAhorroMulti' =>
        ProyeccionAhorro(key: ObjectKey(c), props: c, surface: surface),
      'ResumenMetaGuardada' => ResumenMetaGuardada(props: c),
      final other => UnknownComponent('"$other" no está en el catálogo'),
    };
  }
}
