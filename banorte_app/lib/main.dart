import 'package:flutter/material.dart';

import 'a2ui/components.dart';
import 'a2ui/surface.dart';
import 'agent_client.dart';
import 'theme.dart';

void main() => runApp(
      MaterialApp(
        title: 'Banorte · Simulador de ahorro',
        debugShowCheckedModeBanner: false,
        theme: banorteTheme(),
        home: const HomePage(),
      ),
    );

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Surface _surface = _nueva();
  final _intencion = TextEditingController();

  Surface _nueva() => Surface(AgentClient().sendTurn);

  void _reiniciar() => setState(() {
        _surface.dispose();
        _surface = _nueva();
        _intencion.clear();
      });

  void _empezar([String? texto]) {
    final t = (texto ?? _intencion.text).trim();
    if (t.isNotEmpty) _surface.start(t);
  }

  @override
  void dispose() {
    _surface.dispose();
    _intencion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'BANORTE',
                                style: TextStyle(
                                  fontFamily: gotham,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                  letterSpacing: 1,
                                  color: BanorteColors.red,
                                ),
                              ),
                              const Spacer(),
                              if (!_surface.isEmpty)
                                TextButton.icon(
                                  onPressed: _reiniciar,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('Nueva simulación'),
                                  style: TextButton.styleFrom(foregroundColor: BanorteColors.darkGray),
                                ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          if (_surface.isEmpty) _hero(context) else SurfaceView(surface: _surface),
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
        Text('Ahorra con\nintención.\nVe tu futuro.', style: t.displaySmall),
        const SizedBox(height: 16),
        Text(
          'Cuéntanos para qué quieres ahorrar. Te haremos unas preguntas y generaremos '
          'una proyección que puedes ajustar y guardar como tu meta.',
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
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BanorteColors.darkGray),
          onPressed: busy ? null : _empezar,
          child: const Text('Empezar'),
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final MapEntry(key: etiqueta, value: frase) in sugerencias.entries)
              SizedBox(
                width: 168,
                child: Material(
                  color: BanorteColors.white,
                  borderRadius: BorderRadius.circular(28),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(28),
                    onTap: busy ? null : () => _empezar(frase),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [Flexible(child: Pill(etiqueta)), const SizedBox(width: 8), const ArrowButton()],
                          ),
                          const SizedBox(height: 28),
                          Text(frase, style: t.titleMedium),
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
