
	--Getting RFM

	--DECLARE @EndDt   DATE = DATEADD(DAY, -1, CAST(GETDATE() AS DATE));  -- yesterday
	DECLARE @EndDt DATE = '2025-05-28	'  --Ini kalau mau set manual tergantung periode yang dinginkan , contoh kode ini buat periode 1 January 2025
	DECLARE @StartDt DATE = DATEADD(DAY, -730, @EndDt);                 -- two years before @EndDt



		with CUSTINVOICETRANS as (
		-- data transaksi member 
	SELECT  a.TRANSACTIONID AS TRANSACTIONID 
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
	  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DataAreaId
	  --left join [GORPDWH365].[dbo].[RETAILTRANSACTIONDISCOUNTTRANS] rtd with(nolock) on rtd.CHANNEL = b.CHANNEL AND rtd.STOREID = b.STORE
	  --left join [GORPDWHBI].[dbo].[DimPromotion] dm with(nolock) on dm.PromotionId = rtd.PERIODICDISCOUNTOFFERID
	WHERE a.TYPE in (2,19)
	  and a.ENTRYSTATUS in (0,2)
	  and b.TRANSACTIONSTATUS in (0,2)
	  and a.RECEIPTID is not null
	  and isnull(b.RECEIPTID,'')<>'' 
	  and b.TRANSDATE BETWEEN @StartDt
                           AND @EndDt
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
		DATEDIFF(day, l.LastTrxDate, DATEADD(day, -1, CAST(GETDATE() AS date))) AS RecencyDays
		from GettingDATA g
		inner join TotalNetSales t on g.SalesId = t.SalesId
		INNER JOIN LastTransaction l ON g.MyValueId = l.MyValueId
		group by g.MyValueId, l.LastTrxDate
		HAVING SUM(t.net_sales) > 0
		),

	ScoredScores AS (
	  SELECT
		c.MyValueId,
		c.RecencyDays,
		c.Frequency,
		c.Monetary,
		CASE 
		  WHEN c.RecencyDays  < 90 THEN 3
		  WHEN c.RecencyDays <= 180 THEN 2
		  ELSE 1
		END AS R_Score,
		CASE
		  WHEN c.Frequency < 3 THEN 1
		  WHEN c.Frequency <= 5 THEN 2
		  ELSE 3
		END AS F_Score,
		CASE
		  WHEN c.Monetary < 200000 THEN 1
		  WHEN c.Monetary <= 500000 THEN 2
		  ELSE 3
		END AS M_Score,
		( 
		  CASE WHEN c.RecencyDays < 90 THEN 3 WHEN c.RecencyDays <= 180 THEN 2 ELSE 1 END
		+ CASE WHEN c.Frequency  < 3 THEN 1 WHEN c.Frequency  <= 5 THEN 2 ELSE 3 END
		+ CASE WHEN c.Monetary   < 200000 THEN 1 WHEN c.Monetary   <= 500000 THEN 2 ELSE 3 END
		) AS TotalScore
	  FROM Compiling c
	)


--CREATE TABLE RfmPos_DS 

/*
INSERT INTO RfmPos_DS
(
  MyValueId,
  RecencyDays,
  Frequency,
  Monetary,
  R_Score,
  F_Score,
  M_Score,
  TotalScore,
  Status,
  TanggalBerlaku,
  Period
)
*/
--Hapusin Comment untuk melakukan Insert INTO SELECT

	SELECT
  sc.MyValueId,
  sc.RecencyDays,
  sc.Frequency,
  CAST(sc.Monetary AS INT)              AS Monetary,
  sc.R_Score,
  sc.F_Score,
  sc.M_Score,
  sc.TotalScore,
  CASE
    WHEN sc.RecencyDays >= 365
      THEN 'Inactive'
    WHEN sc.TotalScore = 3
         OR (sc.TotalScore BETWEEN 6 AND 7 AND sc.RecencyDays > 180)
      THEN 'High attention'
    WHEN sc.TotalScore BETWEEN 7 AND 9
         AND sc.RecencyDays <= 180
      THEN 'Hero Customer'
    ELSE 'Mid attention'
  END AS Status,
  FORMAT(@EndDt, 'yyyy-MM-dd') as Period,
  FORMAT(GETDATE(), 'yyyy-MM-dd')       AS TanggalQueryDijalankan --TanggalBerlaku
FROM ScoredScores sc



