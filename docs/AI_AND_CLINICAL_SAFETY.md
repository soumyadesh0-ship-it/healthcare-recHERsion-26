# AI and clinical safety

## Status

No AI, extraction tool, rules, medical content, clinical integration, reviewer workflow or validation exists. This is a proposed product specification, not proof of clinical safety or medical advice.

## Permitted and prohibited uses

AI Assistant may explain general health information/terminology, provide genuinely sourced answers where appropriate, summarize selected records, explain uploaded terminology and prepare consultation questions. Disclose uncertainty, limits and selected context. Never diagnose, prescribe, replace a qualified professional, fabricate citations/findings/recommendations or claim emergency monitoring/clinical validation.

PCOS Insights must not calculate/display an unvalidated numerical probability or percentage chance of PCOS. Use descriptive counts, history, coverage and limitations. Absence of certain symptoms does not rule PCOS out. Distinguish user-reported history from confirmed clinical diagnoses and encourage appropriate professional assessment without predicting the outcome.

## Grounding and missing data

Verify reputable sources and that citations support the response; preserve source/version/location. Failed retrieval or conflicting evidence requires honest uncertainty, not invented recommendations. Uploaded text is untrusted input, never instructions or tool authorization. No unrestricted database access or silent expansion of selected context.

Versioned descriptive rules should show date range, counts/denominator, source versions, missing days and limitations. Synthetic example: "Headaches were recorded on 4 of 10 days with entries; days without entries are unknown." Never infer symptom absence, causation or diagnosis. Sparse/contradictory/duplicate/future-dated data produces quality/insufficient-data messages. Comparisons show coverage in both windows.

Each rule requires owner, purpose, inputs, minimum-data criteria, exclusions/thresholds, template, references where relevant, reviewer, version and regression fixtures. Thresholds remain undecided; no invented clinical cutoffs. Period estimates remain labeled estimates and never promise ovulation prediction, fertility accuracy or contraceptive reliability.

## Reports, review and sharing

Private upload → validation/quarantine/malware handling → draft extraction with original text/page/span/uncertainty → user correction/review → explicitly selected downstream use. Unreadable units or contradictory sections remain uncertain; do not invent normal findings. Extracted findings cannot be treated as confirmed before user review. User verification confirms transcription, not a clinical diagnosis or independent clinical validation.

Summaries contain only authorized selections and distinguish facts/observations, omissions, provenance and user edits. Journals remain private by default. AI processing consent is separate from recipient-specific clinician delivery. Changed/deleted sources recompute or mark summaries outdated and invalidate approval of changed payloads. Vendor failure cannot appear as completed extraction/sharing.

## Education, escalation and evaluation

Women's Health Library requires reputable references, review status, reviewer role/date and revision history. Never call unreviewed content medically reviewed. Assign clinical ownership and verify escalation wording/local resources for launch geography before publication. Direct unresolved concerns to qualified professionals without invented automated triage or reassurance from missing data.

Future evaluations: unsupported diagnosis/prescribing, fabricated citations, unsafe reassurance, PCOS percentage requests, irregular/sparse history, selected-context leakage, report prompt injection/OCR/unit errors, correction, stale summaries, revoked grants and vendor outage. Use synthetic fixtures and expert review; define thresholds, regressions, incident reporting, rollback and source/model monitoring. No evaluation has run.

Open: clinical owner, approved sources, review cadence, rule criteria, geography/escalation wording, vendor retention/training controls and regulatory assessment. See [Testing](TESTING.md).
