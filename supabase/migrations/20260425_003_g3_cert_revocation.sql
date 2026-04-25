-- Migration: Two-person certificate revocation workflow
-- Gap G3: certificate_revocation_requests table with two-person check
-- Reference: Design Decision Q7 (21 CFR Part 11 compliant revocation)

CREATE TABLE IF NOT EXISTS certificate_revocation_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  certificate_id UUID NOT NULL REFERENCES certificates(id),
  
  -- Initiator (first person)
  initiated_by UUID NOT NULL REFERENCES employees(id),
  initiated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  initiation_reason TEXT NOT NULL,
  initiation_esignature_id UUID NOT NULL REFERENCES electronic_signatures(id),
  
  -- Confirmer (second person - must be different)
  confirmed_by UUID REFERENCES employees(id),
  confirmed_at TIMESTAMPTZ,
  confirmation_esignature_id UUID REFERENCES electronic_signatures(id),
  
  -- Cancellation (optional - before confirmation)
  cancelled_by UUID REFERENCES employees(id),
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  
  -- Status tracking
  status TEXT NOT NULL DEFAULT 'pending' 
    CHECK (status IN ('pending', 'confirmed', 'cancelled')),
  
  -- Audit fields
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  -- Two-person integrity: confirmer != initiator
  CONSTRAINT two_person_revocation 
    CHECK (confirmed_by IS NULL OR confirmed_by != initiated_by)
);

-- Indexes for common queries
CREATE INDEX IF NOT EXISTS idx_cert_revocation_certificate 
  ON certificate_revocation_requests(certificate_id);
CREATE INDEX IF NOT EXISTS idx_cert_revocation_status 
  ON certificate_revocation_requests(status) 
  WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_cert_revocation_initiated_by 
  ON certificate_revocation_requests(initiated_by);

-- RLS policies
ALTER TABLE certificate_revocation_requests ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view revocation requests for certificates they have access to
CREATE POLICY "Users can view accessible revocation requests" 
  ON certificate_revocation_requests FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM certificates c
      JOIN employees e ON c.employee_id = e.id
      WHERE c.id = certificate_revocation_requests.certificate_id
        AND e.org_id = (auth.jwt() ->> 'org_id')::uuid
    )
  );

-- Policy: Only training admins can initiate/confirm/cancel
CREATE POLICY "Training admins can manage revocation requests"
  ON certificate_revocation_requests FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM employees e
      JOIN user_roles ur ON e.user_id = ur.user_id
      JOIN roles r ON ur.role_id = r.id
      WHERE e.user_id = auth.uid()
        AND r.name IN ('Training Admin', 'Training Manager', 'QA Manager')
    )
  );

COMMENT ON TABLE certificate_revocation_requests IS 
  'Two-person workflow for certificate revocation per 21 CFR Part 11. Initiator and confirmer must be different users.';
