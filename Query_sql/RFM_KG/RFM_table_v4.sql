--Getting RFM

	DECLARE @StartDt date = DATEADD(day, -730, CAST(GETDATE() AS date));  -- one year ago
	DECLARE @EndDt   date = DATEADD(day, -1, CAST(GETDATE() AS date));       -- yesterday
	
with CUSTINVOICETRANS as (
	-- data transaksi member \
SELECT  a.TRANSACTIONID AS TRANSACTIONID 
		,a.[TRANSDATE] AS transaction_date
	  ,d.MyValueId AS MyValueId
	  ,d.EmailAddress as email
      ,b.[ITEMID] AS ItemId
	  ,(b.QTY * -1) AS Quantity
	  ,(b.NETAMOUNT * -1) AS Sales_Netto
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DataAreaId
WHERE a.TYPE in (2,19)
  and a.ENTRYSTATUS in (0,2)
  and b.TRANSACTIONSTATUS in (0,2)
  and a.RECEIPTID is not null
  and isnull(b.RECEIPTID,'')<>'' 
  and b.TRANSDATE between @StartDt and @EndDt
  and d.MyValueId IS NOT NULL and d.MyValueId <> ''
  and d.CustGroup = 'KGVC'
	),

	 GettingNetSaleData as (
	select
	 TRANSACTIONID as SalesId,
	Sales_Netto as net_sales,
	 Quantity as qty
	FROM[CUSTINVOICETRANS]  with(nolock) --data transaksi dari tabel ini 
	group by TRANSACTIONID, ItemId, Sales_Netto, Quantity
	),

	TotalNetSales as (
	select SalesId, sum(net_sales) as net_sales
	from GettingNetSaleData 
	group by SalesId
	),

	LastTransaction AS (
		-- capture each member's most recent transaction date
		SELECT
			MyValueId,
			MAX(transaction_date) AS LastTrxDate
		FROM [CUSTINVOICETRANS]  WITH (NOLOCK)
		GROUP BY MyValueId
	),

	GettingDATA as(
	SELECT DISTINCT --Kolom myvalueid, phone_number, email, jumlah transaksi, net_sales
	ci.MyValueId,
	CI.TRANSACTIONID as SalesId
	FROM [CUSTINVOICETRANS] ci with(nolock) --data transaksi dari tabel ini
	  left join GORPDWHBI..MitraAtribut ma with(nolock) on ci.email = ma.email
	WHERE  
	isnull (ci.MyValueId,'')<>''
	and ma.email is null
	),

	Compiling as (
	select
	g.MyValueId,
	count(g.SalesId) AS Frequency,
	sum(t.net_sales) as Monetary,
	l.LastTrxDate,
	DATEDIFF(day, l.LastTrxDate, @EndDt) AS RecencyDays
	from GettingDATA g
	inner join TotalNetSales t on g.SalesId = t.SalesId
	INNER JOIN LastTransaction l ON g.MyValueId = l.MyValueId
	group by g.MyValueId, l.LastTrxDate
	HAVING SUM(t.net_sales) > 0
	),


--RFM_MyValue_Base STEP 3
	Thresholds AS (
	  SELECT
		PERCENTILE_CONT(0.3333) WITHIN GROUP (ORDER BY RecencyDays ASC)    OVER() AS R_33,
		PERCENTILE_CONT(0.6666) WITHIN GROUP (ORDER BY RecencyDays ASC)    OVER() AS R_67,
		PERCENTILE_CONT(0.3333) WITHIN GROUP (ORDER BY Frequency DESC) OVER() AS F_33,
		PERCENTILE_CONT(0.6666) WITHIN GROUP (ORDER BY Frequency DESC) OVER() AS F_67,
		PERCENTILE_CONT(0.3333) WITHIN GROUP (ORDER BY Monetary DESC)     OVER() AS M_33,
		PERCENTILE_CONT(0.6666) WITHIN GROUP (ORDER BY Monetary DESC)     OVER() AS M_67
	  FROM Compiling
	),
	SingleThresh AS (
	  -- pick just one row of those identical thresholds
	  SELECT TOP 1 * 
	  FROM Thresholds
	)
	SELECT
		Metric,
		Score,
		RangeDesc
	FROM (
		SELECT 'Recency (days)' AS Metric, 1 AS Score, CONCAT('> ', CAST(R_67 AS INT), ' days')            AS RangeDesc FROM SingleThresh
		UNION ALL
		SELECT 'Recency (days)',                 2, CONCAT('BETWEEN ', CAST(R_33 AS INT), ' AND ', CAST(R_67 AS INT), ' days') FROM SingleThresh
		UNION ALL
		SELECT 'Recency (days)',                 3, CONCAT('< ', CAST(R_33 AS INT), ' days')                   FROM SingleThresh

		UNION ALL

		SELECT 'Frequency',                     1, CONCAT('< ', CAST(F_67 AS INT),' transaction')                   FROM SingleThresh
		UNION ALL
		SELECT 'Frequency',                     2, CONCAT('BETWEEN ', CAST(F_67 AS INT), ' AND ', CAST(F_33 AS INT), ' transaction') FROM SingleThresh
		UNION ALL
		SELECT 'Frequency',                     3, CONCAT('> ', CAST(F_33 AS INT), ' transaction')                   FROM SingleThresh

		UNION ALL

		SELECT 'Monetary (Rp)',                1, CONCAT('< ', CAST(M_67 AS INT) )                   FROM SingleThresh
		UNION ALL
		SELECT 'Monetary (Rp)',                2, CONCAT('BETWEEN ', CAST(M_67 AS INT), ' AND ', CAST(M_33 AS INT)) FROM SingleThresh
		UNION ALL
		SELECT 'Monetary (Rp)',                3, CONCAT('> ', CAST(M_33 AS INT))                   FROM SingleThresh
	) AS Summary
	ORDER BY
		CASE Metric
		  WHEN 'Recency (days)' THEN 1
		  WHEN 'Frequency'     THEN 2
		  ELSE 3
		END,
		Score;


--FREQUENCT COUNT(DISTINCT TRANSACTION ID)
--LEFT JOIN MITRAATRIBUT
--WHERE MITRA-EMAIL ISNULL