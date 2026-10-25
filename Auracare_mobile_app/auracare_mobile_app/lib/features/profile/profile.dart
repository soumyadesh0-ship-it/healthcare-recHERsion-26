import 'package:flutter/material.dart';

import '../../app/auth_service.dart';
import '../../app/session.dart';
import '../../core/widgets.dart';
import '../../core/characters.dart';
import '../../app/theme.dart';
import '../timeline/timeline.dart';
import '../cycle/cycle.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, this.onSignOut, this.authUser});
  final Future<void> Function()? onSignOut;
  final AuthUser? authUser;

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    final displayName =
        authUser?.displayName ?? authUser?.email?.split('@').first ?? 'Alex';
    return ListView(
      key: const PageStorageKey('profile'),
      padding: const EdgeInsets.all(20),
      children: spaced([
        const Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Palette.blush,
            child: Character(kind: AuraCharacter.flower, size: 78),
          ),
        ),
        Center(child: Heading(displayName)),
        Center(
          child: Text(
            authUser == null
                ? 'Fictional demo profile'
                : 'Signed in as ${authUser!.email ?? displayName}',
          ),
        ),
        if (authUser != null)
          Text(
            session.records.isRemote
                ? 'Health records use your private account storage when database deployment is enabled. Loading failures are shown above; no local fallback is used.'
                : 'Health records in this app remain local to this session and are not uploaded to your account.',
          ),
        const Divider(),
        ExpansionTile(
          title: const Text('About this demo'),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                authUser == null
                    ? 'Alex · fictional demo profile\nSession only. Health records clear when the app restarts. Onboarding completion is remembered on Android. No account, cloud storage, encryption or legal compliance is claimed.'
                    : session.records.isRemote
                    ? 'Account records are loaded from private storage. Demo records are never imported automatically.'
                    : 'This account supports sign-in and explicitly confirmed PCOS draft summaries. Other health records are synthetic, stay in this app session, clear when the app restarts, and are not uploaded or linked to your account.',
              ),
            ),
          ],
        ),
        Text(
          authUser == null
              ? 'Account connection is unavailable in this demo.'
              : 'AuraCare account authentication is connected.',
        ),
        const Divider(),
        ExpansionTile(
          title: const Text('Tracking & display'),
          leading: const Icon(Icons.tune_outlined),
          children: [
            DropdownButtonFormField<String>(
              itemHeight: null,
              initialValue: session.zone,
              decoration: const InputDecoration(
                labelText: 'Time display for new entries',
              ),
              isExpanded: true,
              items: const [
                'Device local',
                'UTC',
              ].map((z) => DropdownMenuItem(value: z, child: Text(z))).toList(),
              onChanged: (v) => session.update(() => session.zone = v!),
            ),
            const Text(
              'Device local follows the device clock; UTC uses the UTC clock. Stored entries retain their original wall-clock date and zone label. Named IANA timezone conversion is not implemented.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Optional cycle tracking'),
              subtitle: const Text('Disabling does not delete recorded days.'),
              value: session.cycleEnabled,
              onChanged: (v) => session.update(() => session.cycleEnabled = v),
            ),
            OutlinedButton(
              onPressed: () => pushPage(context, const CyclePage()),
              child: const Text('Manage cycle records'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              subtitle: const Text(
                'Also respects the system’s reduced-motion preference.',
              ),
              value: session.reduceMotion,
              onChanged: (v) => session.update(() => session.reduceMotion = v),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Privacy & preferences'),
          leading: const Icon(Icons.shield_outlined),
          children: [
            Text(
              'Purpose controls — demo preferences',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Required purpose: display/edit this synthetic session. Optional switches below are simulations, not reviewed legal consent or active services.',
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Optional reminder preference'),
              subtitle: const Text('No notifications will be scheduled.'),
              value: session.reminderPreference,
              onChanged: (v) =>
                  session.update(() => session.reminderPreference = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Optional AI-processing preference'),
              subtitle: const Text(
                'No AI calls occur. Future use needs selected-record authorization.',
              ),
              value: session.processingPreference,
              onChanged: (v) =>
                  session.update(() => session.processingPreference = v),
            ),
            const Text(
              'Journals are not automatically included in summaries. Community is unconnected and has no private-record access.',
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Your records'),
          leading: const Icon(Icons.folder_outlined),
          children: [
            ActionCard(
              title: 'Correct or delete records',
              subtitle: 'Open details from the timeline',
              icon: Icons.edit_outlined,
              onTap: () => pushPage(context, const _CorrectionPage()),
            ),
            if (!session.records.isRemote)
              FilledButton(
                onPressed: () => copyText(
                  context,
                  session.account.exportSession(session.records.entries),
                ),
                child: const Text('Copy synthetic JSON export'),
              ),
            const Text(
              'Export includes this session’s records, including journals. Copy only if intended. Clipboard content remains outside app reset. Remote export and account deletion are unavailable.',
            ),
            if (!session.records.isRemote)
              OutlinedButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Reset demo?',
                    'Clear all records, questions and optional preferences for this session. Clipboard copies are not cleared.',
                    action: 'Reset',
                  )) {
                    session.reset();
                    if (context.mounted) tell(context, 'Demo session reset');
                  }
                },
                child: const Text('Reset demo'),
              ),
            const Divider(),
          ],
        ),
        if (!session.records.isRemote)
          ExpansionTile(
            title: const Text('Demo tools'),
            leading: const Icon(Icons.science_outlined),
            children: [
              TextButton(
                onPressed: () {
                  session.records.failNextWrite = true;
                  tell(
                    context,
                    'Next record save/delete will fail once; retry preserves input.',
                  );
                },
                child: const Text('Simulate next write failure'),
              ),
              TextButton(
                onPressed: () async {
                  if (await confirm(
                    context,
                    'Load fictional samples?',
                    'Replace this session’s records with clearly fictional examples.',
                    action: 'Load samples',
                  )) {
                    session.records.reset(sample: true);
                    if (context.mounted) {
                      tell(context, 'Fictional samples loaded');
                    }
                  }
                },
                child: const Text('Load sample records'),
              ),
            ],
          ),
        const Text(
          'Self-care suggestions, reminders, account privacy lifecycles, uploads, reports, AI, moderation and live provider services await reviewed implementations.',
        ),
        if (onSignOut != null)
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await onSignOut!();
              } on AuthException catch (exception) {
                if (context.mounted) {
                  tell(context, authFailureMessage(exception.failure));
                }
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out / exit demo'),
          ),
      ]),
    );
  }
}

class _CorrectionPage extends StatelessWidget {
  const _CorrectionPage();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Correct records'),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(demoBadgeHeight(context)),
        child: DemoBadge(),
      ),
    ),
    body: const SafeArea(top: false, child: TimelinePage()),
  );
}
