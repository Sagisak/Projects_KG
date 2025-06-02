/* --HARUS MEMBER MYVALUE
 Periode Data: Januari hingga Mei 2025 --TransactionDate BETWEEN '2025-01-01' AND  '2025-05-27'
 Detail Data:  
	o Permintaan penarikan data pelanggan dari sistem MyValue untuk 
	keperluan integrasi dan aktivasi kegiatan Gramedia Jalma. Adapun 
	kriteria pelanggan yang dimaksud adalah sebagai berikut: 
		o Kriteria: 
			o Pernah berbelanja di salah satu atau lebih dari 5 toko berikut: 
					o Gramedia Grand Indonesia			--DimStore StoreId 10169 (renov, GRAMEDIA JKT MAL GRAND INDONESIA) or 81169 (New Store, GS GRAND INDONESIA)
					o Gramedia Central Park				--DimStore StoreId 10452 GRAMEDIA JKT MAL CENTRAL PARK
					o Gramedia Pondok Indah Mall (PIM)	--DimStore StoreId 10115 GRAMEDIA JKT MAL PONDOK INDAH
					o Gramedia Gandaria City			--DimStore StoreId 10180 GRAMEDIA JKT MAL GANDARIA CITY
					o Gramedia Emerald Bintaro			--DimStore StoreId 10161 GRAMEDIA EMERALD BINTARO
		o Memiliki riwayat membaca atau membeli dari ketiga department 
		berikut:														--DimProduct	GroupName:GRP BOOKS NON FICTION, GRP BOOKS FICTION
																		--				SUGGESTION: EBOOKS, digital library
					 Fiksi 
					 Non-Fiksi 
					 Komik 
		o Jenis kelamin: Pria & Wanita 
		o Telah melakukan pembelian buku minimal 2 kali dalam periode 5    --POS TABLE, COUNT(TRANSDATE) 
		bulan terakhir													
		o Memiliki nomor WhatsApp aktif, serta data nama lengkap dan 
		berada domisili Jakarta												--DimCustomer Phone, CustomerName, (DOMISILI MUNGKIN TABLE LAIN)
		o Tujuan Penggunaan: Undangan dalam housewarming opening Gramedia 
		Jalma

-Tambahkan Favourite dept, class, subclass
*/

-- data transaksi member 
with GettingData as(
SELECT 
	 a.[TRANSDATE] AS Trans_Date
	 ,a.TRANSACTIONID AS Transactions
	  ,d.MyValueId AS MyValueId
	  ,d.CustomerName AS CustomerName
      ,g.[PHONE] AS phone
	  , c.ItemID as ItemID
	  ,c.DeptName AS DeptName
	  ,c.ClassName AS ClassName
	  ,c.SubClassName AS SubClassName
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DataAreaId
  inner join [GORPDWHBI].[dbo].[DimStore] e with(nolock) on a.STORE = e.StoreId and a.DATAAREAID = e.DataAreaId
  inner join [GORPDWH365].[dbo].[MYVALUETABLE] g with(nolock) on g.VALUEID = d.MyValueId and g.DATAAREAID = d.DataAreaId
  inner join [GORPDWHBI].[dbo].[DimRegion] h with(nolock) on e.RegionId = h.RegionId 
  --left join [GORPDWH365].[dbo].[RETAILTRANSACTIONDISCOUNTTRANS] rtd with(nolock) on rtd.CHANNEL = b.CHANNEL AND rtd.STOREID = b.STORE
  --left join [GORPDWHBI].[dbo].[DimPromotion] dm with(nolock) on dm.PromotionId = rtd.PERIODICDISCOUNTOFFERID

WHERE a.TYPE in (2,19)
  and a.ENTRYSTATUS in (0,2)
  and b.TRANSACTIONSTATUS in (0,2)
  and a.RECEIPTID is not null
  and isnull(b.RECEIPTID,'')<>'' 
  and b.TRANSDATE between '20250101' and '20250527'
  and d.MyValueId IS NOT NULL and d.MyValueId <> ''
  and d.CustomerName IS NOT NULL and d.CustomerName <> ''
  and g.PHONE IS NOT NULL and g.PHONE <> ''
   AND (
       c.GroupName = 'GRP BOOKS NON FICTION'
       OR c.GroupName = 'GRP BOOKS FICTION'
      )
  AND b.STORE IN (10161, 10180, 10115, 10452, 10169) 
),

-- 1. Aggregate counts per department
DeptsTotal AS (
  SELECT
    MyValueId,
    DeptName,
    COUNT(ItemID) AS DistinctCountItem
  FROM GettingData
  GROUP BY 
    MyValueId, 
    DeptName
),

-- 2. Aggregate counts per class
ClassTotal AS (
  SELECT
    MyValueId,
    ClassName,
    COUNT(ItemID) AS DistinctCountItem
  FROM GettingData
  GROUP BY 
    MyValueId, 
    ClassName
),

-- 3. Aggregate counts per subclass
SubclassTotal AS (
  SELECT
    MyValueId,
    SubClassName,
    COUNT(ItemID) AS DistinctCountItem
  FROM GettingData
  GROUP BY 
    MyValueId, 
    SubClassName
),

-- 4. Filter MyValues who have 2 or more distinct transactions
TransactionMyValue AS (
  SELECT
    MyValueId, CustomerName, phone
  FROM GettingData
  GROUP BY 
    MyValueId, CustomerName, phone
  HAVING 
    COUNT(DISTINCT Transactions) >= 2
),

-- 5. Rank each MyValue’s departments by count (highest first), allowing ties
RankedDept AS (
  SELECT
    d.MyValueId,
    d.DeptName,
    d.DistinctCountItem,
    RANK() OVER (
      PARTITION BY d.MyValueId 
      ORDER BY d.DistinctCountItem DESC
    ) AS rk
  FROM 
    DeptsTotal AS d
    JOIN TransactionMyValue AS t
      ON d.MyValueId = t.MyValueId
),

-- 6. Rank each MyValue’s classes by count (highest first), allowing ties
RankedClass AS (
  SELECT
    c.MyValueId,
    c.ClassName,
    c.DistinctCountItem,
    RANK() OVER (
      PARTITION BY c.MyValueId 
      ORDER BY c.DistinctCountItem DESC
    ) AS rk
  FROM 
    ClassTotal AS c
    JOIN TransactionMyValue AS t
      ON c.MyValueId = t.MyValueId
),

-- 7. Rank each MyValue’s subclasses by count (highest first), allowing ties
RankedSubclass AS (
  SELECT
    s.MyValueId,
    s.SubClassName,
    s.DistinctCountItem,
    RANK() OVER (
      PARTITION BY s.MyValueId 
      ORDER BY s.DistinctCountItem DESC
    ) AS rk
  FROM 
    SubclassTotal AS s
    JOIN TransactionMyValue AS t
      ON s.MyValueId = t.MyValueId
)

-- Final selection: pick only the top-ranked (rk = 1) rows for each MyValue
SELECT distinct
  t.MyValueId,
  t.CustomerName,
  t.phone,
  rd.DeptName     AS FavoriteDept,
  rc.ClassName    AS FavoriteClass,
  rs.SubClassName AS FavoriteSubclass
FROM 
  TransactionMyValue AS t
  LEFT JOIN RankedDept AS rd
    ON t.MyValueId = rd.MyValueId 
   AND rd.rk = 1
  LEFT JOIN RankedClass AS rc
    ON t.MyValueId = rc.MyValueId 
   AND rc.rk = 1
  LEFT JOIN RankedSubclass AS rs
    ON t.MyValueId = rs.MyValueId 
   AND rs.rk = 1
ORDER BY 
   t.CustomerName,t.MyValueId;

