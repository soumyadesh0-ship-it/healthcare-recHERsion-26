import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../core/topic_illustration.dart';
import '../../app/theme.dart';
import '../../data/services.dart';
import '../../data/articles.dart';
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
          (r.article?.searchableText ?? r.topic.toLowerCase()).contains(
            query.toLowerCase(),
          ) &&
          (category == 'All' || r.topic == category),
    );
    return ListView(
      key: const PageStorageKey('learn'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        const Heading('Learn'),
        const Text(
          'Health information for every stage. Source-linked educational drafts; clinical editorial review pending.',
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
            subtitle: r.article == null
                ? 'Needs editorial review · article unavailable'
                : 'Read article · source-linked education',
            leading: TopicIllustration(topic: r.topic),
            onTap: () => pushPage(context, ResourcePage(resource: r)),
          ),
      ]),
    );
  }
}

class ResourcePage extends StatelessWidget {
  const ResourcePage({super.key, required this.resource});
  final ResourcePreview resource;
  Future<void> openSource(BuildContext context, String url) async {
    try {
      final opened = await const MethodChannel('org.auracare/links')
          .invokeMethod<bool>('open', url);
      if (opened != true && context.mounted) {
        tell(context, 'Browser unavailable. Use Copy link to read the source.');
      }
    } catch (_) {
      if (context.mounted) {
        tell(context, 'Browser unavailable. Use Copy link to read the source.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final article = resource.article;
    return PageFrame(
      title: resource.topic,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TopicIllustration(topic: resource.topic),
        ),
        Heading(resource.topic),
        if (article == null)
          const EmptyNotice(
            'Editorial review needed',
            'Verified article content has not been supplied for this topic.',
          )
        else ...[
          Text(article.introduction),
          const Text(EducationalArticle.disclaimer),
          for (final section in article.sections) ...[
            Text(
              section.heading,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SelectableText(section.body),
          ],
          Text(
            'Frequently asked',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(article.question),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(article.answer),
              ),
            ],
          ),
          Text(
            'References & further reading',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Sources checked ${EducationalArticle.checkedOn}. This is a source-check date, not a clinical review or endorsement. Local service details in these international sources may differ.',
          ),
          for (final source in article.sources)
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  SelectableText(source.url),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => openSource(context, source.url),
                        child: const Text('Open source'),
                      ),
                      TextButton(
                        onPressed: () => copyText(context, source.url),
                        child: const Text('Copy link'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
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
      ],
    );
  }
}
