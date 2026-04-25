## Requirements traceability checklist (schema-level)

### Canonical training obligation
- **URS**: Encube §5.1.9–5.1.11; Alfa §4.1.1.7–4.1.1.9\n+- **Schema**: `employee_training_obligations`, `curricula`, `curriculum_*`

### Audit trail (3Ws, immutable)
- **URS**: Alfa §3.1.15–3.1.32; Encube §5.6.4–5.6.7\n+- **Schema**: `audit_trails` + immutability trigger, streaming from module-specific audit sources

### Electronic signatures bound to records
- **URS**: Alfa §4.5.30.*; Encube §5.13.*\n+- **Schema**: `electronic_signatures.record_hash`, `hash_schema_version`, `canonical_payload`, `esignature_reauth_sessions`

### Induction gating (DB enforced)
- **URS**: Alfa §4.3.21\n+- **Schema**: `employees.induction_completed`, RLS on `employee_training_obligations`

### Remedial disposition
- **URS**: Alfa §4.2.1.21 (retrain decision), ALCOA+ expectations\n+- **Schema**: `remedial_trainings.disposition` + linkage to obligations + quality workflows

### Multilingual (Marathi/Hindi)
- **URS**: Alfa §4.1.1.10\n+- **Schema**: `content_translations` + translated views

