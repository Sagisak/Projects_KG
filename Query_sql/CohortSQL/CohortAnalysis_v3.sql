With GettingData AS (
SELECT distinct
      CAST(a.TRANSDATE AS DATE) as TransDate
      ,d.[CustomerId]
  FROM GORPDWHBI..ViewCohort a  WITH (NOLOCK)
  Inner join GORPDWHBI..DimCustomer d WITH (NOLOCK)     on a.CustomerId = d.CustomerId and a.DataAreaId = d.DataAreaId
  WHERE d.MyValueId is not NULL and d.MyValueId <> ''
  AND a.TransDate BETWEEN '20240101' AND GETDATE()
  AND A.SalesPoolId = '001'
),
FirstTransactionCohort AS (
  SELECT 
    CustomerId,
    DATEFROMPARTS(YEAR(MIN(TransDate)), MONTH(MIN(TransDate)), 1) AS cohort_month
  FROM GettingData
  GROUP BY CustomerId
),
ActivityWithCohort AS (
  SELECT 
    c.CustomerId,
    c.cohort_month,
    DATEFROMPARTS(YEAR(t.TransDate), MONTH(t.TransDate), 1) AS activity_month
  FROM GettingData t
  INNER JOIN FirstTransactionCohort c ON t.CustomerId = c.CustomerId
),
ActivityWithOffset AS (
  SELECT 
    CustomerId,
    FORMAT(cohort_month, 'MMMM yyyy') AS cohort_label,
    cohort_month AS cohort_date, 
    YEAR(cohort_month) AS cohort_year,
    MONTH(cohort_month) AS cohort_month_number,
    DATEDIFF(MONTH, cohort_month, activity_month) AS month_offset
  FROM ActivityWithCohort
  WHERE activity_month >= cohort_month
)
SELECT 
  cohort_label,
  month_offset,
  COUNT(DISTINCT CustomerId) AS active_users
FROM ActivityWithOffset	
GROUP BY cohort_label, cohort_month_number, month_offset, cohort_date
ORDER BY cohort_date, month_offset;
