import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../data/records.dart';
import 'editor.dart';

/// Keeps each category's draft mounted while the Home sections are collapsed.
/// EntryEditor remains the sole form, validation and repository-write path.
class InlineLogEntry extends StatefulWidget {
  const InlineLogEntry({super.key});

  @override
  State<InlineLogEntry> createState() => _InlineLogEntryState();
}

class _InlineLogEntryState extends State<InlineLogEntry>
    with AutomaticKeepAliveClientMixin {
  final revisions = <EntryType, int>{};
  final draftStorage = <EntryType, PageStorageBucket>{};

  @override
  bool get wantKeepAlive => true;

  void clear(EntryType type) {
    FocusScope.of(context).unfocus();
    setState(() {
      revisions[type] = (revisions[type] ?? 0) + 1;
      draftStorage[type] = PageStorageBucket();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final category in const [
          ('Spotting', EntryType.spotting, Icons.grain, Palette.orchid),
          (
            'Discharge',
            EntryType.discharge,
            Icons.opacity_outlined,
            Palette.apricot,
          ),
          (
            'Symptoms',
            EntryType.symptom,
            Icons.waves_outlined,
            Palette.turquoise,
          ),
          (
            'Period',
            EntryType.bleeding,
            Icons.water_drop_outlined,
            Palette.pink,
          ),
          (
            'Mood & wellbeing',
            EntryType.wellness,
            Icons.spa_outlined,
            Palette.lavender,
          ),
          ('Journal', EntryType.journal, Icons.edit_note, Palette.blue),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: Palette.input,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey('inline-category-${category.$2.name}'),
                maintainState: true,
                shape: const Border(),
                collapsedShape: const Border(),
                leading: Icon(category.$3, color: category.$4),
                title: Text(
                  category.$1,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  PageStorage(
                    bucket: draftStorage.putIfAbsent(
                      category.$2,
                      PageStorageBucket.new,
                    ),
                    child: EntryEditor(
                      key: ValueKey(
                        'inline-editor-${category.$2.name}-${revisions[category.$2] ?? 0}',
                      ),
                      type: category.$2,
                      inline: true,
                      showCalendar: false,
                      allowNotes: true,
                      onSaved: () => clear(category.$2),
                      onCancelled: () => clear(category.$2),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
