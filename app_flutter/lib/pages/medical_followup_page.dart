import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class MedicalFollowupPage extends StatefulWidget {
  const MedicalFollowupPage({super.key});

  @override
  State<MedicalFollowupPage> createState() => _MedicalFollowupPageState();
}

class _Consulta {
  final DateTime fecha;
  final String nota;
  _Consulta(this.fecha, this.nota);
}

class _MedicalFollowupPageState extends State<MedicalFollowupPage> {
  final List<_Consulta> _consultas = [
    _Consulta(DateTime.now().subtract(const Duration(days: 10)), 'Control general'),
    _Consulta(DateTime.now().subtract(const Duration(days: 30)), 'Revisión de medicamentos'),
    _Consulta(DateTime.now().subtract(const Duration(days: 60)), 'Control de presión'),
    _Consulta(DateTime.now().subtract(const Duration(days: 95)), 'Examen de laboratorio'),
  ];

  final TextEditingController _notaController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _notaController.dispose();
    super.dispose();
  }

  void _addConsulta() {
    final fecha = _selectedDate ?? DateTime.now();
    final nota = _notaController.text.trim();
    if (nota.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ingrese una nota para la consulta')));
      return;
    }
    setState(() {
      _consultas.add(_Consulta(fecha, nota));
      _notaController.clear();
      _selectedDate = null;
    });
  }

  Map<int, int> _consultasPorMes() {
    final Map<int, int> counts = {};
    for (final c in _consultas) {
      final key = c.fecha.year * 100 + c.fecha.month;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  List<BarChartGroupData> _buildBarGroups(BuildContext context) {
    final counts = _consultasPorMes();
    final now = DateTime.now();
    final months = List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return dt;
    });

    List<BarChartGroupData> groups = [];
    for (int i = 0; i < months.length; i++) {
      final dt = months[i];
      final key = dt.year * 100 + dt.month;
      final qty = counts[key] ?? 0;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [BarChartRodData(toY: qty.toDouble(), width: 18, color: Theme.of(context).colorScheme.primary)],
      ));
    }
    return groups;
  }

  List<String> _monthLabels() {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final dt = DateTime(now.year, now.month - (5 - i));
      return '${dt.month}/${dt.year % 100}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final barGroups = _buildBarGroups(context);
    final labels = _monthLabels();

    final maxCount = (_consultasPorMes().values.fold<int>(0, (p, e) => p > e ? p : e)).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento médico')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Últimas consultas (por mes)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: (maxCount < 1) ? 1.0 : maxCount + 1.0,
                      barGroups: barGroups,
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              final text = (idx >= 0 && idx < labels.length) ? labels[idx] : '';
                              return SideTitleWidget(meta: meta, child: Text(text, style: const TextStyle(fontSize: 10)));
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Agregar nueva consulta', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _notaController,
                    decoration: const InputDecoration(labelText: 'Nota / Motivo'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => _selectedDate = d);
                  },
                  child: Text(_selectedDate == null ? 'Seleccionar fecha' : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addConsulta, child: const Text('Agregar')),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Historial de consultas', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: ListView.separated(
                  padding: const EdgeInsets.all(8),
                  itemCount: _consultas.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final c = _consultas[_consultas.length - 1 - index];
                    return ListTile(
                      title: Text(c.nota),
                      subtitle: Text('${c.fecha.day}/${c.fecha.month}/${c.fecha.year}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() => _consultas.removeAt(_consultas.length - 1 - index));
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
