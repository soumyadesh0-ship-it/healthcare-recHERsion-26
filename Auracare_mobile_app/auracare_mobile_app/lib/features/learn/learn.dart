import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../app/theme.dart';
import '../../data/services.dart';
import '../appointments/appointments.dart';

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});
  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String query = '';
  String category = 'All';
  @override
  Widget build(BuildContext context) {
    final resources = SessionScope.of(context).resources.resources;
    final filtered = resources.where(
      (r) =>
          r.topic.toLowerCase().contains(query.toLowerCase()) &&
          (category == 'All' || r.topic == category),
    );
    return ListView(
      key: const PageStorageKey('learn'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        const Heading('Learn'),
        const Text(
          "Women's Health Library · structural previews. Medical articles, sources and clinical reviews have not been supplied.",
        ),
        TextField(
          key: const ValueKey('resource-search'),
          decoration: const InputDecoration(
            labelText: 'Search topics',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() => query = v),
        ),
        DropdownButtonFormField<String>(
          itemHeight: null,
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Topic filter'),
          items: ['All', ...resources.map((r) => r.topic)]
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => category = v!),
        ),
        if (filtered.isEmpty)
          const EmptyNotice(
            'No matching topics',
            'Try a broader search or choose All.',
          ),
        for (final r in filtered)
          ActionCard(
            color: Palette.tiles[resources.indexOf(r) % Palette.tiles.length],
            title: r.topic,
            subtitle: 'Preview · article not available',
            icon: Icons.menu_book_outlined,
            onTap: () => pushPage(context, ResourcePage(resource: r)),
          ),
      ]),
    );
  }
}

class ResourcePage extends StatelessWidget {
  const ResourcePage({super.key, required this.resource});
  final ResourcePreview resource;
  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Topic preview',
    children: [
      Heading(resource.topic),
      const Panel(
        child: Text(
          'Structural preview — not medical guidance. No verified article or source URL is available for this topic.',
        ),
      ),
      const Text(
        'Review status: not reviewed. Reviewer and review date: unavailable. No medical endorsement is claimed.',
      ),
      const Text(
        'This space will hold accessible explanations, references and revision history after editorial review. For now, prepare a question in your own words.',
      ),
      FilledButton(
        onPressed: () {
          SessionScope.of(context).addQuestion(resource.question);
          tell(context, 'Question added to appointment preparation');
        },
        child: const Text('Add consultation question'),
      ),
      OutlinedButton(
        onPressed: () => pushPage(context, const AppointmentPage()),
        child: const Text('Open appointment preparation'),
      ),
      const Text(
        'Copy source link unavailable: no verified local source URL was supplied.',
      ),
    ],
  );
}
