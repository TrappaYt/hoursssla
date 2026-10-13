
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const Color bg = Color(0xFF0F0F1A);
const Color panel = Color(0xFF1E1E2E);
const Color purple = Color(0xFF6C5CE7);
const Color mutedPurple = Color(0xFFA29BFE);

const int maxHours = 36;
const int initialHours = 22;

// Важно: DateTime нельзя объявлять через const в этой версии Dart.
final DateTime weekAnchor = DateTime(2026, 10, 13);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  try {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await notifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
  } catch (e) {
    debugPrint('Ошибка инициализации уведомлений: $e');
  }

  runApp(const AttendanceApp());
}

// -----------------------------------------------------------------------------
// МОДЕЛЬ ЗАНЯТИЯ
// -----------------------------------------------------------------------------

class Lesson {
  final String time;
  final String subject;
  final String room;
  final String type;

  const Lesson({
    required this.time,
    required this.subject,
    required this.room,
    required this.type,
  });
}

// -----------------------------------------------------------------------------
// РАСПИСАНИЕ
// true = четная неделя, false = нечетная
// -----------------------------------------------------------------------------

final Map<bool, Map<int, List<Lesson>>> masterSchedule = {
  true: {
    DateTime.monday: const [
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Финансовое право',
        room: 'каб. 402',
        type: 'Сем.',
      ),
    ],
    DateTime.tuesday: const [
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Административное право',
        room: 'каб. 315',
        type: 'Сем.',
      ),
    ],
    DateTime.wednesday: const [
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Гражданский процесс',
        room: 'каб. 501',
        type: 'Сем.',
      ),
      Lesson(
        time: '13:30 — 15:00',
        subject: 'Уголовный процесс',
        room: 'каб. 508',
        type: 'Сем.',
      ),
    ],
    DateTime.thursday: const [
      Lesson(
        time: '08:30 — 10:00',
        subject: 'Криминалистика',
        room: 'каб. 210',
        type: 'Сем.',
      ),
      Lesson(
        time: '10:05 — 11:35',
        subject: 'Гражданское право',
        room: 'каб. 412',
        type: 'Сем.',
      ),
    ],
    DateTime.friday: const [
      Lesson(
        time: '08:30 — 10:00',
        subject: 'Конституционное право',
        room: 'каб. 302',
        type: 'Сем.',
      ),
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Уголовное право',
        room: 'каб. 408',
        type: 'Сем.',
      ),
    ],
    DateTime.saturday: const [
      Lesson(
        time: '10:05 — 11:35',
        subject: 'Гражданское право',
        room: 'каб. 412',
        type: 'Сем.',
      ),
    ],
  },
  false: {
    DateTime.monday: const [
      Lesson(
        time: '08:30 — 10:00',
        subject: 'Финансовое право',
        room: 'Ауд. 1 (Лекция)',
        type: 'Лек.',
      ),
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Финансовое право',
        room: 'каб. 402',
        type: 'Сем.',
      ),
    ],
    DateTime.tuesday: const [
      Lesson(
        time: '10:05 — 11:35',
        subject: 'Административное право',
        room: 'каб. 315',
        type: 'Сем.',
      ),
    ],
    DateTime.wednesday: const [
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Гражданский процесс',
        room: 'каб. 501',
        type: 'Сем.',
      ),
    ],
    DateTime.thursday: const [
      Lesson(
        time: '08:30 — 10:00',
        subject: 'Криминалистика',
        room: 'каб. 210',
        type: 'Сем.',
      ),
    ],
    DateTime.friday: const [
      Lesson(
        time: '11:40 — 13:10',
        subject: 'Уголовное право',
        room: 'каб. 408',
        type: 'Сем.',
      ),
    ],
    DateTime.saturday: const [
      Lesson(
        time: '10:05 — 11:35',
        subject: 'Гражданское право',
        room: 'каб. 412',
        type: 'Сем.',
      ),
    ],
  },
};

// -----------------------------------------------------------------------------
// ДАТЫ И ВРЕМЯ
// -----------------------------------------------------------------------------

String dateKey(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

DateTime parseLessonTime(DateTime date, String time) {
  final start = time.split(' — ').first.split(':');

  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(start[0]),
    int.parse(start[1]),
  );
}

DateTime parseLessonEnd(DateTime date, String time) {
  final end = time.split(' — ').last.split(':');

  return DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(end[0]),
    int.parse(end[1]),
  );
}

String lessonKey(DateTime date, Lesson lesson) {
  return '${dateKey(date)}|${lesson.subject}|'
      '${lesson.time}|${lesson.room}';
}

// Считаем недели от понедельника.
// 13 октября 2026 года — вторник четной недели.
// Поэтому понедельник 12 октября тоже относится к этой неделе.
bool isEvenWeek(DateTime date) {
  final dateMonday = DateTime(
    date.year,
    date.month,
    date.day,
  ).subtract(Duration(days: date.weekday - DateTime.monday));

  final anchorMonday = DateTime(
    weekAnchor.year,
    weekAnchor.month,
    weekAnchor.day,
  ).subtract(Duration(days: weekAnchor.weekday - DateTime.monday));

  final days = dateMonday.difference(anchorMonday).inDays;
  final weekOffset = days ~/ 7;

  return weekOffset.isEven;
}

// -----------------------------------------------------------------------------
// ПРИЛОЖЕНИЕ
// -----------------------------------------------------------------------------

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Моя посещаемость',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bg,
        primaryColor: purple,
        colorScheme: const ColorScheme.dark(
          primary: purple,
          secondary: Color(0xFFFF7675),
          surface: panel,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: bg,
          elevation: 0,
          centerTitle: true,
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: panel,
        ),
      ),
      home: const MainContainer(),
    );
  }
}

// -----------------------------------------------------------------------------
// ГЛАВНЫЙ ЭКРАН И СОХРАНЕНИЕ ДАННЫХ
// -----------------------------------------------------------------------------

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int currentIndex = 0;
  int unexcusedHours = initialHours;

  DateTime selectedDate = DateTime(2026, 10, 13);

  final Map<String, String> pairStatus = {};

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedStatuses = prefs.getString('pairStatus');

      if (savedStatuses != null) {
        final decoded = jsonDecode(savedStatuses);

        if (decoded is Map) {
          pairStatus
            ..clear()
            ..addAll(
              decoded.map(
                (key, value) => MapEntry(
                  key.toString(),
                  value.toString(),
                ),
              ),
            );
        }
      }

      final savedHours = prefs.getInt('unexcusedHours') ?? initialHours;
      final safeHours = savedHours.clamp(0, maxHours).toInt();

      if (!mounted) return;

      setState(() {
        unexcusedHours = safeHours;
        loading = false;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных: $e');

      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt('unexcusedHours', unexcusedHours);
      await prefs.setString('pairStatus', jsonEncode(pairStatus));
    } catch (e) {
      debugPrint('Ошибка сохранения данных: $e');
    }
  }

  void updateStatus(String key, String newStatus) {
    final oldStatus = pairStatus[key] ?? 'none';

    if (oldStatus == newStatus) return;

    int updatedHours = unexcusedHours;

    // Если раньше пропуск был неуважительным,
    // убираем его два часа при смене статуса.
    if (oldStatus == 'unexcused') {
      updatedHours -= 2;
    }

    // Новый неуважительный пропуск добавляет два часа.
    if (newStatus == 'unexcused') {
      if (updatedHours + 2 > maxHours) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Лимит в 36 часов будет превышен. '
              'Нельзя добавить этот пропуск.',
            ),
          ),
        );
        return;
      }

      updatedHours += 2;
    }

    setState(() {
      // clamp возвращает num, поэтому преобразуем результат в int.
      unexcusedHours = updatedHours.clamp(0, maxHours).toInt();

      if (newStatus == 'none') {
        pairStatus.remove(key);
      } else {
        pairStatus[key] = newStatus;
      }
    });

    saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: purple),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          HomeScreen(
            unexcusedHours: unexcusedHours,
            selectedDate: selectedDate,
            pairStatus: pairStatus,
            onDateChanged: (date) {
              setState(() {
                selectedDate = date;
              });
            },
            onStatusChanged: updateStatus,
          ),
          AnalyticsScreen(
            pairStatus: pairStatus,
            unexcusedHours: unexcusedHours,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        backgroundColor: panel,
        indicatorColor: purple.withOpacity(0.25),
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.schedule),
            label: 'Расписание',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Аналитика',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ЭКРАН РАСПИСАНИЯ
// -----------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  final int unexcusedHours;
  final DateTime selectedDate;
  final Map<String, String> pairStatus;
  final ValueChanged<DateTime> onDateChanged;
  final void Function(String, String) onStatusChanged;

  const HomeScreen({
    super.key,
    required this.unexcusedHours,
    required this.selectedDate,
    required this.pairStatus,
    required this.onDateChanged,
    required this.onStatusChanged,
  });

  Color get statusColor {
    if (unexcusedHours >= 34) return Colors.redAccent;
    if (unexcusedHours >= 28) return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = maxHours - unexcusedHours;
    final even = isEvenWeek(selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Моя посещаемость',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Карточка лимита
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Лимит неуважительных пропусков',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$unexcusedHours',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        ' / 36 часов',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (unexcusedHours / maxHours)
                        .clamp(0.0, 1.0)
                        .toDouble(),
                    minHeight: 10,
                    backgroundColor: Colors.white10,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Осталось: $remaining ч.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  'Запас: ${remaining ~/ 2} полных пар',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Подсказка
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: purple.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Text(
              '«Лучшая защита от проблем на сессии — присутствие на парах».',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedPurple,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Выбор даты и четности недели
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    even ? 'Четная неделя' : 'Нечетная неделя',
                    style: const TextStyle(
                      color: mutedPurple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Выбрать дату',
                  icon: const Icon(
                    Icons.calendar_month,
                    color: purple,
                  ),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2026, 9, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );

                    if (picked != null) {
                      onDateChanged(picked);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Расписание на ${dateKey(selectedDate)}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ...buildLessons(context, even),
        ],
      ),
    );
  }

  List<Widget> buildLessons(BuildContext context, bool even) {
    final lessons = masterSchedule[even]?[selectedDate.weekday] ?? [];

    if (lessons.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: panel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.bedtime_outlined,
                size: 36,
                color: Colors.grey,
              ),
              SizedBox(height: 8),
              Text(
                'Выходной день — пар нет!',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ];
    }

    return lessons.map((lesson) {
      final key = lessonKey(selectedDate, lesson);
      final status = pairStatus[key] ?? 'none';

      Color color = Colors.grey;
      String label = 'Не отмечено';
      IconData icon = Icons.radio_button_unchecked;

      switch (status) {
        case 'present':
          color = Colors.greenAccent;
          label = 'Присутствовал';
          icon = Icons.check_circle;
          break;
        case 'excused':
          color = Colors.lightBlueAccent;
          label = 'Уважительная причина';
          icon = Icons.info;
          break;
        case 'unexcused':
          color = Colors.redAccent;
          label = 'Н/У пропуск (+2 ч)';
          icon = Icons.warning;
          break;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 25),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lesson.subject,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Добавить в календарь',
                  icon: const Icon(
                    Icons.event,
                    color: mutedPurple,
                  ),
                  onPressed: () => addToCalendar(context, lesson),
                ),
                IconButton(
                  tooltip: 'Отметить посещаемость',
                  icon: const Icon(
                    Icons.edit,
                    color: purple,
                  ),
                  onPressed: () => showStatusDialog(context, key, lesson),
                ),
              ],
            ),
            Text(
              '${lesson.time}  •  ${lesson.type}',
              style: const TextStyle(
                color: mutedPurple,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              lesson.room,
              style: const TextStyle(
                color: Colors.amberAccent,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<void> addToCalendar(
    BuildContext context,
    Lesson lesson,
  ) async {
    final event = Event(
      title: '${lesson.subject} (${lesson.type})',
      description: 'Занятие группы ИЮЮР24-08 в ${lesson.room}',
      location: 'СГЮА, ${lesson.room}',
      startDate: parseLessonTime(selectedDate, lesson.time),
      endDate: parseLessonEnd(selectedDate, lesson.time),
      allDay: false,
      androidParams: const AndroidParams(),
    );

    try {
      final success = await Add2Calendar.addEvent2Cal(event);

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Открой календарь и подтверди добавление пары.'
                : 'Не удалось открыть календарь.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка календаря: $e'),
        ),
      );
    }
  }

  void showStatusDialog(
    BuildContext context,
    String key,
    Lesson lesson,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            lesson.subject,
            style: const TextStyle(fontSize: 17),
          ),
          content: Text('Отметь посещаемость: ${lesson.time}'),
          actions: [
            TextButton(
              onPressed: () {
                onStatusChanged(key, 'present');
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Был (0 ч)',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                onStatusChanged(key, 'excused');
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Уважительная (0 ч)',
                style: TextStyle(color: Colors.lightBlueAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                onStatusChanged(key, 'unexcused');
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Н/У (+2 ч)',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                onStatusChanged(key, 'none');
                Navigator.pop(dialogContext);
              },
              child: const Text('Сбросить отметку'),
            ),
          ],
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// АНАЛИТИКА
// -----------------------------------------------------------------------------

class AnalyticsScreen extends StatelessWidget {
  final Map<String, String> pairStatus;
  final int unexcusedHours;

  const AnalyticsScreen({
    super.key,
    required this.pairStatus,
    required this.unexcusedHours,
  });

  @override
  Widget build(BuildContext context) {
    final Map<String, Map<String, int>> stats = {};

    for (final entry in pairStatus.entries) {
      final parts = entry.key.split('|');

      if (parts.length < 4) continue;

      final subject = parts[1];
      final status = entry.value;

      stats.putIfAbsent(
        subject,
        () => {
          'unexcused': 0,
          'excused': 0,
          'present': 0,
        },
      );

      if (status == 'unexcused') {
        stats[subject]!['unexcused'] =
            stats[subject]!['unexcused']! + 2;
      } else if (status == 'excused') {
        stats[subject]!['excused'] =
            stats[subject]!['excused']! + 1;
      } else if (status == 'present') {
        stats[subject]!['present'] =
            stats[subject]!['present']! + 1;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Аналитика',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: stats.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 60,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Пока нет отметок посещаемости',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Отмечай пары во вкладке «Расписание»',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: panel,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Общий лимит пропусков',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$unexcusedHours / $maxHours ч.',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: unexcusedHours >= 34
                              ? Colors.redAccent
                              : mutedPurple,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (unexcusedHours / maxHours)
                            .clamp(0.0, 1.0)
                            .toDouble(),
                        color: unexcusedHours >= 34
                            ? Colors.redAccent
                            : purple,
                        backgroundColor: Colors.white10,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...stats.entries.map((entry) {
                  final values = entry.value;

                  final absent = values['unexcused']!;
                  final excused = values['excused']!;
                  final present = values['present']!;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: panel,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: absent > 0
                            ? Colors.redAccent.withOpacity(0.4)
                            : Colors.white10,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: statistic(
                                'Н/У пропуски',
                                '$absent ч.',
                                Colors.redAccent,
                              ),
                            ),
                            Expanded(
                              child: statistic(
                                'Уважительные',
                                '$excused пар',
                                Colors.lightBlueAccent,
                              ),
                            ),
                            Expanded(
                              child: statistic(
                                'Посещено',
                                '$present пар',
                                Colors.greenAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget statistic(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}
