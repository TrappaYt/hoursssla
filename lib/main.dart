import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

const Color appBackground = Color(0xFF0F0F1A);
const Color cardBackground = Color(0xFF1E1E2E);
const Color accentColor = Color(0xFF6C5CE7);
const int absenceLimit = 36;
const int initialAbsenceHours = 22;

// 12 октября 2026 — понедельник. Сверь с официальным расписанием:
// true, если неделя, начинающаяся 12 октября, чётная; иначе false.
final DateTime weekAnchor = DateTime(2026, 10, 12);
const bool anchorWeekIsEven = true;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const settings = InitializationSettings(android: androidSettings);
  await notifications.initialize(settings);

  final androidPlugin = notifications.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.requestNotificationsPermission();

  runApp(const AttendanceApp());
}

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

  String get id => '$time::$subject';
}

class AttendanceApp extends StatelessWidget {
  const AttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Моя посещаемость',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: appBackground,
        primaryColor: accentColor,
        cardColor: cardBackground,
        colorScheme: const ColorScheme.dark(
          primary: accentColor,
          secondary: Color(0xFFFF7675),
          surface: cardBackground,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: appBackground,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AttendanceHome(),
    );
  }
}

class AttendanceHome extends StatefulWidget {
  const AttendanceHome({super.key});

  @override
  State<AttendanceHome> createState() => _AttendanceHomeState();
}

class _AttendanceHomeState extends State<AttendanceHome> {
  int _tab = 0;
  int _historicalHours = initialAbsenceHours;
  DateTime _selectedDate = DateTime(2026, 10, 13);
  final Map<String, String> _statuses = {};
  bool _loading = true;

  static const List<String> _quotes = [
    'закон суров, но пары сами себя не прогуляют.',
    'презумпция невиновности. особенно до переклички.',
    'лучше знать статью, чем объяснять отсутствие.',
    'судья простит многое. деканат не факт.',
    'одна пара сегодня дешевле пересдачи завтра.',
    'адвокат дьявола, студент юридического факультета.',
    'право на отдых не равно праву на пропуск.',
    'пункт первый: не паниковать. пункт второй: учиться.',
    '36 часов свободы. расходуй с умом.',
    'доказательства присутствия: конспект и живой взгляд.',
    'ваша честь, будильник не был надлежащим образом уведомлён.',
    'сильная позиция начинается с присутствия на семинаре.',
    'не всё потеряно, пока не закрыта ведомость.',
    'обжаловать можно многое. пропущенную пару — не всегда.',
  ];

  String get _dailyQuote {
    final now = DateTime.now();
    final dayNumber = DateTime(now.year, now.month, now.day)
        .difference(DateTime(2026, 1, 1))
        .inDays;
    return _quotes[dayNumber.abs() % _quotes.length];
  }

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  bool _isEvenWeek(DateTime date) {
    final monday = DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: date.weekday - DateTime.monday));
    final anchorMonday = DateTime(
      weekAnchor.year,
      weekAnchor.month,
      weekAnchor.day,
    );
    final weekOffset = monday.difference(anchorMonday).inDays ~/ 7;
    return anchorWeekIsEven ? weekOffset.isEven : weekOffset.isOdd;
  }

  // Расписание ИЮЮР24-08. Сверь чётность недель с расписанием кафедры.
  List<Lesson> _lessonsFor(DateTime date) {
    final isEven = _isEvenWeek(date);
    final result = <Lesson>[];

    switch (date.weekday) {
      case DateTime.monday:
        result.addAll([
          const Lesson(time: '10:05 — 11:35', subject: 'Гражданский процесс (Лекция)', room: 'ауд. 1/238', type: 'Лек.'),
          const Lesson(time: '11:40 — 13:10', subject: 'Финансовое право', room: 'ауд. 1/321', type: 'Сем.'),
        ]);
        break;
      case DateTime.tuesday:
        result.addAll([
          const Lesson(time: '10:05 — 11:35', subject: 'Уголовный процесс (Лекция)', room: 'ауд. 1/238', type: 'Лек.'),
          const Lesson(time: '11:40 — 13:10', subject: 'Административное право', room: 'ауд. 1/408', type: 'Сем.'),
        ]);
        break;
      case DateTime.wednesday:
        if (isEven) {
          result.add(const Lesson(time: '10:05 — 11:35', subject: 'Уголовное право (Особ. часть — Лекция)', room: 'ауд. 1/238', type: 'Лек.'));
        }
        result.addAll([
          const Lesson(time: '11:40 — 13:10', subject: 'Гражданское право (Особ. часть)', room: 'ауд. 1/409', type: 'Сем.'),
          const Lesson(time: '13:30 — 15:00', subject: 'Уголовный процесс', room: 'ауд. 1/409', type: 'Сем.'),
        ]);
        break;
      case DateTime.thursday:
        result.addAll([
          const Lesson(time: '08:30 — 10:00', subject: 'Криминалистика', room: 'ауд. 5/611а', type: 'Сем.'),
          const Lesson(time: '10:05 — 11:35', subject: 'Гражданское право (Особ. часть)', room: 'ауд. 1/408', type: 'Сем.'),
          const Lesson(time: '11:40 — 13:10', subject: 'Финансовое право (Лекция)', room: 'ауд. 1/238', type: 'Лек.'),
        ]);
        break;
      case DateTime.friday:
        result.addAll([
          const Lesson(time: '08:30 — 10:00', subject: 'Конституционные основы труда', room: 'дистанционно', type: 'Сем.'),
          Lesson(
            time: '10:05 — 11:35',
            subject: isEven ? 'Административное право (Лекция)' : 'Психология проф. деятельности (Лекция)',
            room: 'ауд. 1/238',
            type: 'Лек.',
          ),
          const Lesson(time: '11:40 — 13:10', subject: 'Уголовное право (Особ. часть)', room: 'ауд. 1/408', type: 'Сем.'),
          const Lesson(time: '13:30 — 15:00', subject: 'Конституционные основы труда (Лекция)', room: 'дистанционно', type: 'Лек.'),
        ]);
        break;
      case DateTime.saturday:
        result.add(const Lesson(time: '10:05 — 11:35', subject: 'Уголовный процесс', room: 'ауд. 1/321', type: 'Сем.'));
        if (isEven) {
          result.add(const Lesson(time: '11:40 — 13:10', subject: 'Гражданское право (Особ. часть — Лекция)', room: 'ауд. 1/238', type: 'Лек.'));
        }
        break;
    }
    return result;
  }

  String _statusKey(DateTime date, Lesson lesson) =>
      '${_dateKey(date)}::${lesson.id}';

  int get _trackedHours =>
      _statuses.values.where((value) => value == 'unexcused').length * 2;

  int get _totalHours => _historicalHours + _trackedHours;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final rawStatuses = prefs.getString('attendance.statuses');
    if (rawStatuses != null) {
      try {
        final decoded = jsonDecode(rawStatuses) as Map<String, dynamic>;
        _statuses.addAll(
          decoded.map((key, value) => MapEntry(key, value.toString())),
        );
      } catch (_) {
        _statuses.clear();
      }
    }

    final oldHistorical = prefs.getInt('attendance.historicalHours');
    final oldTotal = prefs.getInt('unexcusedHours');
    if (oldHistorical != null) {
      _historicalHours = oldHistorical.clamp(0, absenceLimit).toInt();
    } else if (oldTotal != null) {
      _historicalHours = (oldTotal - _trackedHours)
          .clamp(0, absenceLimit)
          .toInt();
    } else {
      _historicalHours = initialAbsenceHours;
    }

    // Защита от старых или повреждённых данных, превышающих лимит.
    if (_trackedHours > absenceLimit) {
      final unexcusedKeys = _statuses.entries
          .where((entry) => entry.value == 'unexcused')
          .map((entry) => entry.key)
          .toList();
      for (final key in unexcusedKeys.skip(absenceLimit ~/ 2)) {
        _statuses.remove(key);
      }
    }
    if (_historicalHours + _trackedHours > absenceLimit) {
      _historicalHours = (absenceLimit - _trackedHours)
          .clamp(0, absenceLimit)
          .toInt();
    }

    final savedDate = prefs.getString('attendance.selectedDate');
    if (savedDate != null) {
      _selectedDate = DateTime.tryParse(savedDate) ?? _selectedDate;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    await _saveData();
    await _scheduleNotification();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('attendance.historicalHours', _historicalHours);
    await prefs.setInt('unexcusedHours', _totalHours);
    await prefs.setString('attendance.statuses', jsonEncode(_statuses));
    await prefs.setString('attendance.selectedDate', _dateKey(_selectedDate));
    await _syncWidget();
  }

  Future<void> _syncWidget() async {
    final remaining = (absenceLimit - _totalHours).clamp(0, absenceLimit);
    try {
      await HomeWidget.saveWidgetData<int>('totalHours', _totalHours);
      await HomeWidget.saveWidgetData<int>('remainingHours', remaining);
      await HomeWidget.saveWidgetData<String>('quote', _dailyQuote);
      await HomeWidget.updateWidget(
        androidName: 'AttendanceWidgetProvider',
      );
    } catch (error) {
      debugPrint('Не удалось обновить виджет: $error');
    }
  }

  Future<void> _scheduleNotification() async {
    try {
      final location = tz.getLocation('Europe/Saratov');
      final now = tz.TZDateTime.now(location);
      var scheduled = tz.TZDateTime(location, now.year, now.month, now.day, 7, 30);
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'attendance_morning',
          'Напоминания о посещаемости',
          channelDescription: 'Ежедневное напоминание о расписании и лимите пропусков',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );
      await notifications.zonedSchedule(
        0,
        'Моя посещаемость',
        'Осталось ${absenceLimit - _totalHours} ч. до лимита пропусков. Проверь расписание!',
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (error) {
      debugPrint('Не удалось запланировать уведомление: $error');
    }
  }

  Future<void> _setStatus(String key, String newStatus) async {
    final oldStatus = _statuses[key] ?? 'none';
    if (oldStatus == newStatus) return;
    final proposed = _totalHours -
        (oldStatus == 'unexcused' ? 2 : 0) +
        (newStatus == 'unexcused' ? 2 : 0);

    if (proposed > absenceLimit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Лимит 36 часов будет превышен. Отметка не сохранена.')),
      );
      return;
    }

    setState(() {
      if (newStatus == 'none') {
        _statuses.remove(key);
      } else {
        _statuses[key] = newStatus;
      }
    });
    await _saveData();
    await _scheduleNotification();
  }

  Future<void> _setHistoricalHours(int value) async {
    final newValue = value.clamp(0, absenceLimit).toInt();
    if (newValue + _trackedHours > absenceLimit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Начальные часы вместе с новыми пропусками превышают лимит 36 часов.')),
      );
      return;
    }
    setState(() => _historicalHours = newValue);
    await _saveData();
    await _scheduleNotification();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2026, 9, 1),
      lastDate: DateTime(2026, 12, 31),
      helpText: 'Выбери учебный день',
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _saveData();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: accentColor)),
      );
    }
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [_buildScheduleTab(), _buildAnalyticsTab()],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        backgroundColor: cardBackground,
        selectedItemColor: accentColor,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _tab = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Расписание'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: 'Аналитика'),
        ],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final remaining = (absenceLimit - _totalHours).clamp(0, absenceLimit);
    final progress = (_totalHours / absenceLimit).clamp(0.0, 1.0).toDouble();
    final color = _totalHours >= 34
        ? Colors.redAccent
        : _totalHours >= 28
            ? Colors.orangeAccent
            : Colors.greenAccent;
    final lessons = _lessonsFor(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Посещаемость · ИЮЮР24-08', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withOpacity(0.45)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Невыходы без уважительной причины', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 5),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('$_totalHours', style: TextStyle(fontSize: 38, fontWeight: FontWeight.bold, color: color)),
                const Padding(padding: EdgeInsets.only(left: 6, bottom: 8), child: Text('/ 36 часов')),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: progress, minHeight: 10, color: color, backgroundColor: Colors.white10),
              ),
              const SizedBox(height: 12),
              Text('Осталось $remaining ч. · примерно ${remaining ~/ 2} пар', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('До приложения: $_historicalHours ч. · Отметки в приложении: $_trackedHours ч.', style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _editHistoricalHours,
                  icon: const Icon(Icons.edit, size: 17),
                  label: const Text('Изменить начальные часы'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          _buildQuoteCard(),
          const SizedBox(height: 16),
          Card(
            color: cardBackground,
            child: ListTile(
              leading: const Icon(Icons.calendar_month, color: accentColor),
              title: Text('${_selectedDate.day.toString().padLeft(2, '0')}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.year}'),
              subtitle: Text(_isEvenWeek(_selectedDate) ? 'Чётная неделя' : 'Нечётная неделя'),
              trailing: const Icon(Icons.edit_calendar, color: accentColor),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 14),
          const Text('Пары на выбранный день', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (lessons.isEmpty)
            const Card(color: cardBackground, child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Выходной день — пар нет'))))
          else
            ...lessons.map(_lessonCard),
        ],
      ),
    );
  }

  Widget _buildQuoteCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF29234A), Color(0xFF1E1E2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accentColor.withOpacity(0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.format_quote, color: Color(0xFFA29BFE), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ЦИТАТА ДНЯ', style: TextStyle(color: Color(0xFFA29BFE), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 6),
                  Text(_dailyQuote, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _lessonCard(Lesson lesson) {
    final key = _statusKey(_selectedDate, lesson);
    final status = _statuses[key] ?? 'none';
    final statusLabel = switch (status) {
      'present' => 'Присутствовал',
      'excused' => 'Уважительная причина',
      'unexcused' => 'Н/У пропуск (+2 ч)',
      _ => 'Не отмечено',
    };
    final statusColor = switch (status) {
      'present' => Colors.greenAccent,
      'excused' => Colors.lightBlueAccent,
      'unexcused' => Colors.redAccent,
      _ => Colors.grey,
    };

    return Card(
      color: cardBackground,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: statusColor.withOpacity(0.4))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(lesson.time, style: const TextStyle(color: Color(0xFFA29BFE), fontWeight: FontWeight.bold))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: lesson.type == 'Лек.' ? Colors.orange.withOpacity(0.15) : Colors.white10, borderRadius: BorderRadius.circular(7)),
              child: Text(lesson.type, style: TextStyle(color: lesson.type == 'Лек.' ? Colors.orangeAccent : Colors.white70, fontSize: 11)),
            ),
          ]),
          const SizedBox(height: 7),
          Text(lesson.subject, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(lesson.room, style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
          const SizedBox(height: 9),
          Row(children: [
            Icon(Icons.circle, size: 9, color: statusColor),
            const SizedBox(width: 7),
            Expanded(child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12))),
            TextButton(onPressed: () => _showStatusDialog(key, lesson, status), child: const Text('Отметить')),
          ]),
        ]),
      ),
    );
  }

  Future<void> _showStatusDialog(String key, Lesson lesson, String currentStatus) async {
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: cardBackground,
        title: Text(lesson.subject, style: const TextStyle(fontSize: 16)),
        children: [
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'present'), child: const Text('Был на паре · 0 ч.', style: TextStyle(color: Colors.greenAccent))),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'excused'), child: const Text('Уважительная причина · 0 ч.', style: TextStyle(color: Colors.lightBlueAccent))),
          SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'unexcused'), child: const Text('Н/У пропуск · +2 ч.', style: TextStyle(color: Colors.redAccent))),
          if (currentStatus != 'none')
            SimpleDialogOption(onPressed: () => Navigator.pop(dialogContext, 'none'), child: const Text('Снять отметку')),
        ],
      ),
    );
    if (selected != null) await _setStatus(key, selected);
  }

  Future<void> _editHistoricalHours() async {
    final controller = TextEditingController(text: '$_historicalHours');
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: cardBackground,
        title: const Text('Начальные пропуски'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Часы до приложения', helperText: 'Например, 22'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed != null && parsed >= 0 && parsed <= absenceLimit) {
                Navigator.pop(dialogContext, parsed);
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await _setHistoricalHours(value);
  }

  Widget _buildAnalyticsTab() {
    final Map<String, Map<String, int>> stats = {};
    final Map<String, String> subjectByLessonId = {};

    for (var month = 9; month <= 12; month++) {
      final days = DateTime(2026, month + 1, 0).day;
      for (var day = 1; day <= days; day++) {
        final date = DateTime(2026, month, day);
        for (final lesson in _lessonsFor(date)) {
          subjectByLessonId['${_dateKey(date)}::${lesson.id}'] = lesson.subject;
        }
      }
    }

    for (final entry in _statuses.entries) {
      final subject = subjectByLessonId[entry.key];
      if (subject == null) continue;
      final item = stats.putIfAbsent(subject, () => {'unexcusedHours': 0, 'excusedPairs': 0, 'presentPairs': 0});
      if (entry.value == 'unexcused') item['unexcusedHours'] = item['unexcusedHours']! + 2;
      if (entry.value == 'excused') item['excusedPairs'] = item['excusedPairs']! + 1;
      if (entry.value == 'present') item['presentPairs'] = item['presentPairs']! + 1;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Аналитика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cardBackground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Общая статистика', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _analyticsRow('Начальные пропуски', '$_historicalHours ч.', Colors.white70),
                _analyticsRow('Отмечено в приложении', '$_trackedHours ч.', Colors.redAccent),
                _analyticsRow('Всего', '$_totalHours / $absenceLimit ч.', _totalHours >= 34 ? Colors.redAccent : accentColor),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          if (stats.isEmpty)
            const Padding(padding: EdgeInsets.all(28), child: Center(child: Text('Пока нет отметок посещаемости')))
          else
            ...stats.entries.map((entry) {
              final values = entry.value;
              return Card(
                color: cardBackground,
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(entry.key, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(spacing: 18, runSpacing: 10, children: [
                      _badge('Н/У пропуски', '${values['unexcusedHours']} ч.', Colors.redAccent),
                      _badge('Уважительные', '${values['excusedPairs']} пар', Colors.lightBlueAccent),
                      _badge('Посещено', '${values['presentPairs']} пар', Colors.greenAccent),
                    ]),
                  ]),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _analyticsRow(String label, String value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ]),
      );

  Widget _badge(String label, String value, Color color) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
}
