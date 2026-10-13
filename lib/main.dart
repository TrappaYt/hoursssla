import 'package:flutter/material.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Счетчик Пропусков',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: Colors.deepPurple,
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.amber,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int unexcusedHours = 22; // Предзаполненные 22 часа
  final int maxHours = 36;

  final Map<int, List<String>> schedule = {
    DateTime.monday: ["11:40 — Финансовое право (Сем.)"],
    DateTime.tuesday: ["11:40 — Административное право (Сем.)"],
    DateTime.wednesday: ["11:40 — Гражданский процесс (Сем.)", "13:30 — Уголовный процесс (Сем.)"],
    DateTime.thursday: ["08:30 — Криминалистика (Сем.)", "10:05 — Гражданское право (Сем.)"],
    DateTime.friday: ["08:30 — Конст. право (Сем.)", "11:40 — Уголовное право (Сем.)"],
    DateTime.saturday: ["10:05 — Гражданское право (Сем.)"],
  };

  final List<String> quotes = [
    "«Дисциплина — это выбор между тем, чего ты хочешь сейчас, и тем, чего ты хочешь больше всего.»",
    "«Каждая пропущенная пара приближает к отчислению. Держись!»",
    "«Осталось совсем мало часов — береги каждый пропуск!»",
  ];

  @override
  Widget build(BuildContext context) {
    double progress = (unexcusedHours / maxHours).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Счетчик Пропусков (ИЮЮР24-08)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFF1E1E2C),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Н/У пропуски:", style: TextStyle(fontSize: 16)),
                        Text("$unexcusedHours / $maxHours ч",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: unexcusedHours >= 30 ? Colors.redAccent : Colors.greenAccent,
                            )),
                      ],
                    ),
                    const SizedBox(height: 15),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                      color: unexcusedHours >= 30 ? Colors.redAccent : Colors.deepPurpleAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Осталось без ув. причины: ${maxHours - unexcusedHours} ч. (${(maxHours - unexcusedHours) ~/ 2} пар)",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                quotes[unexcusedHours % quotes.length],
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _showAddAbsenceDialog,
              icon: const Icon(Icons.add_task),
              label: const Text("Отметить пропуск пары"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAbsenceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить пропуск"),
        content: const Text("Укажите тип причины пропуска занятия:"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Уважительная (0 ч)", style: TextStyle(color: Colors.greenAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              setState(() {
                if (unexcusedHours + 2 <= maxHours) {
                  unexcusedHours += 2;
                }
              });
              Navigator.pop(context);
            },
            child: const Text("Неуважительная (+2 ч)"),
          ),
        ],
      ),
    );
  }
}
