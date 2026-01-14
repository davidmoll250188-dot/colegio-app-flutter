import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// --- CONFIGURACIÓN ---
// REEMPLAZA ESTO CON TUS CLAVES REALES DEL PASO 2.3
const supabaseUrl = 'https://xtqtfqzowgvuqggllwrp.supabase.co';
const supabaseKey = 'sb_publishable_1TOgskMUujx0pAfnDa9ATQ_6vEp_Fhf';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );

  runApp(const ColegioApp());
}

class ColegioApp extends StatelessWidget {
  const ColegioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColegioApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MainLayout(),
    );
  }
}

// --- LAYOUT PRINCIPAL (SIDEBAR + CONTENIDO) ---
class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isAdmin = true; // Simulación de rol

  final List<Widget> _pages = [
    const DashboardPage(),
    const AttendancePage(),
    const PlaceholderPage(title: "Notas", icon: Icons.school),
    const PlaceholderPage(title: "Tareas", icon: Icons.book),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            leading: Column(
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.school, size: 40, color: Colors.blue),
                const SizedBox(height: 20),
                IconButton(
                  icon: Icon(
                      _isAdmin ? Icons.admin_panel_settings : Icons.person),
                  tooltip: 'Cambiar Rol Demo',
                  onPressed: () => setState(() => _isAdmin = !_isAdmin),
                ),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                  icon: Icon(Icons.dashboard), label: Text('Inicio')),
              NavigationRailDestination(
                  icon: Icon(Icons.qr_code_scanner), label: Text('Asistencia')),
              NavigationRailDestination(
                  icon: Icon(Icons.grade), label: Text('Notas')),
              NavigationRailDestination(
                  icon: Icon(Icons.book), label: Text('Tareas')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _selectedIndex == 1
                ? AttendancePage(isAdmin: _isAdmin)
                : _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

// --- PÁGINA DE ASISTENCIA ---
class AttendancePage extends StatefulWidget {
  final bool isAdmin;
  const AttendancePage({super.key, this.isAdmin = true});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _students = [];
  String? _selectedStudentId;
  String _observation = '';

  late final Stream<List<Map<String, dynamic>>> _attendanceStream;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _setupRealtimeStream();
  }

  Future<void> _fetchStudents() async {
    final data = await _supabase.from('students').select();
    if (mounted) {
      setState(() {
        _students = List<Map<String, dynamic>>.from(data);
      });
    }
  }

  void _setupRealtimeStream() {
    _attendanceStream = _supabase
        .from('attendance')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((data) => data);
  }

  Future<void> _registerAttendance() async {
    if (_selectedStudentId == null) {
      return;
    }

    final now = DateTime.now();
    final isLate = now.hour > 8;

    try {
      await _supabase.from('attendance').insert({
        'student_id': _selectedStudentId,
        'status': isLate ? 'Tarde' : 'Temprano',
        'observation': _observation.isEmpty ? 'Sin novedad' : _observation,
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Asistencia registrada.'),
          backgroundColor: isLate ? Colors.orange : Colors.green,
        ),
      );

      setState(() {
        _observation = '';
        _selectedStudentId = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.isAdmin ? 'Control de Asistencia' : 'Historial',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          if (widget.isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _selectedStudentId,
                    decoration: const InputDecoration(
                      labelText: 'Estudiante',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: _students.map((s) {
                      return DropdownMenuItem<String>(
                        value: s['id'],
                        child: Text(s['full_name']),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedStudentId = val),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => _observation = val,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _registerAttendance,
                    icon: const Icon(Icons.check),
                    label: const Text('Registrar Asistencia'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
          const Text('Registros Recientes',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data!;
                if (records.isEmpty) {
                  return const Text('No hay registros.');
                }

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final studentName = _students.firstWhere(
                        (s) => s['id'] == record['student_id'],
                        orElse: () =>
                            {'full_name': 'Cargando...'})['full_name'];

                    return Card(
                      child: ListTile(
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(studentName),
                        subtitle: Text(record['observation'] ?? ''),
                        trailing: Text(
                          DateFormat('HH:mm').format(
                              DateTime.parse(record['timestamp']).toLocal()),
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
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(icon, size: 64, color: Colors.grey), Text(title)]));
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: "Panel General", icon: Icons.dashboard);
}
