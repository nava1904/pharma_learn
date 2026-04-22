# Phase 3: Learn-IQ Admin / Master Data Parity

## Completed

### 1. Subjects API (NEW)
**File:** `create/subjects/subjects_handler.dart` + `routes.dart`
**Endpoints:**
- `GET /v1/subjects` - List all subjects
- `GET /v1/subjects/:id` - Get subject details
- `POST /v1/subjects` - Create subject
- `PUT /v1/subjects/:id` - Update subject
- `DELETE /v1/subjects/:id` - Soft delete subject
- `POST /v1/subjects/:id/submit` - Submit for approval
- `POST /v1/subjects/:id/approve` - Approve subject

---

### 2. Topics API (NEW)
**File:** `create/topics/topics_handler.dart` + `routes.dart`
**Endpoints:**
- `GET /v1/topics` - List all topics
- `GET /v1/topics/:id` - Get topic details with tags and linked documents
- `POST /v1/topics` - Create topic with category/subject tags
- `PUT /v1/topics/:id` - Update topic and tags
- `DELETE /v1/topics/:id` - Soft delete topic
- `POST /v1/topics/:id/submit` - Submit for approval
- `POST /v1/topics/:id/approve` - Approve topic
- `POST /v1/topics/:id/documents` - Link document to topic
- `DELETE /v1/topics/:id/documents/:documentId` - Unlink document

---

### 3. Format Numbers API (NEW)
**File:** `create/config/master_data_handler.dart`
**Endpoints:**
- `GET /v1/config/format-numbers` - List format numbers
- `GET /v1/config/format-numbers/:id` - Get format number
- `POST /v1/config/format-numbers` - Create format number
- `PUT /v1/config/format-numbers/:id` - Update format number
- `DELETE /v1/config/format-numbers/:id` - Delete format number

---

### 4. Satisfaction Scales API (NEW)
**File:** `create/config/master_data_handler.dart`
**Endpoints:**
- `GET /v1/config/satisfaction-scales` - List scales
- `GET /v1/config/satisfaction-scales/:id` - Get scale
- `POST /v1/config/satisfaction-scales` - Create scale with parameters
- `PUT /v1/config/satisfaction-scales/:id` - Update scale
- `DELETE /v1/config/satisfaction-scales/:id` - Delete scale (if not in use)

---

## Summary

| Entity | Status | Endpoints |
|--------|--------|-----------|
| Subjects | ✅ Complete | 7 |
| Topics | ✅ Complete | 9 |
| Format Numbers | ✅ Complete | 5 |
| Satisfaction Scales | ✅ Complete | 5 |

**Total New Endpoints: 26**

## Route Mounting
- `subjects` mounted via `subjectsRoutes(app)` in `create/routes.dart`
- `topics` mounted via `topicsRoutes(app)` in `create/routes.dart`
- `format-numbers` and `satisfaction-scales` mounted via `mountConfigRoutes(app)`

## Verified
- `dart analyze lib/` - No errors (12 lint info warnings only)
