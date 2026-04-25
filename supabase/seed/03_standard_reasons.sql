-- ===========================================
-- SEED DATA: STANDARD REASONS
-- ===========================================

-- Standard Reasons for Learn-IQ Workflow (21 CFR Part 11 compliant)
INSERT INTO standard_reasons (id, organization_id, reason_type, reason_code, reason_text, is_active) VALUES
    -- Approval Reasons
    ('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-000000000001', 'approval', 'APR001', 'Content reviewed and verified as accurate', true),
    ('00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-000000000001', 'approval', 'APR002', 'Compliance requirements met', true),
    ('00000000-0000-0000-0000-0000000000a3', '00000000-0000-0000-0000-000000000001', 'approval', 'APR003', 'Training objectives clearly defined', true),
    ('00000000-0000-0000-0000-0000000000a4', '00000000-0000-0000-0000-000000000001', 'approval', 'APR004', 'Assessment criteria appropriate', true),
    ('00000000-0000-0000-0000-0000000000a5', '00000000-0000-0000-0000-000000000001', 'approval', 'APR005', 'All required documents attached', true),
    
    -- Rejection Reasons
    ('00000000-0000-0000-0000-0000000000b1', '00000000-0000-0000-0000-000000000001', 'rejection', 'REJ001', 'Content requires revision - technical inaccuracies', true),
    ('00000000-0000-0000-0000-0000000000b2', '00000000-0000-0000-0000-000000000001', 'rejection', 'REJ002', 'Missing required regulatory references', true),
    ('00000000-0000-0000-0000-0000000000b3', '00000000-0000-0000-0000-000000000001', 'rejection', 'REJ003', 'Assessment questions not aligned with objectives', true),
    ('00000000-0000-0000-0000-0000000000b4', '00000000-0000-0000-0000-000000000001', 'rejection', 'REJ004', 'Insufficient supporting documentation', true),
    ('00000000-0000-0000-0000-0000000000b5', '00000000-0000-0000-0000-000000000001', 'rejection', 'REJ005', 'Does not meet GMP requirements', true),
    
    -- Return for Revision
    ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-000000000001', 'return', 'RET001', 'Minor corrections needed', true),
    ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-000000000001', 'return', 'RET002', 'Additional information required', true),
    ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-000000000001', 'return', 'RET003', 'Formatting issues need correction', true),
    
    -- Waiver Reasons
    ('00000000-0000-0000-0000-0000000000d1', '00000000-0000-0000-0000-000000000001', 'waiver', 'WAV001', 'Prior equivalent training completed externally', true),
    ('00000000-0000-0000-0000-0000000000d2', '00000000-0000-0000-0000-000000000001', 'waiver', 'WAV002', 'Training not applicable to current role', true),
    ('00000000-0000-0000-0000-0000000000d3', '00000000-0000-0000-0000-000000000001', 'waiver', 'WAV003', 'Medical exemption documented', true),
    ('00000000-0000-0000-0000-0000000000d4', '00000000-0000-0000-0000-000000000001', 'waiver', 'WAV004', 'Temporary assignment - training deferred', true),
    
    -- E-Signature Reasons
    ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-000000000001', 'esignature', 'ESIG001', 'I have reviewed and approve this document', true),
    ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-000000000001', 'esignature', 'ESIG002', 'I certify the information is accurate and complete', true),
    ('00000000-0000-0000-0000-0000000000e3', '00000000-0000-0000-0000-000000000001', 'esignature', 'ESIG003', 'I acknowledge completion of this training', true),
    ('00000000-0000-0000-0000-0000000000e4', '00000000-0000-0000-0000-000000000001', 'esignature', 'ESIG004', 'I verify the trainee demonstrated competency', true),
    
    -- Training Completion Reasons
    ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-000000000001', 'completion', 'CMP001', 'Successfully completed all requirements', true),
    ('00000000-0000-0000-0000-0000000000f2', '00000000-0000-0000-0000-000000000001', 'completion', 'CMP002', 'Demonstrated competency through assessment', true),
    ('00000000-0000-0000-0000-0000000000f3', '00000000-0000-0000-0000-000000000001', 'completion', 'CMP003', 'Practical evaluation passed', true),
    
    -- Deviation/CAPA Training Reasons
    ('00000000-0000-0000-0000-0000000000g1', '00000000-0000-0000-0000-000000000001', 'deviation', 'DEV001', 'Corrective training required due to deviation', true),
    ('00000000-0000-0000-0000-0000000000g2', '00000000-0000-0000-0000-000000000001', 'deviation', 'DEV002', 'Preventive training as part of CAPA', true),
    ('00000000-0000-0000-0000-0000000000g3', '00000000-0000-0000-0000-000000000001', 'deviation', 'DEV003', 'Retraining due to repeated errors', true)
ON CONFLICT DO NOTHING;
