import 'package:flutter/material.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(const AttendanceApp());
}

class Lesson {
  final String time;
  final String subject;
  final String room;
  final String type; // Сем. / Лек.

  Lesson({
    required this.time,
    required this.subject,
    required this.room,
    required this.type,
  });
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Учет Пропусков СГЮА',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        primaryColor: const Color(0xFF6C5CE7),
        cardColor: const Color(0xFF1E1E2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFFFF7675),
          surface: Color(0xFF1E1E2E),
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

  // Хранилище статусов отметок
  final Map<String, String> pairStatus = {};

  // Автоматическое определение чётности недели (Опорная точка: 13 октября 2026 — чётная неделя)
  bool get isEvenWeek {
    int diffDays = selectedDate.difference(DateTime(2026, 10, 13)).inDays;
    int weekOffset = diffDays ~/ 7;
    if (diffDays < 0 && diffDays % 7 != 0) {
      weekOffset -= 1;
    }
    return weekOffset % 2 == 0;
  }

  // Расписание: Четность -> День Недели -> Список Пар с Аудиториями
  final Map<bool, Map<int, List<Lesson>>> masterSchedule = {
    // ЧЕТНАЯ НЕДЕЛЯ (True)
    true: {
      DateTime.monday: [
        Lesson(time: "11:40 — 13:10", subject: "Финансовое право", room: "каб. 402", type: "Сем."),
      ],
      DateTime.tuesday: [
        Lesson(time: "11:40 — 13:10", subject: "Административное право", room: "каб. 315", type: "Сем."),
      ],
      DateTime.wednesday: [
        Lesson(time: "11:40 — 13:10", subject: "Гражданский процесс", room: "каб. 501", type: "Сем."),
        Lesson(time: "13:30 — 15:00", subject: "Уголовный процесс", room: "каб. 508", type: "Сем."),
      ],
      DateTime.thursday: [
        Lesson(time: "08:30 — 10:00", subject: "Криминалистика", room: "каб. 210", type: "Сем."),
        Lesson(time: "10:05 — 11:35", subject: "Гражданское право", room: "каб. 412", type: "Сем."),
      ],
      DateTime.friday: [
        Lesson(time: "08:30 — 10:00", subject: "Конституционное право", room: "каб. 302", type: "Сем."),
        Lesson(time: "11:40 — 13:10", subject: "Уголовное право", room: "каб. 408", type: "Сем."),
      ],
      DateTime.saturday: [
        Lesson(time: "10:05 — 11:35", subject: "Гражданское право", room: "каб. 412", type: "Сем."),
      ],
    },
    // НЕЧЕТНАЯ НЕДЕЛЯ (False)
    false: {
      DateTime.monday: [
        Lesson(time: "08:30 — 10:00", subject: "Финансовое право", room: "Ауд. 1 (Лекция)", type: "Лек."),
        Lesson(time: "11:40 — 13:10", subject: "Финансовое право", room: "каб. 402", type: "Сем."),
      ],
      DateTime.tuesday: [
        Lesson(time: "10:05 — 11:35", subject: "Административное право", room: "каб. 315", type: "Сем."),
      ],
      DateTime.wednesday: [
        Lesson(time: "11:40 — 13:10", subject: "Гражданский процесс", room: "каб. 501", type: "Сем."),
      ],
      DateTime.thursday: [
        Lesson(time: "08:30 — 10:00", subject: "Криминалистика", room: "каб. 210", type: "Сем."),
      ],
      DateTime.friday: [
        Lesson(time: "11:40 — 13:10", subject: "Уголовное право", room: "каб. 408", type: "Сем."),
      ],
      DateTime.saturday: [
        Lesson(time: "10:05 — 11:35", subject: "Гражданское право", room: "каб. 412", type: "Сем."),
      ],
    }
  };

  final List<String> quotes = [
    "«Дисциплина — это выбор между тем, чего ты хочешь сейчас, и тем, чего ты хочешь больше всего.»",
    "«Лучшая защита от проблем на сессии — твое присутствие на парах.»",
    "«Юрист должен знать законы, а студент ИЮЮР24-08 — беречь лимит пропусков!»",
    "«Каждый час прогула уменьшает твой запас прочности перед зачетами.»",
  ];

  // По умолчанию открываем сегодняшний день (13 октября 2026 или текущую дату)
  DateTime selectedDate = DateTime(2026, 10, 13);

  @override
  void initState() {
    super.initState();
    _scheduleMorningNotification();
  }

  Future<void> _scheduleMorningNotification() async {
    final tz.Location saratovLocation = tz.getLocation('Europe/Saratov');
    final tz.TZDateTime now = tz.TZDateTime.now(saratovLocation);
    
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(saratovLocation, now.year, now.month, now.day, 7, 30);
    
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_attendance_channel',
      'Утренние напоминания',
      channelDescription: 'Напоминания о парах и лимите пропусков',
      importance: Importance.high,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'СГЮА | Пары на сегодня',
      'Проверь расписание и кабинеты! У тебя осталось ${maxHours - unexcusedHours} ч. пропусков.',
      scheduledDate,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  void _addPairToCalendar(Lesson lesson) {
    final Event event = Event(
      title: '${lesson.subject} (${lesson.type})',
      description: 'Занятие группы ИЮЮР24-08 в ${lesson.room}',
      location: 'СГЮА, ${lesson.room}',
      startDate: selectedDate,
      endDate: selectedDate.add(const Duration(hours: 1, minutes: 30)),
      timeZone: 'Europe/Saratov',
    );
    Add2Calendar.addEvent2Calendar(event);
  }

  @override
  Widget build(BuildContext context) {
    double progress = (unexcusedHours / maxHours).clamp(0.0, 1.0);
    Color statusColor = Colors.greenAccent;
    if (unexcusedHours >= 28) statusColor = Colors.orangeAccent;
    if (unexcusedHours >= 34) statusColor = Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Трекер Пропусков | ИЮЮР24-08',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Карточка Прогресса
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF1E1E2E),
                    statusColor.withOpacity(0.15),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
              ),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Лимит Н/У пропусков",
                              style: TextStyle(color: Colors.grey, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("Статус посещаемости",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$unexcusedHours / $maxHours ч",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                      backgroundColor: Colors.white10,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Осталось: ${maxHours - unexcusedHours} ч.",
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      Text(
                        "Запас: ${(maxHours - unexcusedHours) ~/ 2} пар",
                        style: TextStyle(
                            color: statusColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Цитата
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF6C5CE7).withOpacity(0.3)),
              ),
              child: Text(
                quotes[unexcusedHours % quotes.length],
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    fontSize: 12.5,
                    color: Color(0xFFA29BFE)),
              ),
            ),

            const SizedBox(height: 20),

            // Индикатор недели и выбор даты
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C5CE7).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6C5CE7)),
                  ),
                  child: Text(
                    isEvenWeek ? "🗓 Неделя: Четная (II)" : "🗓 Неделя: Нечетная (I)",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Color(0xFFA29BFE), fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today,
                      color: Color(0xFF6C5CE7)),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2026, 9, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              "Расписание на ${selectedDate.day}.${selectedDate.month}.${selectedDate.year}",
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),

            const SizedBox(height: 12),

            // Список пар
            _buildPairsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildPairsList() {
    Map<int, List<Lesson>> scheduleForWeek = masterSchedule[isEvenWeek]!;
    List<Lesson>? dayLessons = scheduleForWeek[selectedDate.weekday];
    String dateStr =
        "${selectedDate.year}-${selectedDate.month}-${selectedDate.day}";

    if (dayLessons == null || dayLessons.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          children: [
            Icon(Icons.bedtime_outlined, color: Colors.grey, size: 36),
            SizedBox(height: 8),
            Text("Выходной день — пар нет!",
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ],
        ),
      );
    }

    return Column(
      children: dayLessons.map((lesson) {
        String key = "${dateStr}_${lesson.subject}_${lesson.time}";
        String status = pairStatus[key] ?? "none";

        Color cardBorder = Colors.white10;
        String statusLabel = "Не отмечено";
        IconData statusIcon = Icons.radio_button_unchecked;
        Color iconColor = Colors.grey;

        if (status == "present") {
          cardBorder = Colors.greenAccent.withOpacity(0.5);
          statusLabel = "Присутствовал";
          statusIcon = Icons.check_circle;
          iconColor = Colors.greenAccent;
        } else if (status == "excused") {
          cardBorder = Colors.lightBlueAccent.withOpacity(0.5);
          statusLabel = "Уважительная причина";
          statusIcon = Icons.info;
          iconColor = Colors.lightBlueAccent;
        } else if (status == "unexcused") {
          cardBorder = Colors.redAccent.withOpacity(0.5);
          statusLabel = "Н/У пропуск (+2ч)";
          statusIcon = Icons.warning;
          iconColor = Colors.redAccent;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Icon(statusIcon, color: iconColor, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(lesson.time,
                              style: const TextStyle(
                                  color: Color(0xFFA29BFE),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(lesson.type,
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(lesson.subject,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.meeting_room,
                              size: 13, color: Colors.amberAccent),
                          const SizedBox(width: 4),
                          Text(lesson.room,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.amberAccent)),
                          const SizedBox(width: 10),
                          Text("•  $statusLabel",
                              style: TextStyle(
                                  fontSize: 11, color: iconColor)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.calendar_add_on,
                          color: Colors.white54, size: 20),
                      onPressed: () => _addPairToCalendar(lesson),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit,
                          color: Color(0xFF6C5CE7), size: 20),
                      onPressed: () => _showMarkDialog(key, lesson),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showMarkDialog(String key, Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(lesson.subject,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text("Отметь статус для аудитории ${lesson.room}:"),
        actions: [
          TextButton(
            onPressed: () {
              _updatePairStatus(key, "present");
              Navigator.pop(context);
            },
            child: const Text("Был (0 ч)",
                style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () {
              _updatePairStatus(key, "excused");
              Navigator.pop(context);
            },
            child: const Text("Уважительная (0 ч)",
                style: TextStyle(color: Colors.lightBlueAccent)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              _updatePairStatus(key, "unexcused");
              Navigator.pop(context);
            },
            child: const Text("Н/У (+2 ч)"),
          ),
        ],
      ),
    );
  }

  void _updatePairStatus(String key, String newStatus) {
    setState(() {
      String oldStatus = pairStatus[key] ?? "none";

      if (oldStatus == "unexcused") {
        unexcusedHours = (unexcusedHours - 2).clamp(0, maxHours);
      }

      if (newStatus == "unexcused") {
        if (unexcusedHours + 2 <= maxHours) {
          unexcusedHours += 2;
        }
      }

      pairStatus[key] = newStatus;
    });
  }
}
