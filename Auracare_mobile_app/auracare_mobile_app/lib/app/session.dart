import 'package:flutter/material.dart';

import '../data/records.dart';
import '../data/services.dart';
import '../data/appointments.dart';
import '../data/chat_service.dart';

class DemoSession extends ChangeNotifier {
  DemoSession({
    RecordsRepository? records,
    AppointmentsRepository? appointments,
    this.quizService,
    this.chatService,
  }) : records = records ?? DemoRecordsRepository(),
       appointments = appointments ?? AppointmentsRepository() {
    this.records.addListener(notifyListeners);
    this.appointments.addListener(notifyListeners);
  }
  final RecordsRepository records;
  final AuthenticatedQuizService? quizService;
  final AuthenticatedChatService? chatService;
  final AppointmentsRepository appointments;
  bool showCycleEstimates = false, unsuitableCycleEstimates = false;
  final ResourcesRepository resources = PreviewResourcesRepository();
  final AccountPrivacyService account = DemoAccountPrivacyService();
  final List<String> questions = [];
  bool cycleEnabled = false,
      reminderPreference = false,
      processingPreference = false,
      reduceMotion = false;
  String zone = 'Device local';
  int homeRequest = 0;
  void requestHome() {
    homeRequest++;
    notifyListeners();
  }

  void update(VoidCallback change) {
    change();
    notifyListeners();
  }

  void addQuestion(String q) {
    if (!questions.contains(q)) questions.add(q);
    notifyListeners();
  }

  void reset({bool sample = false}) {
    questions.clear();
    cycleEnabled = false;
    reminderPreference = false;
    processingPreference = false;
    zone = 'Device local';
    records.reset(sample: sample);
    notifyListeners();
  }

  @override
  void dispose() {
    quizService?.dispose();
    chatService?.dispose();
    records.removeListener(notifyListeners);
    records.dispose();
    appointments.removeListener(notifyListeners);
    appointments.dispose();
    super.dispose();
  }
}

class SessionScope extends InheritedNotifier<DemoSession> {
  const SessionScope({
    super.key,
    required DemoSession session,
    required super.child,
  }) : super(notifier: session);
  static DemoSession of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
