/* =========================================================
   0. HARD RESET (DEV SAFE)
   ========================================================= */
DROP SCHEMA IF EXISTS dq CASCADE;
CREATE SCHEMA dq;

/* =========================================================
   1. CORE TABLES
   ========================================================= */

CREATE TABLE dq.provider_reference (
  provider_id TEXT PRIMARY KEY,
  provider_name TEXT NOT NULL,
  provider_state TEXT NOT NULL
);

CREATE TABLE dq.claims_transactions (
  claim_id TEXT NOT NULL,
  member_id TEXT NOT NULL,
  provider_id TEXT NOT NULL,
  service_date DATE NOT NULL,
  submission_date DATE NOT NULL,
  claim_amount NUMERIC(12,2) NOT NULL,
  paid_amount NUMERIC(12,2) NOT NULL,
  diagnosis_code TEXT,
  procedure_code TEXT NOT NULL,
  claim_status TEXT NOT NULL,
  source_system TEXT NOT NULL,
  load_timestamp TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dq.validation_results (
  rule_id TEXT,
  rule_name TEXT,
  rule_category TEXT,
  severity TEXT,
  claim_id TEXT,
  failure_reason TEXT,
  detected_at TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT uq_rule_claim UNIQUE (rule_id, claim_id)
);

CREATE TABLE dq.severity_weights (
  severity TEXT PRIMARY KEY,
  weight INT NOT NULL
);

/* =========================================================
   2. SEED DATA
   ========================================================= */

INSERT INTO dq.severity_weights VALUES
('HIGH',5),
('MEDIUM',2),
('LOW',1);

INSERT INTO dq.provider_reference VALUES
('P100','Orlando Family Clinic','FL'),
('P200','Pittsburgh General','PA'),
('P300','New Brunswick Health','NJ');

/* =========================================================
   3. SCALE DATA (~10,000 CLAIMS WITH DEFECTS)
   ========================================================= */

INSERT INTO dq.claims_transactions
SELECT
  'C' || g                              AS claim_id,
  'M' || g                              AS member_id,
  CASE WHEN g % 50 = 0 THEN 'P999'
       ELSE 'P100' END                  AS provider_id,
  CURRENT_DATE - (g % 30)               AS service_date,
  CURRENT_DATE - (g % 25)               AS submission_date,
  100 + (g % 200)                       AS claim_amount,
  CASE WHEN g % 33 = 0 THEN 300
       ELSE 80 END                      AS paid_amount,
  CASE WHEN g % 45 = 0 THEN NULL
       ELSE 'I10' END                   AS diagnosis_code,
  '99213'                               AS procedure_code,
  CASE WHEN g % 40 = 0 THEN 'DENIED'
       ELSE 'PAID' END                  AS claim_status,
  'FACETS'                              AS source_system,
  NOW()                                 AS load_timestamp
FROM generate_series(1,10000) g;

/* =========================================================
   4. VALIDATION RULES (IDEMPOTENT)
   ========================================================= */

-- Missing diagnosis code
INSERT INTO dq.validation_results
SELECT 'R001','Missing Diagnosis','Completeness','HIGH',
       claim_id,'diagnosis_code IS NULL'
FROM dq.claims_transactions
WHERE diagnosis_code IS NULL
ON CONFLICT DO NOTHING;

-- Paid amount greater than claim amount
INSERT INTO dq.validation_results
SELECT 'R003','Paid > Claim','Validity','HIGH',
       claim_id,'paid_amount > claim_amount'
FROM dq.claims_transactions
WHERE paid_amount > claim_amount
ON CONFLICT DO NOTHING;

-- Service date after submission date
INSERT INTO dq.validation_results
SELECT 'R005','Service After Submission','Consistency','MEDIUM',
       claim_id,'service_date > submission_date'
FROM dq.claims_transactions
WHERE service_date > submission_date
ON CONFLICT DO NOTHING;

-- Denied but paid
INSERT INTO dq.validation_results
SELECT 'R007','Denied But Paid','Consistency','HIGH',
       claim_id,'DENIED with payment'
FROM dq.claims_transactions
WHERE claim_status = 'DENIED'
  AND paid_amount > 0
ON CONFLICT DO NOTHING;

-- Orphan provider
INSERT INTO dq.validation_results
SELECT 'R008','Orphan Provider','Referential Integrity','HIGH',
       c.claim_id,'provider not found'
FROM dq.claims_transactions c
LEFT JOIN dq.provider_reference p
  ON c.provider_id = p.provider_id
WHERE p.provider_id IS NULL
ON CONFLICT DO NOTHING;

/* =========================================================
   5. POWER BI–READY VIEWS
   ========================================================= */

-- Base claims (for drill-through)
CREATE OR REPLACE VIEW dq.claims_base AS
SELECT * FROM dq.claims_transactions;

-- Rule-level summary
CREATE OR REPLACE VIEW dq.dq_rule_summary AS
SELECT
  v.rule_id,
  v.rule_name,
  v.rule_category,
  v.severity,
  COUNT(*) AS failure_count,
  COUNT(*) * MAX(w.weight) AS weighted_impact
FROM dq.validation_results v
JOIN dq.severity_weights w
  ON v.severity = w.severity
GROUP BY
  v.rule_id,
  v.rule_name,
  v.rule_category,
  v.severity;

-- Risk by category
CREATE OR REPLACE VIEW dq.dq_category_risk AS
SELECT
  v.rule_category,
  SUM(w.weight) AS risk_score
FROM dq.validation_results v
JOIN dq.severity_weights w
  ON v.severity = w.severity
GROUP BY v.rule_category;

-- Severity distribution
CREATE OR REPLACE VIEW dq.dq_severity_distribution AS
SELECT
  severity,
  COUNT(*) AS failure_count
FROM dq.validation_results
GROUP BY severity;

-- Executive scorecard
CREATE OR REPLACE VIEW dq.dq_executive_scorecard AS
SELECT
  (SELECT COUNT(*) FROM dq.claims_transactions) AS total_claims,
  (SELECT COUNT(DISTINCT claim_id)
     FROM dq.validation_results) AS claims_with_issues,
  (SELECT COUNT(*)
     FROM dq.validation_results
     WHERE severity = 'HIGH') AS high_severity_issues,
  ROUND(
    100 - (
      (SELECT SUM(w.weight)
         FROM dq.validation_results v
         JOIN dq.severity_weights w
           ON v.severity = w.severity
      ) /
      ((SELECT COUNT(*) FROM dq.claims_transactions) * 5.0)
    ) * 100,
    2
  ) AS weighted_data_quality_score;

/* =========================================================
   6. VERIFICATION QUERIES
   ========================================================= */

SELECT COUNT(*) AS total_claims FROM dq.claims_transactions;
SELECT * FROM dq.dq_rule_summary ORDER BY weighted_impact DESC;
SELECT * FROM dq.dq_category_risk ORDER BY risk_score DESC;
SELECT * FROM dq.dq_severity_distribution;
SELECT * FROM dq.dq_executive_scorecard;

-- Detailed validation log
SELECT
  v.claim_id,
  v.rule_id,
  v.rule_name,
  v.rule_category,
  v.severity,
  v.failure_reason,
  v.detected_at
FROM dq.validation_results v
ORDER BY
  v.severity DESC,
  v.detected_at DESC;

-- Claims with provider context
SELECT
  c.claim_id,
  c.member_id,
  c.provider_id,
  p.provider_name,
  p.provider_state,
  c.service_date,
  c.submission_date,
  c.claim_amount,
  c.paid_amount,
  c.claim_status,
  c.source_system,
  c.load_timestamp
FROM dq.claims_transactions c
LEFT JOIN dq.provider_reference p
  ON c.provider_id = p.provider_id
ORDER BY c.load_timestamp DESC;
