import 'package:flutter/material.dart';

void main() {
  runApp(const AttendanceApp());
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Счетчик Пропусков СГЮА',
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

  // Расписание ИЮЮР24-08 (День недели -> Список предметов с временем)
  final Map<int, List<String>> schedule = {
    DateTime.monday: [
      "11:40 — Финансовое право (Сем.)",
    ],
    DateTime.tuesday: [
      "11:40 — Административное право (Сем.)",
    ],
    DateTime.wednesday: [
      "11:40 — Гражданский процесс (Сем.)",
      "13:30 — Уголовный процесс (Сем.)",
    ],
    DateTime.thursday: [
      "08:30 — Криминалистика (Сем.)",
      "10:05 — Гражданское право (Сем.)",
    ],
    DateTime.friday: [
      "08:30 — Конст. право (Сем.)",
      "11:40 — Уголовное право (Сем.)",
    ],
    DateTime.saturday: [
      "10:05 — Гражданское право (Сем.)",
    ],
  };

  // Хранилище отметок: "YYYY-MM-DD_PairName" -> "present" | "excused" | "unexcused"
  final Map<String, String> pairStatus = {};

  final List<String> quotes = [
    "«Дисциплина — это выбор между тем, чего ты хочешь сейчас, и тем, чего ты хочешь больше всего.»",
    "«Каждая посещенная пара приближает к спокойной сессии!»",
    "«Лимит 36 часов — береги каждый пропуск без ув. причины!»",
  ];

  DateTime selectedDate = DateTime(2026, 9, 1);

  @override
  Widget build(BuildContext context) {
    double progress = (unexcusedHours / maxHours).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Учет пропусков | ИЮЮР24-08'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Карточка Прогресса
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
                        Text(
                          "$unexcusedHours / $maxHours ч",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: unexcusedHours >= 30 ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      borderRadius: BorderRadius.circular(6),
                      color: unexcusedHours >= 30 ? Colors.redAccent : Colors.deepPurpleAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Запас без ув. причины: ${maxHours - unexcusedHours} ч. (${(maxHours - unexcusedHours) ~/ 2} пар)",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Цитата
            Container(
              width: double.infinity,
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

            // Выбор месяца/дня
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  " Календарь за пар",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2026, 9, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );
                    if (picked != null) {
                      setState(() {
                        selectedDate = picked;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_month, size: 18),
                  label: Text("${selectedDate.day}.${selectedDate.month}.${selectedDate.year}"),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Список пар на выбранный день
            _buildPairsListForDate(selectedDate),
          ],
        ),
      ),
    );
  }

  Widget _buildPairsListForDate(DateTime date) {
    List<String>? dayPairs = schedule[date.weekday];
    String dateStr = "${date.year}-${date.month}-${date.day}";

    if (dayPairs == null || dayPairs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text("Занятий по расписанию нет (выходной / нет пар)", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: dayPairs.map((pair) {
        String key = "${dateStr}_$pair";
        String status = pairStatus[key] ?? "none";

        Color tileColor = Colors.white10;
        String statusText = "Не отмечено";
        IconData icon = Icons.help_outline;

        if (status == "present") {
          tileColor = Colors.green.withOpacity(0.2);
          statusText = "Был на паре";
          icon = Icons.check_circle;
        } else if (status == "excused") {
          tileColor = Colors.blue.withOpacity(0.2);
          statusText = "Пропуск (Уважительная)";
          icon = Icons.info;
        } else if (status == "unexcused") {
          tileColor = Colors.red.withOpacity(0.2);
          statusText = "Пропуск (Неуважительная, +2ч)";
          icon = Icons.warning;
        }

        return Card(
          color: tileColor,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(icon, color: status == "unexcused" ? Colors.redAccent : Colors.white),
            title: Text(pair, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(statusText, style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showMarkPairDialog(key, pair),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMarkPairDialog(String key, String pairName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Пара: $pairName"),
        content: const Text("Отметь статус посещения этой пары:"),
        actions: [
          TextButton(
            onPressed: () {
              _updatePairStatus(key, "present");
              Navigator.pop(context);
            },
            child: const Text("Был (0 ч)", style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () {
              _updatePairStatus(key, "excused");
              Navigator.pop(context);
            },
            child: const Text("Уважительная (0 ч)", style: TextStyle(color: Colors.lightBlueAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _updatePairStatus(key, "unexcused");
              Navigator.pop(context);
            },
            child: const Text("Н/У пропуск (+2 ч)"),
          ),
        ],
      ),
    );
  }

  void _updatePairStatus(String key, String newStatus) {
    setState(() {
      String oldStatus = pairStatus[key] ?? "none";

      // Снимаем часы от предыдущего состояния, если был Н/У
      if (oldStatus == "unexcused") {
        unexcusedHours = (unexcusedHours - 2).clamp(0, maxHours);
      }

      // Добавляем часы, если новый статус Н/У
      if (newStatus == "unexcused") {
        if (unexcusedHours + 2 <= maxHours) {
          unexcusedHours += 2;
        }
      }

      pairStatus[key] = newStatus;
    });
  }
}
