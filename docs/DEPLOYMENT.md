# Deployment

## Verified status

No host/domain/runtime, CI/container, environment template, database connection or deployment command exists. No stack/provider is selected. No verified setup/build/deploy command can be given yet; no dependencies were installed during documentation work.

## Proposed preparation and release

Select compatible hosting/runtime/storage after architecture, region and processor decisions. Separate local/preview/staging/production identities, secrets, storage and databases. Previews use synthetic data only; never copy real reports/journals into fixtures.

Future configuration categories, not existing variable names: identity issuer/client credentials, session configuration, storage connection, canonical origin, AI/extraction adapter, provider booking adapter, notifications, observability and key management. Document server/client exposure; validate configuration without printing values. Secret templates use placeholders only.

Release: CI → preview design/wording review → staging flows/migrations → restore readiness → controlled compatible migration → deploy → synthetic smoke tests → monitoring. Roll back application without destructive schema reversal. Disable unavailable AI/uploads/bookings/community publishing instead of showing fake success.

## Launch gates and operations

- Test deployed seven-module scope/shared navigation; visibly label unavailable planned modules.
- Verify owner authorization, scoped consent/revocation, community isolation and private caching.
- Validate quarantine/extraction/user review and vendor lifecycle before real uploads.
- Review PCOS non-diagnostic wording, estimate limits, sourced education/reviewer metadata and AI evaluation.
- Verify provider provenance/callback signatures, request-versus-confirmation and recipient-approved sharing before real bookings.
- Staff moderation and implement guidelines/anti-spam/report/block/appeal handling before community publication.
- Verify keyboard/screen reader/contrast/reduced-motion/mobile behavior and measured performance.
- Review TLS/encryption/key access, safe logs, retention/deletion, expiring exports, backup restore, incident ownership and rollback.

Monitor health-free failures/latency/job state, never payloads. Assign content, moderation, incident, rotation and restoration owners. Reconcile outages without duplicate shares/bookings. Restores must reapply deletions. No compliance/security/clinical validation is established.

Pending: host/region/domain, runtime versions, cost, availability/recovery budgets, retention/backup expiry and release/support owners. See [Roadmap](PIPELINE.md) and [Testing](TESTING.md).
