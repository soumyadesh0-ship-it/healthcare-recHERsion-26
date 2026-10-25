import 'package:flutter/material.dart';

import '../data/records.dart';
import '../data/services.dart';

class DemoSession extends ChangeNotifier {
  DemoSession({DemoRecordsRepository? records})
    : records = records ?? DemoRecordsRepository() {
    this.records.addListener(notifyListeners);
  }
  final DemoRecordsRepository records;
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
    records.removeListener(notifyListeners);
    records.dispose();
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
