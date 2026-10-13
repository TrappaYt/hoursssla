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
      home: const MainContainer(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;
  
  // Общие данные приложения, доступные из обоих экранов
  int unexcusedHours = 22;
  final int maxHours = 36;
  final Map<String, String> pairStatus = {}; // Ключ: "Date_Subject_Time", Значение: "present"|"excused"|"unexcused"
  DateTime selectedDate = DateTime(2026, 10, 13);

  final Map<bool, Map<int, List<Lesson>>> masterSchedule = {
    true: { // Четная неделя
      DateTime.monday: [Lesson(time: "11:40 — 13:10", subject: "Финансовое право", room: "каб. 402", type: "Сем.")],
      DateTime.tuesday: [Lesson(time: "11:40 — 13:10", subject: "Административное право", room: "каб. 315", type: "Сем.")],
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
      DateTime.saturday: [Lesson(time: "10:05 — 11:35", subject: "Гражданское право", room: "каб. 412", type: "Сем.")],
    },
    false: { // Нечетная неделя
      DateTime.monday: [
        Lesson(time: "08:30 — 10:00", subject: "Финансовое право", room: "Ауд. 1 (Лекция)", type: "Лек."),
        Lesson(time: "11:40 — 13:10", subject: "Финансовое право", room: "каб. 402", type: "Сем."),
      ],
      DateTime.tuesday: [Lesson(time: "10:05 — 11:35", subject: "Административное право", room: "каб. 315", type: "Сем.")],
      DateTime.wednesday: [Lesson(time: "11:40 — 13:10", subject: "Гражданский процесс", room: "каб. 501", type: "Сем.")],
      DateTime.thursday: [Lesson(time: "08:30 — 10:00", subject: "Криминалистика", room: "каб. 210", type: "Сем.")],
      DateTime.friday: [Lesson(time: "11:40 — 13:10", subject: "Уголовное право", room: "каб. 408", type: "Сем.")],
      DateTime.saturday: [Lesson(time: "10:05 — 11:35", subject: "Гражданское право", room: "каб. 412", type: "Сем.")],
    }
  };

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        unexcusedHours: unexcusedHours,
        maxHours: maxHours,
        pairStatus: pairStatus,
        selectedDate: selectedDate,
        masterSchedule: masterSchedule,
        onStatusChanged: (newHours, updatedStatuses, newDate) {
          setState(() {
            unexcusedHours = newHours;
            pairStatus.clear();
            pairStatus.addAll(updatedStatuses);
            selectedDate = newDate;
          });
        },
      ),
      AnalyticsScreen(
        pairStatus: pairStatus,
        masterSchedule: masterSchedule,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        backgroundColor: const Color(0xFF1E1E2E),
        selectedItemColor: const Color(0xFF6C5CE7),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Расписание',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Аналитика',
          ),
        ],
      ),
    );
  }
}

// ЭКРАН 1: РАСПИСАНИЕ И КАЛЕНДАРЬ
class HomeScreen extends StatefulWidget {
  final int unexcusedHours;
  final int maxHours;
  final Map<String, String> pairStatus;
  final DateTime selectedDate;
  final Map<bool, Map<int, List<Lesson>>> masterSchedule;
  final Function(int, Map<String, String>, DateTime) onStatusChanged;

  const HomeScreen({
    Key? key,
    required this.unexcusedHours,
    required this.maxHours,
    required this.pairStatus,
    required this.selectedDate,
    required this.masterSchedule,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late int unexcusedHours;
  late DateTime selectedDate;
  late Map<String, String> pairStatus;

  @override
  void initState() {
    super.initState();
    unexcusedHours = widget.unexcusedHours;
    selectedDate = widget.selectedDate;
    pairStatus = Map.from(widget.pairStatus);
    _scheduleMorningNotification();
  }

  bool get isEvenWeek {
    int diffDays = selectedDate.difference(DateTime(2026, 10, 13)).inDays;
    int weekOffset = diffDays ~/ 7;
    if (diffDays < 0 && diffDays % 7 != 0) weekOffset -= 1;
    return weekOffset % 2 == 0;
  }

  final List<String> quotes = [
    "«Дисциплина — это выбор между тем, чего ты хочешь сейчас, и тем, чего ты хочешь больше всего.»",
    "«Лучшая защита от проблем на сессии — твое присутствие на парах.»",
    "«Юрист должен знать законы, а студент ИЮЮР24-08 — беречь лимит пропусков!»",
  ];

  Future<void> _scheduleMorningNotification() async {
    final tz.Location saratovLocation = tz.getLocation('Europe/Saratov');
    final tz.TZDateTime now = tz.TZDateTime.now(saratovLocation);
    tz.TZDateTime scheduledDate = tz.TZDateTime(saratovLocation, now.year, now.month, now.day, 7, 30);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_attendance_channel',
      'Утренние напоминания',
      channelDescription: 'Напоминания о парах и лимите пропусков',
      importance: Importance.high,
      priority: Priority.high,
    );
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'СГЮА | Пары на сегодня',
      'Проверь расписание! У тебя осталось ${widget.maxHours - unexcusedHours} ч. пропусков.',
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
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
    double progress = (unexcusedHours / widget.maxHours).clamp(0.0, 1.0);
    Color statusColor = Colors.greenAccent;
    if (unexcusedHours >= 28) statusColor = Colors.orangeAccent;
    if (unexcusedHours >= 34) statusColor = Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Трекер Пропусков | ИЮЮР24-08', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  colors: [const Color(0xFF1E1E2E), statusColor.withOpacity(0.15)],
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
                          Text("Лимит Н/У пропусков", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          SizedBox(height: 4),
                          Text("Статус посещаемости", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "$unexcusedHours / ${widget.maxHours} ч",
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: statusColor),
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
                      Text("Осталось: ${widget.maxHours - unexcusedHours} ч.", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                      Text("Запас: ${(widget.maxHours - unexcusedHours) ~/ 2} пар", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF6C5CE7).withOpacity(0.3)),
              ),
              child: Text(
                quotes[unexcusedHours % quotes.length],
                textAlign: TextAlign.center,
                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12.5, color: Color(0xFFA29BFE)),
              ),
            ),
            const SizedBox(height: 20),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFA29BFE), fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_today, color: Color(0xFF6C5CE7)),
                  onPressed: () async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2026, 9, 1),
                      lastDate: DateTime(2026, 12, 31),
                    );
                    if (
