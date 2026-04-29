# PharmaLearn LMS — Documentation

> **Version:** 2.0 | **Date:** April 2026 | **Status:** Production-Ready (98.2% scope coverage)

---

## Documentation Structure

```
docs/
├── README.md                           # This file - documentation index
│
├── 📋 CORE REFERENCE
│   ├── schema.md                       # Database schema reference (292 tables)
│   ├── answer.md                       # API reference (646+ endpoints)
│   └── API_TOOLS_REFERENCE.md          # API tools and utilities
│
├── 📐 ARCHITECTURE
│   ├── architecture_plan.md            # System architecture overview
│   └── architecture_onpremise.md       # On-premise deployment guide
│
├── 📚 DOMAIN PLANS
│   ├── access_plan.md                  # Access control module design
│   ├── create_plan.md                  # Content creation module design
│   ├── train_plan.md                   # Training execution module design
│   └── certify_plan.md                 # Certification module design
│
├── 📊 ANALYSIS & COMPLIANCE
│   ├── pharma_lms_scope_document.md    # Business requirements baseline
│   ├── codebase_richness_analysis.md   # Implementation completeness analysis
│   ├── backend_scope_traceability_matrix.md  # Scope-to-code traceability
│   └── SCORM_SUPPORT.md                # SCORM implementation details
│
├── 📝 IMPLEMENTATION
│   └── plan.md                         # Master implementation plan (DO NOT MODIFY)
│
└── 📄 REFERENCE DOCUMENTS
    └── Pharma_LMS_Knowledge_Base.docx  # Original knowledge base
```

---

## Quick Links

### For Developers

| Document | Purpose |
|----------|---------|
| [schema.md](./schema.md) | Database schema reference with all 292 tables |
| [answer.md](./answer.md) | Complete API reference with 646+ endpoints |
| [API_TOOLS_REFERENCE.md](./API_TOOLS_REFERENCE.md) | Shared services and utilities |

### For Architects

| Document | Purpose |
|----------|---------|
| [architecture_plan.md](./architecture_plan.md) | System architecture and design decisions |
| [architecture_onpremise.md](./architecture_onpremise.md) | On-premise deployment patterns |
| [codebase_richness_analysis.md](./codebase_richness_analysis.md) | Implementation completeness assessment |

### For Product Owners

| Document | Purpose |
|----------|---------|
| [pharma_lms_scope_document.md](./pharma_lms_scope_document.md) | Business requirements and scope |
| [backend_scope_traceability_matrix.md](./backend_scope_traceability_matrix.md) | Requirements-to-code mapping |
| [SCORM_SUPPORT.md](./SCORM_SUPPORT.md) | SCORM e-learning support details |

---

## Current System Status

| Metric | Value |
|--------|-------|
| **Scope Coverage** | 98.2% (213/217 capabilities) |
| **API Endpoints** | 646+ |
| **Database Tables** | 292 |
| **Handler Files** | 197 |
| **21 CFR Part 11** | Fully compliant |
| **SCORM Support** | 1.2 & 2004 |

---

## Key Compliance Features

- ✅ **21 CFR Part 11** — Full electronic signature and audit trail compliance
- ✅ **EU Annex 11** — Data integrity and system validation support
- ✅ **WHO GMP** — Training record retention and qualification tracking
- ✅ **ICH Q10** — Quality management integration

---

## Module Overview

### ACCESS (42 handlers)
Authentication, authorization, employees, roles, groups, SSO, biometrics, delegations

### CREATE (49 handlers)
Courses, documents, GTPs, curricula, SCORM, question banks, trainers, venues, configuration

### TRAIN (42 handlers)
Sessions, attendance, OJT, induction, self-learning, triggers, invitations, batches

### CERTIFY (31 handlers)
E-signatures, assessments, certificates, compliance, competencies, waivers, integrity

### WORKFLOW (9 handlers)
Approvals, deviations, CAPAs, change controls, audit trails

### REPORTS (8 handlers)
Report templates, execution, scheduling, export (PDF/CSV/Excel)

### HEALTH (3 handlers)
Health checks, readiness probes, Prometheus metrics

---

## Maintenance Notes

1. **DO NOT MODIFY** `plan.md` — This is the master implementation plan
2. **Schema is frozen** — All 292 tables are production-ready
3. **API handlers use Relic HTTP framework** — Follow existing patterns
4. **All e-signature actions require reauth** — Per 21 CFR §11.200

---

*Documentation last updated: April 2026*
