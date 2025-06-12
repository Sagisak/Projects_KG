CREATE VIEW ViewRFMMei as 
	--Getting RFM

with CUSTINVOICETRANS as (
		-- data transaksi member 
	SELECT  rs.TRANSACTIONID AS TRANSACTIONID 
			,rs.TransactionDate AS transaction_date
		  ,rs.MyValueId AS MyValueId
		  ,d.EmailAddress as email
		  ,rs.ItemId AS ItemId
		  --,dm.PromotionId AS Promotion_Id
		  --,dm.Name AS Promotion_Name
		  ,rs.qty AS Quantity
		  ,rs.Netto AS Sales_Netto
	 FROM SharedDB..RetailSalesDotCom rs with (nolock)
	  inner join GORPDWHBI..DimCustomer d with(nolock) on rs.CustomerID=d.CustomerId and rs.DataareaID=d.DataAreaId
	  --left join [GORPDWH365].[dbo].[RETAILTRANSACTIONDISCOUNTTRANS] rtd with(nolock) on rtd.CHANNEL = b.CHANNEL AND rtd.STOREID = b.STORE
	  --left join [GORPDWHBI].[dbo].[DimPromotion] dm with(nolock) on dm.PromotionId = rtd.PERIODICDISCOUNTOFFERID
	WHERE  rs.TransactionDate BETWEEN  DATEADD(year, -2, '20250531')
                           AND '20250531'
	  and rs.MyValueId IS NOT NULL and rs.MyValueId <> ''
	  and rs.SalesPoolID in ('001')
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
		select SalesId, sum(net_sales) as net_sales, sum(qty) as qty
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
		ci.email,
		CI.TRANSACTIONID as SalesId
		FROM [CUSTINVOICETRANS] ci with(nolock) --data transaksi dari tabel ini
		),

		Compiling as (
		select
		g.MyValueId,
		g.email,
		count(g.SalesId) AS Frequency,
		sum(t.net_sales) as Monetary,
		sum(t.qty) as qty,
		l.LastTrxDate,
		DATEDIFF(day, l.LastTrxDate, DATEADD(day, -1, CAST(GETDATE() AS date))) AS RecencyDays
		from GettingDATA g 
		inner join TotalNetSales t on g.SalesId = t.SalesId
		INNER JOIN LastTransaction l ON g.MyValueId = l.MyValueId
		group by g.MyValueId, l.LastTrxDate , g.email
		HAVING SUM(t.net_sales) > 0
		),

	ScoredScores AS (
	  SELECT
		c.MyValueId,
		c.email,
		c.RecencyDays,
		c.Frequency,
		c.Monetary,
		c.qty,
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
  WHEN m.email IS NOT NULL 
    OR ( sc.qty > 60 
         AND sc.Frequency / sc.qty < 0.12 )
    THEN 'Trader'
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
  iif((select count(1) from [GORPDWHBI].[dbo].[MitraAtribut] where email = sc.email ) = 0, 0 ,1)  'Mitra (Non-mitra = 0, Mitra = 1)',
  FORMAT(CONVERT(DATE, '20250531', 112), 'yyyy-MM-dd') as Period,
  FORMAT(GETDATE(), 'yyyy-MM-dd')       AS TanggalQueryDijalankan --TanggalBerlaku

FROM ScoredScores sc
left join GORPDWHBI..MitraAtribut m with(nolock) ON  sc.email = m.email;
