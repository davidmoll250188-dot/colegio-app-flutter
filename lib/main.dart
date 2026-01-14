import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

// --- CONFIGURACIÓN ---
// Obtén estas claves en tu panel de Supabase (Settings -> API)
// REEMPLAZA ESTO CON TUS CLAVES REALES DEL PASO 2.3
const supabaseUrl = 'https://xtqtfqzowgvuqggllwrp.supabase.co';
const supabaseKey = 'sb_publishable_1TOgskMUujx0pAfnDa9ATQ_6vEp_Fhf';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Supabase
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

  runApp(const ColegioApp());
}

class ColegioApp extends StatelessWidget {
  const ColegioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ColegioApp',
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
          // Sidebar (NavigationRail en Flutter)
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
                // Botón para cambiar rol (Demo)
                IconButton(
                  icon: Icon(
                    _isAdmin ? Icons.admin_panel_settings : Icons.person,
                  ),
                  tooltip: 'Cambiar Rol Demo',
                  onPressed: () => setState(() => _isAdmin = !_isAdmin),
                ),
              ],
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard),
                label: Text('Inicio'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.qr_code_scanner),
                label: Text('Asistencia'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.grade),
                label: Text('Notas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book),
                label: Text('Tareas'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Contenido Principal
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

// --- PÁGINA DE ASISTENCIA (LÓGICA SUPABASE) ---
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

  // Stream para escuchar cambios en tiempo real desde Supabase
  late final Stream<List<Map<String, dynamic>>> _attendanceStream;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _setupRealtimeStream();
  }

  // 1. Cargar lista de estudiantes (para el dropdown)
  Future<void> _fetchStudents() async {
    final data = await _supabase.from('students').select();
    setState(() {
      _students = List<Map<String, dynamic>>.from(data);
    });
  }

  // 2. Configurar el stream de asistencia (lectura en tiempo real)
  void _setupRealtimeStream() {
    _attendanceStream = _supabase
        .from('attendance')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map(
          (data) => data.map((e) {
            // Hacemos un join manual simple buscando el nombre del estudiante
            // En una app real, usaríamos .select('*, students(*)')
            return e; // Simplificado para este ejemplo
          }).toList(),
        );
  }

  // 3. Registrar Asistencia (Insertar en Supabase)
  Future<void> _registerAttendance() async {
    if (_selectedStudentId == null) return;

    final now = DateTime.now();
    final isLate = now.hour > 8; // Tarde después de las 8am

    try {
      await _supabase.from('attendance').insert({
        'student_id': _selectedStudentId,
        'status': isLate ? 'Tarde' : 'Temprano',
        'observation': _observation.isEmpty ? 'Sin novedad' : _observation,
        // timestamp se genera auto en la DB
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Asistencia registrada. Notificación enviada (Simulada).',
          ),
          backgroundColor: isLate ? Colors.orange : Colors.green,
        ),
      );

      setState(() {
        _observation = '';
        _selectedStudentId = null;
      });
    } catch (e) {
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
            widget.isAdmin
                ? 'Control de Asistencia (Admin)'
                : 'Historial de Asistencia',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),

          // --- FORMULARIO DE REGISTRO (SOLO ADMIN) ---
          if (widget.isAdmin) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Simulador de Escáner QR',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStudentId,
                          decoration: const InputDecoration(
                            labelText: 'Estudiante (Resultado del QR)',
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
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: _registerAttendance,
                        icon: const Icon(Icons.check),
                        label: const Text('Registrar'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Observación (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => _observation = val,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],

          // --- LISTA EN TIEMPO REAL ---
          const Text(
            'Registros Recientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final records = snapshot.data!;
                if (records.isEmpty) return const Text('No hay registros hoy.');

                return ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    final isLate = record['status'] == 'Tarde';

                    // Buscar nombre del estudiante (ineficiente pero funcional para demo)
                    final studentName = _students.firstWhere(
                      (s) => s['id'] == record['student_id'],
                      orElse: () => {'full_name': 'Desconocido'},
                    )['full_name'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLate
                              ? Colors.orange.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            isLate ? Icons.warning : Icons.check,
                            color: isLate ? Colors.orange : Colors.green,
                          ),
                        ),
                        title: Text(studentName),
                        subtitle: Text('${record['observation']}'),
                        trailing: Text(
                          DateFormat('HH:mm').format(
                            DateTime.parse(record['timestamp']).toLocal(),
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

// --- PAGINAS PLACEHOLDER ---
class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderPage({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, color: Colors.grey)),
        ],
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(title: "Panel General", icon: Icons.dashboard);
  }
}
