With GettingData AS (
SELECT distinct
      CAST(a.CREATEDDATETIME AS DATE) as TransDate
      ,d.[CustomerId], ds.Area
  FROM gorpdwh365..retailtransactiontable a WITH (NOLOCK)
	LEFT JOIN gorpdwh365..retailtransactionsalestrans rs WITH (NOLOCK) on rs.TRANSACTIONID = a.TRANSACTIONID and rs.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=d.DataAreaId
  inner join GORPDWHBI..DimStore ds with(nolock) on a.STORE = ds.StoreId
  left join GORPDWHBI..MitraAtribut ma with(nolock) on d.EmailAddress = ma.email
  WHERE d.MyValueId is not NULL and d.MyValueId <> ''
  and ma.email is null
  AND a.CREATEDDATETIME BETWEEN '20240101' AND GETDATE()
),
FirstTransactionCohort AS (
  SELECT 
    CustomerId,
    Area,
    DATEFROMPARTS(YEAR(MIN(TransDate)), MONTH(MIN(TransDate)), 1) AS cohort_month
  FROM GettingData
  GROUP BY CustomerId, Area
),
ActivityWithCohort AS (
  SELECT 
    c.CustomerId,
    c.Area,
    c.cohort_month,
    DATEFROMPARTS(YEAR(t.TransDate), MONTH(t.TransDate), 1) AS activity_month
  FROM GettingData t
  INNER JOIN FirstTransactionCohort c ON t.CustomerId = c.CustomerId
),
ActivityWithOffset AS (
  SELECT 
    CustomerId,
    Area,
    FORMAT(cohort_month, 'MMMM yyyy') AS cohort_label,
    cohort_month AS cohort_date, 
    YEAR(cohort_month) AS cohort_year,
    MONTH(cohort_month) AS cohort_month_number,
    DATEDIFF(MONTH, cohort_month, activity_month) AS month_offset
  FROM ActivityWithCohort
  WHERE activity_month >= cohort_month
)
SELECT 
  Area,
  cohort_label as 'First Transaction',
  month_offset as 'bulan transaksi kembali',
  COUNT(DISTINCT CustomerId) AS active_users
FROM ActivityWithOffset	
GROUP BY cohort_label, cohort_month_number, month_offset, cohort_date, Area
ORDER BY Area DESC, cohort_date, month_offset;
