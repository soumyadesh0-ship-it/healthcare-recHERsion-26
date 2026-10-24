# Security and privacy

## Verified status

No authentication, authorization, data collection, consent system, encryption configuration, secure storage, backup or security test exists. Requirements below are proposed. No compliance or certification is established.

## Access, consent and isolation

Authenticate with a reviewed session lifecycle; authorize ownership/role/purpose server-side on each request and queued job. Derive owner from session. Shared identity/navigation does not grant universal health access. Use least privilege for services/staff/processors, session expiry/revocation, secure HttpOnly cookies where appropriate and CSRF/origin controls.

Purpose-specific consent identifies selected records/versions, processing purpose, recipient and policy version. Optional uses can be refused/withdrawn. AI processing, summarization and clinician delivery are separate permissions; changed payloads need renewed approval. Show grants and sharing history. Journals remain private by default and cannot be disclosed to clinicians/community without explicit consent and action. Sisterhood offers no automatic private-record sharing path, including through existing AI/clinic permissions.

Community services/search/moderators cannot access period history, PCOS information, reports, journals, appointment summaries or AI conversations. Separate community IDs with restricted internal account linkage. No composer prefill, private attachments, private-history topic inference or health details in profiles. Pseudonymity is not complete anonymity: account/network metadata, volunteered details and screenshots can identify users. Reporting/blocking, anti-spam and harassment/doxxing/misinformation procedures require real tools/staff before launch.

## Required controls

| Area | Requirement, not implemented |
| --- | --- |
| Minimization | Purpose per field, optional logs, minimal identity; no unnecessary address/birth/anatomy collection |
| Transport/storage | HTTPS/TLS, reviewed encryption at rest/key permissions, private data/storage and expiring owner-authorized downloads |
| Files | Type/size validation, quarantine/malware checks, extraction isolation, protected objects and user review before reliance |
| Injection/abuse | Server validation, parameterized access, safe rendering/sanitization, rate limits and signed/replay-protected provider callbacks |
| Caches/logs | Private/no-store health responses; no health text in URLs, logs, errors, analytics, crash reports or session replay; minimal restricted audit metadata |
| Secrets | Server-only secret management, rotation and isolated environments; future templates use placeholders only |
| Operations | Restricted audited admin/support access, encrypted backups, restore exercises and incident owners |

No advertising trackers/session replay in private routes. Vendors receive only authorized minimum data after processor/retention/training/deletion review. Opt-in reminder bodies remain neutral, including on lock screens.

## Correction, retention and deletion

Support access, correction, selected export and deletion with visible lifecycle status. Source changes invalidate affected derived summaries. Remove eligible files/findings/indices/conversations/pending jobs/exports. Revocation prevents future access but cannot undo downloaded/delivered copies; disclose before sharing.

Define per-entity retention/justified exceptions before collection, including community authorship/moderation evidence, consent/audit metadata, processors and backups. Do not promise immediate removal from immutable backups. Set backup expiry and restore procedures that reapply deletion tombstones before serving records. Display truthful pending/completed states and limitations rather than silent indefinite retention.

## Verification and decisions

Test cross-user operations/downloads/jobs, grant revocation, moderator/community isolation, cache leaks, malicious uploads/prompt injection, logging, deletion propagation and restore. See [Testing](TESTING.md).

Open: jurisdiction/legal basis, age policy, controller/processors, residency, retention/backup schedules, recovery objectives, incident response and reviewed privacy notice. No legal or clinical compliance claim is supported.
