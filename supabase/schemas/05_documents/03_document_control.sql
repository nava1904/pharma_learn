-- ===========================================
-- DOCUMENT CONTROL
-- GAP 3: Document issuance, retrieval logging, print control
-- ===========================================

-- -------------------------------------------------------
-- DOCUMENT ISSUANCES
-- Tracks controlled/uncontrolled copies issued to employees
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_issuances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
    document_version_id UUID REFERENCES document_versions(id) ON DELETE RESTRICT,
    copy_number TEXT NOT NULL,              -- e.g. CC-001, UC-005
    issued_to_employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    issued_to_name TEXT NOT NULL,
    issued_by UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    issuance_type TEXT NOT NULL CHECK (issuance_type IN ('controlled', 'uncontrolled', 'reference', 'training')),
    acknowledgment_required BOOLEAN NOT NULL DEFAULT true,
    acknowledged_at TIMESTAMPTZ,
    acknowledged_via_esig_id UUID REFERENCES electronic_signatures(id),
    is_superseded BOOLEAN NOT NULL DEFAULT false,
    superseded_at TIMESTAMPTZ,
    retrieval_required BOOLEAN NOT NULL DEFAULT true,
    retrieved_at TIMESTAMPTZ,
    retrieval_log_id UUID,                  -- populated when retrieval_log row is created
    notes TEXT,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(document_id, copy_number)
);

CREATE INDEX IF NOT EXISTS idx_doc_issuances_document ON document_issuances(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_issuances_employee ON document_issuances(issued_to_employee_id);
CREATE INDEX IF NOT EXISTS idx_doc_issuances_type ON document_issuances(issuance_type);
CREATE INDEX IF NOT EXISTS idx_doc_issuances_superseded ON document_issuances(is_superseded);
CREATE INDEX IF NOT EXISTS idx_doc_issuances_org ON document_issuances(organization_id);

-- -------------------------------------------------------
-- DOCUMENT RETRIEVAL LOG
-- Append-only log of retrieved/destroyed document copies
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_retrieval_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_issuance_id UUID NOT NULL REFERENCES document_issuances(id) ON DELETE RESTRICT,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
    retrieved_from_employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    retrieved_by UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    retrieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    retrieval_method TEXT NOT NULL CHECK (retrieval_method IN ('physical', 'electronic', 'destroyed', 'returned')),
    destruction_witnessed_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    destruction_method TEXT,
    notes TEXT,
    esignature_id UUID REFERENCES electronic_signatures(id),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doc_retrieval_issuance ON document_retrieval_log(document_issuance_id);
CREATE INDEX IF NOT EXISTS idx_doc_retrieval_document ON document_retrieval_log(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_retrieval_at ON document_retrieval_log(retrieved_at);

-- Append-only enforcement
CREATE OR REPLACE FUNCTION document_retrieval_log_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'document_retrieval_log is append-only and cannot be modified (21 CFR Part 11)';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'document_retrieval_log is append-only and cannot be deleted (21 CFR Part 11)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_doc_retrieval_log_immutable ON document_retrieval_log;
CREATE TRIGGER trg_doc_retrieval_log_immutable
    BEFORE UPDATE OR DELETE ON document_retrieval_log
    FOR EACH ROW EXECUTE FUNCTION document_retrieval_log_immutable();

-- -------------------------------------------------------
-- DOCUMENT PRINT LOG
-- Append-only log of every print action; enforces reprint policy
-- -------------------------------------------------------
CREATE TABLE IF NOT EXISTS document_print_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE RESTRICT,
    document_version_id UUID REFERENCES document_versions(id) ON DELETE RESTRICT,
    printed_by UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    printed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    print_type TEXT NOT NULL CHECK (print_type IN ('controlled', 'uncontrolled', 'training', 'reference')),
    printer_name TEXT,
    copy_count INTEGER NOT NULL DEFAULT 1 CHECK (copy_count > 0),
    is_reprint BOOLEAN NOT NULL DEFAULT false,
    reprint_reason TEXT,
    reprint_approved_by UUID REFERENCES employees(id) ON DELETE SET NULL,
    reprint_approved_via_esig_id UUID REFERENCES electronic_signatures(id),
    issuance_id UUID REFERENCES document_issuances(id),
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    plant_id UUID REFERENCES plants(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_doc_print_document ON document_print_log(document_id);
CREATE INDEX IF NOT EXISTS idx_doc_print_employee ON document_print_log(printed_by);
CREATE INDEX IF NOT EXISTS idx_doc_print_at ON document_print_log(printed_at);
CREATE INDEX IF NOT EXISTS idx_doc_print_reprint ON document_print_log(is_reprint);
CREATE INDEX IF NOT EXISTS idx_doc_print_org ON document_print_log(organization_id);

-- Append-only enforcement
CREATE OR REPLACE FUNCTION document_print_log_immutable()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        RAISE EXCEPTION 'document_print_log is append-only and cannot be modified (21 CFR Part 11)';
    END IF;
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION 'document_print_log is append-only and cannot be deleted (21 CFR Part 11)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_doc_print_log_immutable ON document_print_log;
CREATE TRIGGER trg_doc_print_log_immutable
    BEFORE UPDATE OR DELETE ON document_print_log
    FOR EACH ROW EXECUTE FUNCTION document_print_log_immutable();

-- -------------------------------------------------------
-- FUNCTIONS
-- -------------------------------------------------------

-- Issue a document copy (controlled or uncontrolled) to an employee
CREATE OR REPLACE FUNCTION issue_document_copy(
    p_document_id UUID,
    p_version_id UUID,
    p_employee_id UUID,
    p_issuance_type TEXT DEFAULT 'controlled',
    p_copy_number TEXT DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_issuance_id UUID;
    v_doc RECORD;
    v_employee RECORD;
    v_copy_number TEXT;
    v_copy_seq INTEGER;
    v_prefix TEXT;
BEGIN
    -- Validate document is active
    SELECT d.*, o.id as org_id FROM documents d
    LEFT JOIN organizations o ON o.id = d.organization_id
    INTO v_doc
    WHERE d.id = p_document_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document not found: %', p_document_id;
    END IF;

    IF v_doc.status != 'active' THEN
        RAISE EXCEPTION 'Cannot issue document "%" — current status is "%" (must be active)',
            v_doc.name, v_doc.status;
    END IF;

    -- Get employee name
    SELECT first_name || ' ' || last_name AS full_name
    INTO v_employee FROM employees WHERE id = p_employee_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Employee not found: %', p_employee_id;
    END IF;

    -- Auto-generate copy number if not provided
    IF p_copy_number IS NULL THEN
        v_prefix := CASE p_issuance_type
            WHEN 'controlled'   THEN 'CC'
            WHEN 'uncontrolled' THEN 'UC'
            WHEN 'reference'    THEN 'RC'
            WHEN 'training'     THEN 'TC'
            ELSE 'DC'
        END;

        SELECT COALESCE(MAX(
            NULLIF(regexp_replace(copy_number, '[^0-9]', '', 'g'), '')::INTEGER
        ), 0) + 1
        INTO v_copy_seq
        FROM document_issuances
        WHERE document_id = p_document_id
          AND issuance_type = p_issuance_type;

        v_copy_number := v_prefix || '-' || LPAD(v_copy_seq::TEXT, 3, '0');
    ELSE
        v_copy_number := p_copy_number;
    END IF;

    INSERT INTO document_issuances (
        document_id, document_version_id, copy_number,
        issued_to_employee_id, issued_to_name, issued_by,
        issuance_type, notes,
        organization_id, plant_id
    ) VALUES (
        p_document_id, p_version_id, v_copy_number,
        p_employee_id, v_employee.full_name, get_current_user_id(),
        p_issuance_type, p_notes,
        v_doc.organization_id, v_doc.plant_id
    )
    RETURNING id INTO v_issuance_id;

    RETURN v_issuance_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Log a document print; enforces reprint policy for superseded versions
CREATE OR REPLACE FUNCTION log_document_print(
    p_document_id UUID,
    p_version_id UUID DEFAULT NULL,
    p_print_type TEXT DEFAULT 'uncontrolled',
    p_is_reprint BOOLEAN DEFAULT false,
    p_reprint_reason TEXT DEFAULT NULL,
    p_esig_id UUID DEFAULT NULL,
    p_issuance_id UUID DEFAULT NULL,
    p_printer_name TEXT DEFAULT NULL,
    p_copy_count INTEGER DEFAULT 1
) RETURNS UUID AS $$
DECLARE
    v_print_id UUID;
    v_doc RECORD;
    v_version RECORD;
BEGIN
    -- Get document context
    SELECT d.organization_id, d.plant_id, d.status
    INTO v_doc FROM documents d WHERE d.id = p_document_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Document not found: %', p_document_id;
    END IF;

    -- Reprint policy: check if reprinting a superseded/obsolete version
    IF p_is_reprint AND p_version_id IS NOT NULL THEN
        SELECT is_current INTO v_version
        FROM document_versions WHERE id = p_version_id;

        IF FOUND AND NOT v_version.is_current THEN
            -- Version is not current — check behavioral control
            IF NOT get_setting_bool(v_doc.organization_id, 'allow_reprint_old_docs') THEN
                RAISE EXCEPTION
                    'Reprint of superseded document version is not permitted. '
                    'Set compliance.allow_reprint_old_docs = true to allow, or obtain approval. '
                    USING ERRCODE = 'check_violation';
            END IF;
        END IF;
    END IF;

    INSERT INTO document_print_log (
        document_id, document_version_id, printed_by,
        print_type, printer_name, copy_count,
        is_reprint, reprint_reason, reprint_approved_via_esig_id,
        issuance_id, organization_id, plant_id
    ) VALUES (
        p_document_id, p_version_id, get_current_user_id(),
        p_print_type, p_printer_name, p_copy_count,
        p_is_reprint, p_reprint_reason, p_esig_id,
        p_issuance_id, v_doc.organization_id, v_doc.plant_id
    )
    RETURNING id INTO v_print_id;

    RETURN v_print_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE document_issuances IS 'Controlled-copy issuance tracking per employee — required for GMP document control';
COMMENT ON TABLE document_retrieval_log IS 'Append-only log of document retrieval/destruction (21 CFR Part 11)';
COMMENT ON TABLE document_print_log IS 'Append-only print audit log; enforces reprint policy for superseded versions';
COMMENT ON FUNCTION issue_document_copy IS 'Issue a controlled or uncontrolled copy to an employee; validates document is active';
COMMENT ON FUNCTION log_document_print IS 'Log a print action; raises exception if reprinting superseded version when policy disallows it';
