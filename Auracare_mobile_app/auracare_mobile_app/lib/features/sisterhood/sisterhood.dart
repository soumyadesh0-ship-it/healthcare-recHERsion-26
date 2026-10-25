import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/widgets.dart';

class _SamplePost {
  const _SamplePost(
    this.author,
    this.category,
    this.title,
    this.body,
    this.reply, {
    this.rating,
  });
  final String author, category, title, body, reply;
  final int? rating;
}

const _posts = [
  _SamplePost(
    'Nila',
    'Stories',
    'Small steps count, too',
    'I used my journal to put a busy day into words. A short entry felt easier than trying to write everything perfectly.',
    'Mira: I like that approach. A few honest words can be enough.',
  ),
  _SamplePost(
    'Mira',
    'Reviews',
    'A calmer place to check in',
    'The gentle colours and simple mood check-in make the app easy to return to. I especially like having the journal close by.',
    'Nila: The quiet design is my favourite part, too.',
    rating: 4,
  ),
  _SamplePost(
    'Tara',
    'Feedback',
    'Make saved and temporary entries clearer',
    'The screen could explain which entries stay after closing the app. A short label near Save would help me understand what to expect.',
    'Asha: Agreed. Clear storage labels would make the experience less confusing.',
  ),
  _SamplePost(
    'Asha',
    'Stories',
    'Making room for questions',
    'I made a short list of questions before an appointment. Having them in one place helped me organise what I wanted to discuss.',
    'Tara: A question list is a useful way to prepare at your own pace.',
  ),
  _SamplePost(
    'Riya',
    'Reviews',
    'Love the pause-and-play space',
    'Merge & Unwind is a lovely little break. The pause control is useful when I need to step away. I would love an easier-to-find restart button.',
    'Mira: Good point. Controls should be easy to find before starting a round.',
    rating: 4,
  ),
  _SamplePost(
    'Sana',
    'Feedback',
    'Keep larger text comfortable',
    'Some pages need more scrolling with larger text. Keeping important actions easy to reach would make the app more comfortable to use.',
    'Riya: Larger tap targets and clear headings would help as well.',
  ),
];

class SisterhoodPage extends StatefulWidget {
  const SisterhoodPage({super.key});
  @override
  State<SisterhoodPage> createState() => _SisterhoodPageState();
}

class _SisterhoodPageState extends State<SisterhoodPage> {
  String category = 'All';
  final helpful = <int>{};
  final replies = <int>{};

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: spaced([
          const Heading('Sisterhood'),
          Text(
            'A little connection. A little encouragement.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Panel(
            color: Palette.lavender,
            child: Text(
              'Community demo · All names, posts, reviews and replies below are fictional examples. Helpful marks and reply previews work only on this screen. Nothing is published or shared.',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in ['All', 'Stories', 'Reviews', 'Feedback'])
                ChoiceChip(
                  label: Text(value),
                  selected: category == value,
                  onSelected: (_) => setState(() => category = value),
                ),
            ],
          ),
          for (var index = 0; index < _posts.length; index++)
            if (category == 'All' || _posts[index].category == category)
              postCard(index),
          const Text(
            'A kind space starts with respect. Avoid sharing identifying details or private records. Community stories are not medical advice.',
          ),
        ]),
      ),
    ),
  );

  Widget postCard(int index) {
    final post = _posts[index];
    final color = switch (post.category) {
      'Reviews' => Palette.blush,
      'Feedback' => Palette.periwinkle,
      _ => Palette.lavender,
    };
    return Panel(
      key: ValueKey('community-post-$index'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: spaced([
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                child: Text(
                  post.author.substring(0, 1),
                  style: const TextStyle(color: Palette.ink),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.author,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Fictional member · ${post.category}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(post.title, style: Theme.of(context).textTheme.titleLarge),
          if (post.rating != null)
            Text(
              'Sample review · ${post.rating}/5',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          Text(post.body),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() {
                  if (!helpful.add(index)) helpful.remove(index);
                }),
                icon: Icon(
                  helpful.contains(index)
                      ? Icons.favorite
                      : Icons.favorite_border,
                ),
                label: Text(
                  helpful.contains(index) ? 'Marked helpful' : 'Helpful',
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() {
                  if (!replies.add(index)) replies.remove(index);
                }),
                icon: const Icon(Icons.chat_bubble_outline),
                label: Text(
                  replies.contains(index)
                      ? 'Hide sample reply'
                      : 'View sample reply',
                ),
              ),
            ],
          ),
          if (replies.contains(index))
            Panel(color: color, child: Text('Fictional reply\n${post.reply}')),
        ], gap: 12),
      ),
    );
  }
}
