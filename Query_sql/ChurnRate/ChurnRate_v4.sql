WITH ActivePerMonth AS (
SELECT 
		CONVERT(char(7), a.transdate, 120) AS MonthKey,
		COUNT(DISTINCT e.customerid) AS ActiveCount,
		s.storeId as StoreId ,
		s.storeName as StoreName
		FROM gorpdwh365..retailtransactiontable a WITH (NOLOCK)
	LEFT JOIN gorpdwh365..retailtransactionsalestrans b WITH (NOLOCK) ON a.transactionid = b.transactionid
	--INNER JOIN gorpdwh365..RETAILTRANSACTIONDISCOUNTTRANS c WITH (NOLOCK) ON b.transactionid = c.transactionid AND b.LINENUM = c.LINENUM
	LEFT JOIN gorpdwhbi..dimcustomer e with(nolock) on isnull(a.custaccount,a.description)=e.CustomerId and a.DATAAREAID=e.DataAreaId
	LEFT JOIN gorpdwhbi..DimStore s  WITH (NOLOCK) ON a.STORE = s.StoreId AND a.DATAAREAID = s.DataAreaId
	left join GORPDWHBI..MitraAtribut ma with(nolock) on e.EmailAddress = ma.email
	INNER JOIN gorpdwhbi..DataMemberReferralTokoAkuisisi t  WITH (NOLOCK)ON s.StoreId = t.referral_from and t.myvalue_id = e.MyValueId
	LEFT join [GORPDWHBI].[dbo].[DimRegion]  h WITH (NOLOCK) on s.RegionId = h.RegionId 
	WHERE 
		a.transdate BETWEEN '20221201' AND EOMONTH(DATEADD(MONTH, -1, GETDATE()))
		AND b.transactionstatus IN (0, 2)  
		AND ISNULL(b.RECEIPTID, '') <> '' 
		AND TYPE IN (2, 19) 
		AND a.ENTRYSTATUS IN (0, 2)
		--and left(a.COMMENT_,1)<>'v' 
		AND (left(a.COMMENT_,1)='v' OR e.MyValueId IS NOT NULL)
		AND e.CustomerId IS NOT NULL
		AND t.myvalue_id IS NOT NULL
		and ma.email IS NULL
		AND t.myvalue_id <> ''
		AND t.referral_from <> ''
		AND t.referral_from IS NOT NULL
	GROUP BY CONVERT(char(7), a.transdate, 120), s.StoreId, s.StoreName
	),

FirstTrans AS (
SELECT
t.myvalue_id,
    MIN(
      CASE
        -- compare the two dates row by row
        WHEN a.TransDate < b.TransDate THEN a.TransDate
        ELSE b.TransDate
      END
    ) AS FirstTransDate,
	s.storeId as StoreId ,
	s.storeName as StoreName
  FROM gorpdwh365..retailtransactiontable a WITH (NOLOCK)
	LEFT JOIN gorpdwh365..retailtransactionsalestrans b WITH (NOLOCK) ON a.transactionid = b.transactionid
	LEFT JOIN gorpdwhbi..dimcustomer e with(nolock) on isnull(a.custaccount,a.description)=e.CustomerId and a.DATAAREAID=e.DataAreaId
	LEFT JOIN gorpdwhbi..DimStore s WITH (NOLOCK) ON a.STORE = s.StoreId AND a.DATAAREAID = s.DataAreaId
	INNER JOIN gorpdwhbi..DataMemberReferralTokoAkuisisi t WITH (NOLOCK) ON s.StoreId = t.referral_from and t.myvalue_id = e.MyValueId
	LEFT join [GORPDWHBI].[dbo].[DimRegion] h WITH (NOLOCK) on s.RegionId = h.RegionId
  WHERE t.Referral_From IS NOT NULL
		AND b.transactionstatus IN (0, 2)  
		AND ISNULL(b.RECEIPTID, '') <> '' 
		AND TYPE IN (2, 19) 
		AND a.ENTRYSTATUS IN (0, 2)
		--and left(a.COMMENT_,1)<>'v'
		AND (left(a.COMMENT_,1)='v' OR e.MyValueId IS NOT NULL)
		AND e.CustomerId IS NOT NULL
		AND t.myvalue_id IS NOT NULL
		AND t.myvalue_id <> ''
		AND t.referral_from <> ''
		AND t.referral_from IS NOT NULL
  GROUP BY t.myvalue_id, s.StoreId, s.StoreName),

	NewPerMonth AS (
	SELECT
    -- now bucket that earliest date into YYYY‑MM
    CONVERT(char(7), FirstTransDate, 120) AS MonthKey,
    COUNT(DISTINCT myvalue_id)              AS NewCount,
	StoreId,
	StoreName
  FROM FirstTrans
  WHERE FirstTransDate BETWEEN '2023-05-01' AND EOMONTH(DATEADD(MONTH, -1, GETDATE()))
  GROUP BY CONVERT(char(7), FirstTransDate, 120), StoreId, StoreName
	),

AggData AS (
SELECT
  a.MonthKey as Tahun_Bulan,
  a.ActiveCount as Jumlah_Memb_Aktif_Periode,
  n.NewCount as jumlah_member_baru,
  a.StoreId,
  a.StoreName
FROM ActivePerMonth a
FULL OUTER JOIN NewPerMonth n
  ON a.MonthKey = n.MonthKey and a.StoreId = n.StoreId
),

 ProcessData AS (
    SELECT
		StoreId,
		StoreName,
        Tahun_Bulan,     
        LAG(Jumlah_Memb_Aktif_Periode) OVER (ORDER BY StoreId, Tahun_Bulan) AS Jumlah_Memb_Aktif_Awal_Periode,
        Jumlah_Memb_Aktif_Periode AS Jumlah_Memb_Aktif_Akhir_Periode,
        jumlah_member_baru
    FROM AggData
),
Calculated AS (
    SELECT 
		StoreId,
		StoreName,
        Tahun_Bulan, 
        Jumlah_Memb_Aktif_Awal_Periode, 
        Jumlah_Memb_Aktif_Akhir_Periode,
        jumlah_member_baru, 
        (Jumlah_Memb_Aktif_Awal_Periode + jumlah_member_baru - Jumlah_Memb_Aktif_Akhir_Periode) AS jumlah_member_Berhenti
    FROM ProcessData
)
SELECT
	StoreId,
	StoreName,
    LEFT(Tahun_Bulan, 4) AS Tahun,
    RIGHT(Tahun_Bulan, 2) AS Bulan,
    Jumlah_Memb_Aktif_Awal_Periode, 
    Jumlah_Memb_Aktif_Akhir_Periode,
    jumlah_member_baru,
    jumlah_member_Berhenti,
    CASE 
      WHEN Jumlah_Memb_Aktif_Awal_Periode = 0 THEN 0
      ELSE 
		CAST(jumlah_member_Berhenti * 100.0 
    / (
        (Jumlah_Memb_Aktif_Awal_Periode 
         + Jumlah_Memb_Aktif_Akhir_Periode
        ) / 2.0
      ) AS DECIMAL(5,2))
    END AS 'churn rate (%)'
	
FROM Calculated
WHERE
CAST(REPLACE(Tahun_Bulan, '-', '') AS INT) 
        BETWEEN 202306 AND CAST(FORMAT(EOMONTH(DATEADD(MONTH, -1, GETDATE())), 'yyyyMM') AS INT)
ORDER BY
	StoreId,
    -- Year ascending
    CAST(LEFT(Tahun_Bulan, 4) AS INT) ASC,
    -- Month ascending
    CAST(RIGHT(Tahun_Bulan, 2) AS INT) ASC