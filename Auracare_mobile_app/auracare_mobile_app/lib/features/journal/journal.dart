import 'package:flutter/material.dart';

import '../../core/widgets.dart';
import '../../data/records.dart';
import '../timeline/timeline.dart';

class JournalPage extends StatelessWidget {
  const JournalPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Private journal'),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(demoBadgeHeight(context)),
        child: DemoBadge(),
      ),
    ),
    body: const SafeArea(
      top: false,
      child: TimelinePage(onlyType: EntryType.journal),
    ),
  );
}
