import 'package:flutter/material.dart';

import '../a2ui/surface.dart';
import '../agent_client.dart';
import '../models/dashboard_model.dart';
import '../theme.dart';

/// Detalle de un widget guardado: pide al backend el registro de ese widget (`ver_detalle`)
/// y lo pinta con el catálogo A2UI. Si el registro ya no existe ofrece eliminar el widget
/// (regresa `'eliminar'` al Dashboard).
class DetalleWidgetScreen extends StatefulWidget {
  const DetalleWidgetScreen({super.key, required this.instancia});
  final WidgetInstance instancia;

  @override
  State<DetalleWidgetScreen> createState() => _DetalleWidgetScreenState();
}

class _DetalleWidgetScreenState extends State<DetalleWidgetScreen> {
  // Un solo cliente: las acciones del detalle (ej. editar la meta) siguen la misma conversación.
  final _cliente = AgentClient();
  late final _surface = Surface(_cliente.sendTurn);
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _surface.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final w = widget.instancia;
    try {
      _surface.apply(await _cliente.sendTurn(action: {
        'name': 'ver_detalle',
        'module_type': w.toJson()['module_type'],
        'module_data_id': w.moduleDataId,
      }));
    } catch (e) {
      _error = 'No se pudo cargar el detalle.\n$e';
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: BanorteColors.background,
      appBar: AppBar(
        backgroundColor: BanorteColors.background,
        foregroundColor: BanorteColors.darkGray,
        elevation: 0,
        title: Text(widget.instancia.title, style: t.titleMedium?.copyWith(color: BanorteColors.darkGray)),
      ),
      body: SafeArea(
        child: _cargando
            ? const LinearProgressIndicator(minHeight: 3, color: BanorteColors.red, backgroundColor: Colors.transparent)
            : _error != null
                ? _Aviso(icon: Icons.cloud_off_rounded, texto: _error!)
                : _surface.isEmpty
                    ? _Aviso(
                        icon: Icons.inventory_2_outlined,
                        texto: 'Este widget ya no tiene datos',
                        accion: FilledButton.icon(
                          onPressed: () => Navigator.pop(context, 'eliminar'),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Eliminar widget'),
                        ),
                      )
                    : ListenableBuilder(
                        listenable: _surface,
                        builder: (context, _) => Column(children: [
                          _surface.busy
                              ? const LinearProgressIndicator(
                                  minHeight: 3, color: BanorteColors.red, backgroundColor: Colors.transparent)
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
                                      SurfaceView(surface: _surface),
                                      if (_surface.error != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 16),
                                          child:
                                              Text(_surface.error!, style: const TextStyle(color: BanorteColors.red)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icon, required this.texto, this.accion});
  final IconData icon;
  final String texto;
  final Widget? accion;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: BanorteColors.content3),
              const SizedBox(height: 16),
              Text(texto, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              if (accion != null) ...[const SizedBox(height: 24), accion!],
            ],
          ),
        ),
      );
}
