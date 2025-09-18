// Comentarios en español.
// Pantalla principal (dashboard) con:
// - Formulario para ingresar vehículo (placa + tipo).
// - Lista de vehículos activos con acciones: "Dar salida" y "Eliminar".
// - Histórico (Hive) accesible desde el AppBar.
// Correcciones: uso de Future en estado (_futureVehicles) + _reload() tras cambios.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'data/db_helper.dart';
import 'data/history_store.dart';
import 'models/vehicle.dart';
import 'utils/price_calculator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HistoryStore.init();
  runApp(const ParkCarApp());
}

class ParkCarApp extends StatelessWidget {
  const ParkCarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Paleta azul y blanco, estética limpia.
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ParkCar',
      theme: theme,
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _plateCtrl = TextEditingController();
  String _type = 'car';
  final _formKey = GlobalKey<FormState>();

  // Mantener la Future en estado y recargarla al cambiar datos
  Future<List<Vehicle>>? _futureVehicles;

  @override
  void initState() {
    super.initState();
    _futureVehicles = DBHelper.instance.getActiveVehicles();
  }

  Future<void> _reload() async {
    _futureVehicles = DBHelper.instance.getActiveVehicles();
    if (mounted) setState(() {});
  }

  void _showSnack(BuildContext ctx, String msg) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _addVehicle() async {
    // Validación simple: placa obligatoria.
    if (!_formKey.currentState!.validate()) return;

    final plate = _plateCtrl.text.trim().toUpperCase();
    final now = DateTime.now();

    try {
      await DBHelper.instance.insertVehicle(Vehicle(
        plate: plate,
        type: _type,
        entryMillis: now.millisecondsSinceEpoch,
      ));
      _plateCtrl.clear();
      if (mounted) {
        _showSnack(context, 'Vehículo ingresado.');
        await _reload(); // recargar lista
      }
    } catch (e) {
      // Mostrar el error real (p.ej., 'UNIQUE constraint failed', etc.)
      if (mounted) _showSnack(context, 'Error al ingresar: $e');
    }
  }

  Future<void> _deleteVehicle(Vehicle v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar vehículo'),
        content: Text(
            '¿Eliminar el vehículo ${v.plate} sin cobrar? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    await DBHelper.instance.deleteById(v.id!);
    if (mounted) {
      _showSnack(context, 'Vehículo eliminado.');
      await _reload(); // recargar lista
    }
  }

  Future<void> _checkoutVehicle(Vehicle v) async {
    final entry = DateTime.fromMillisecondsSinceEpoch(v.entryMillis);
    final exit = DateTime.now();
    final result = PriceCalculator.calculate(entry: entry, exit: exit, type: v.type);
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Dar salida'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Placa: ${v.plate}'),
            Text('Tipo: ${PriceCalculator.typeLabelEs(v.type)}'),
            const SizedBox(height: 8),
            Text('Entrada: ${DateFormat('dd/MM/yyyy HH:mm').format(entry)}'),
            Text('Salida:  ${DateFormat('dd/MM/yyyy HH:mm').format(exit)}'),
            Text('Horas cobradas: ${result.hours}'),
            const Divider(),
            Text('Total a cobrar: ${formatter.format(result.total)}'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Confirmar cobro')),
        ],
      ),
    );

    if (ok != true) return;

    // Guardar en Hive (histórico) y eliminar de la lista de activos.
    await HistoryStore.addRecord(
      plate: v.plate,
      type: v.type,
      entry: entry,
      exit: exit,
      hours: result.hours,
      total: result.total,
    );
    await DBHelper.instance.deleteById(v.id!);

    if (mounted) {
      _showSnack(context, 'Salida registrada. Cobro: ${formatter.format(result.total)}');
      await _reload(); // recargar lista
    }
  }

  void _openHistory() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryPage()));
  }

  @override
  Widget build(BuildContext context) {
    final typeItems = const [
      DropdownMenuItem(value: 'car', child: Text('Carro')),
      DropdownMenuItem(value: 'moto', child: Text('Moto')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('ParkCar'),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ------- Formulario de ingreso -------
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Ingresar nuevo vehículo', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _plateCtrl,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(
                                labelText: 'Placa',
                                hintText: 'Ej: ABC123',
                              ),
                              validator: (v) {
                                if ((v ?? '').trim().isEmpty) return 'La placa es obligatoria';
                                if ((v ?? '').trim().length < 5) return 'Placa inválida';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _type,
                              items: typeItems,
                              decoration: const InputDecoration(labelText: 'Tipo'),
                              onChanged: (v) => setState(() => _type = v ?? 'car'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Ingresar'),
                          onPressed: _addVehicle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ------- Lista de activos -------
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Vehículos activos', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Vehicle>>(
                future: _futureVehicles, // usa la future del estado
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Error: ${snap.error}'));
                  }
                  final items = snap.data ?? [];
                  if (items.isEmpty) {
                    return const Center(child: Text('No hay vehículos activos.'));
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final v = items[i];
                      final entry = DateTime.fromMillisecondsSinceEpoch(v.entryMillis);
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                        ),
                        child: ListTile(
                          title: Text('${v.plate} • ${PriceCalculator.typeLabelEs(v.type)}'),
                          subtitle: Text('Entrada: ${DateFormat('dd/MM/yyyy HH:mm').format(entry)}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () => _checkoutVehicle(v),
                                icon: const Icon(Icons.exit_to_app),
                                label: const Text('Dar salida'),
                              ),
                              IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () => _deleteVehicle(v),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Map<String, dynamic>> _records = [];

  @override
  void initState() {
    super.initState();
    _records = HistoryStore.getAll().reversed.toList(); // más reciente primero
  }

  String _fmtDate(int ms) => DateFormat('dd/MM/yyyy HH:mm')
      .format(DateTime.fromMillisecondsSinceEpoch(ms));

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: r'$');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico'),
        actions: [
          IconButton(
            tooltip: 'Borrar histórico',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Borrar histórico'),
                  content: const Text('¿Desea borrar todos los registros del histórico?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                    FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Borrar')),
                  ],
                ),
              );
              if (ok == true) {
                await HistoryStore.clearAll();
                if (mounted) setState(() => _records = []);
              }
            },
            icon: const Icon(Icons.delete_sweep_outlined),
          )
        ],
      ),
      body: _records.isEmpty
          ? const Center(child: Text('No hay registros en el histórico.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final r = _records[i];
                final typeEs = r['type'] == 'car' ? 'Carro' : 'Moto';
                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
                  ),
                  child: ListTile(
                    title: Text('${r['plate']} • $typeEs • ${r['hours']} h'),
                    subtitle: Text('Entrada: ${_fmtDate(r['entryMillis'])}\nSalida:  ${_fmtDate(r['exitMillis'])}'),
                    isThreeLine: true,
                    trailing: Text(formatter.format(r['total'])),
                  ),
                );
              },
            ),
    );
  }
}
