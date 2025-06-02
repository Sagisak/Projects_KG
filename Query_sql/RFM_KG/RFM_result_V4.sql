--Getting RFM

	DECLARE @StartDt date = DATEADD(day, -365, CAST(GETDATE() AS date));  -- one year ago
	DECLARE @EndDt   date = DATEADD(day, -1, CAST(GETDATE() AS date));       -- yesterday
	
	with CUSTINVOICETRANS as (
	-- data transaksi member 
SELECT  a.TRANSACTIONID AS TRANSACTIONID 
		,a.Dataareaid AS Dataareaid 
		,a.[TRANSDATE] AS transaction_date
	  ,d.MyValueId AS MyValueId
	  ,d.EmailAddress as email
      ,b.[ITEMID] AS ItemId
	  --,dm.PromotionId AS Promotion_Id
	  --,dm.Name AS Promotion_Name
	  ,(b.QTY * -1) AS Quantity
	  ,(b.NETAMOUNT * -1) AS Sales_Netto
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DataAreaId
  inner join [GORPDWHBI].[dbo].[DimStore] e with(nolock) on a.STORE = e.StoreId and a.DATAAREAID = e.DataAreaId
  inner join [GORPDWHBI].[dbo].[DimRegion] h with(nolock) on e.RegionId = h.RegionId 
  --left join [GORPDWH365].[dbo].[RETAILTRANSACTIONDISCOUNTTRANS] rtd with(nolock) on rtd.CHANNEL = b.CHANNEL AND rtd.STOREID = b.STORE
  --left join [GORPDWHBI].[dbo].[DimPromotion] dm with(nolock) on dm.PromotionId = rtd.PERIODICDISCOUNTOFFERID
WHERE a.TYPE in (2,19)
  and a.ENTRYSTATUS in (0,2)
  and b.TRANSACTIONSTATUS in (0,2)
  and a.RECEIPTID is not null
  and isnull(b.RECEIPTID,'')<>'' 
  and b.TRANSDATE between @StartDt and @EndDt
  and d.MyValueId IS NOT NULL and d.MyValueId <> ''
  and b.STORE IN (10155)
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

--RFM_MyValue_Final STEP 4
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
	
-- 4. Collapse to one row
SingleThresh AS (
  SELECT TOP 1 *
  FROM Thresholds
),

ScoredScores AS (
  SELECT
    c.MyValueId,
    c.RecencyDays,
    c.Frequency,
    c.Monetary,
    CASE 
      WHEN c.RecencyDays <= t.R_33 THEN 3
      WHEN c.RecencyDays <= t.R_67 THEN 2
      ELSE 1
    END AS R_Score,
    CASE
      WHEN c.Frequency <= t.F_67 THEN 1
      WHEN c.Frequency <= t.F_33 THEN 2
      ELSE 3
    END AS F_Score,
    CASE
      WHEN c.Monetary <= t.M_67 THEN 1
      WHEN c.Monetary <= t.M_33 THEN 2
      ELSE 3
    END AS M_Score,
    ( 
      CASE WHEN c.RecencyDays <= t.R_33 THEN 3 WHEN c.RecencyDays <= t.R_67 THEN 2 ELSE 1 END
    + CASE WHEN c.Frequency  <= t.F_67 THEN 1 WHEN c.Frequency  <= t.F_33 THEN 2 ELSE 3 END
    + CASE WHEN c.Monetary   <= t.M_67 THEN 1 WHEN c.Monetary   <= t.M_33 THEN 2 ELSE 3 END
    ) AS TotalScore
  FROM Compiling c
  CROSS JOIN SingleThresh t
),

FinalStatus AS (
  SELECT
    sc.MyValueId,
    sc.RecencyDays,
    sc.Frequency,
    sc.Monetary,
    sc.R_Score,
    sc.F_Score,
    sc.M_Score,
    sc.TotalScore,
    CASE
      -- 1) Always high when score = 3, or score 6–7 but stale
      WHEN sc.TotalScore = 3
           OR (sc.TotalScore BETWEEN 6 AND 7 AND sc.RecencyDays >= st.R_67)
        THEN 'High attention'

      -- 2) Healthy only if high‐scoring AND fresh
      WHEN sc.TotalScore BETWEEN 7 AND 9
           AND sc.RecencyDays < st.R_67
        THEN 'Hero Customers'

      -- 3) Everything else falls to Mid attention
      ELSE 'Mid attention'
    END AS Status
  FROM ScoredScores sc
  CROSS JOIN SingleThresh st
)

SELECT
  MyValueId,
  RecencyDays,
  Frequency,
  Monetary,
  R_Score,
  F_Score,
  M_Score,
  TotalScore,
  Status
FROM FinalStatus
ORDER BY 
  CASE Status
    WHEN 'Healthy' THEN 3
    WHEN 'Mid Attention' THEN 2
    WHEN 'High Attention' THEN 1
    ELSE 0
  END DESC,
  TotalScore DESC,
  RecencyDays ASC;

--FREQUENCT COUNT(DISTINCT TRANSACTION ID)
--LEFT JOIN MITRAATRIBUT
--WHERE MITRA-EMAIL ISNULL