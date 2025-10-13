import 'package:flutter/material.dart';
import 'package:app_flutter/pages/profile_page.dart';
import 'package:app_flutter/pages/medical_followup_page.dart';
import 'package:app_flutter/pages/lista_pacientes_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTrack - Fichas Médicas',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      routes: {
        '/': (context) => const MyHomePage(title: 'MediTrack - Inicio'),
        '/profile': (context) => const ProfilePage(),
        '/followup': (context) => const MedicalFollowupPage(),
        '/lista-pacientes': (context) => const ListaPacientesPage(),
      },
      initialRoute: '/',
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Lista de Pacientes',
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.of(context).pushNamed('/lista-pacientes');
            },
          ),
          IconButton(
            tooltip: 'Crear Paciente',
            icon: const Icon(Icons.person_add),
            onPressed: () {
              Navigator.of(context).pushNamed('/profile');
            },
          ),
          IconButton(
            tooltip: 'Seguimiento',
            icon: const Icon(Icons.monitor_heart),
            onPressed: () {
              Navigator.of(context).pushNamed('/followup');
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.medical_services, size: 80, color: Colors.deepPurple),
            const SizedBox(height: 24),
            const Text(
              'MediTrack',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sistema de Fichas Médicas',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/lista-pacientes'),
              icon: const Icon(Icons.people),
              label: const Text('Ver Pacientes'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushNamed('/profile'),
              icon: const Icon(Icons.person_add),
              label: const Text('Crear Nuevo Paciente'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
