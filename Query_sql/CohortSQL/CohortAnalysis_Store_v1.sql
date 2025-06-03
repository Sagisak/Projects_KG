With GettingData AS (
SELECT distinct
      CAST(a.CREATEDDATETIME AS DATE) as TransDate
      ,d.[CustomerId], ds.StoreName
  FROM gorpdwh365..retailtransactiontable a WITH (NOLOCK)
	LEFT JOIN gorpdwh365..retailtransactionsalestrans rs WITH (NOLOCK) on rs.TRANSACTIONID = a.TRANSACTIONID and rs.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=d.DataAreaId
  inner join GORPDWHBI..DimStore ds with(nolock) on a.STORE = ds.StoreId
  WHERE d.MyValueId is not NULL and d.MyValueId <> ''
  AND a.CREATEDDATETIME BETWEEN '20240101' AND GETDATE()
),
FirstTransactionCohort AS (
  SELECT 
    CustomerId,
    StoreName,
    DATEFROMPARTS(YEAR(MIN(TransDate)), MONTH(MIN(TransDate)), 1) AS cohort_month
  FROM GettingData
  GROUP BY CustomerId, StoreName
),
ActivityWithCohort AS (
  SELECT 
    c.CustomerId,
    c.StoreName,
    c.cohort_month,
    DATEFROMPARTS(YEAR(t.TransDate), MONTH(t.TransDate), 1) AS activity_month
  FROM GettingData t
  INNER JOIN FirstTransactionCohort c ON t.CustomerId = c.CustomerId
),
ActivityWithOffset AS (
  SELECT 
    CustomerId,
    StoreName,
    FORMAT(cohort_month, 'MMMM yyyy') AS cohort_label,
    cohort_month AS cohort_date, 
    YEAR(cohort_month) AS cohort_year,
    MONTH(cohort_month) AS cohort_month_number,
    DATEDIFF(MONTH, cohort_month, activity_month) AS month_offset
  FROM ActivityWithCohort
  WHERE activity_month >= cohort_month
)
SELECT 
  StoreName,
  cohort_label,
  month_offset,
  COUNT(DISTINCT CustomerId) AS active_users
FROM ActivityWithOffset	
GROUP BY cohort_label, cohort_month_number, month_offset, cohort_date, storeName
ORDER BY StoreName DESC, cohort_date, month_offset;
