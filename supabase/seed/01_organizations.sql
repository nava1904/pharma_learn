-- ===========================================
-- SEED DATA: ORGANIZATIONS, PLANTS, DEPARTMENTS
-- All tables live in `public` schema (no prefixes)
-- ===========================================

INSERT INTO organizations (
    id, name, code, legal_name, description,
    email, phone, website,
    address_line1, city, state, country, postal_code,
    timezone, currency, language,
    gst_number, pan_number, drug_license, manufacturing_license,
    compliance_frameworks,
    default_pass_mark, max_assessment_attempts, certificate_validity_months,
    is_active, status
) VALUES
('00000000-0000-0000-0000-000000000001',
 'Acme Pharma Ltd', 'ACME', 'Acme Pharmaceuticals Private Limited',
 'Demo pharma manufacturer - GMP certified',
 'info@acmepharma.com', '+91-40-12345678', 'https://acmepharma.example.com',
 '100 Industry Road', 'Hyderabad', 'Telangana', 'India', '500032',
 'Asia/Kolkata', 'INR', 'en',
 '36AAAAA0000A1Z5', 'AAAAA0000A', 'DL/TG/2021/0001', 'MFG/TG/2021/0001',
 ARRAY['FDA_21CFR_PART11','EU_ANNEXURE_11','WHO_GMP','ICH_Q10'],
 70.00, 3, 12,
 true, 'active')
ON CONFLICT (code) DO NOTHING;

INSERT INTO plants (
    id, organization_id, name, code, short_name, description,
    is_master, plant_type,
    address_line1, city, state, country, postal_code, timezone,
    contact_person, contact_email, contact_phone,
    manufacturing_license, drug_license, gmp_certificate,
    is_active, status
) VALUES
('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000001',
 'Head Office','HQ','HQ','Corporate headquarters - master plant',
 true,'office','100 Industry Road','Hyderabad','Telangana','India','500032','Asia/Kolkata',
 'Rajesh Menon','hq@acmepharma.com','+91-40-12345678',
 NULL,NULL,NULL,true,'active'),
('00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000001',
 'Plant 1 - Hyderabad','P1-HYD','P1','Oral solids manufacturing',
 false,'manufacturing','Plot 12, Pharma City','Hyderabad','Telangana','India','500078','Asia/Kolkata',
 'Kavita Rao','p1@acmepharma.com','+91-40-23456789',
 'MFG/TG/P1/2021','DL/TG/P1/2021','GMP-P1-2024',true,'active'),
('00000000-0000-0000-0000-000000000013','00000000-0000-0000-0000-000000000001',
 'Plant 2 - Visakhapatnam','P2-VZG','P2','Injectables & parenterals',
 false,'manufacturing','SEZ Unit 7','Visakhapatnam','Andhra Pradesh','India','530012','Asia/Kolkata',
 'Naveen Reddy','p2@acmepharma.com','+91-891-3456789',
 'MFG/AP/P2/2022','DL/AP/P2/2022','GMP-P2-2024',true,'active'),
('00000000-0000-0000-0000-000000000014','00000000-0000-0000-0000-000000000001',
 'QC Lab - Hyderabad','QCL','QCL','Quality control laboratory',
 false,'qa_qc_lab','Plot 14, Pharma City','Hyderabad','Telangana','India','500078','Asia/Kolkata',
 'Priya Sharma','qcl@acmepharma.com','+91-40-34567890',
 NULL,NULL,'ISO 17025',true,'active')
ON CONFLICT (organization_id, code) DO NOTHING;

INSERT INTO departments (
    id, organization_id, plant_id, name, unique_code, short_name,
    description, hierarchy_level, is_active, status
) VALUES
('00000000-0000-0000-0000-000000000021','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',
 'Human Resources','HR','HR','Corporate HR',1,true,'active'),
('00000000-0000-0000-0000-000000000022','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',
 'Quality Assurance','QA','QA','Corporate QA',1,true,'active'),
('00000000-0000-0000-0000-000000000023','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'Production','PROD','PROD','Plant 1 production',1,true,'active'),
('00000000-0000-0000-0000-000000000024','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'Quality Control','QC','QC','Plant 1 QC',1,true,'active'),
('00000000-0000-0000-0000-000000000025','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000013',
 'Sterile Manufacturing','STERILE','STR','Plant 2 sterile ops',1,true,'active'),
('00000000-0000-0000-0000-000000000026','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',
 'Regulatory Affairs','RA','RA','Corporate regulatory',1,true,'active'),
('00000000-0000-0000-0000-000000000027','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',
 'Training & Development','TD','TND','L&D department',1,true,'active'),
('00000000-0000-0000-0000-000000000028','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000012',
 'Warehouse','WH','WH','Plant 1 warehouse',1,true,'active'),
('00000000-0000-0000-0000-000000000029','00000000-0000-0000-0000-000000000001','00000000-0000-0000-0000-000000000011',
 'Information Technology','IT','IT','Corporate IT',1,true,'active')
ON CONFLICT DO NOTHING;
