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
	  ,c. GroupName as GroupName
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

-- 1. Aggregate counts per (Dept, Class, Subclass) into a single string
DeptsClassSubclassTotal AS (
  SELECT
    MyValueId,
    DeptName,
	GroupName,
    COUNT(ItemID) AS DistinctCountItem
  FROM GettingData
  GROUP BY 
    MyValueId,
    DeptName, GroupName
),

-- 2. Filter MyValues who have 2 or more distinct transactions
TransactionMyValue AS (
  SELECT
    MyValueId,
    CustomerName,
    phone,
	count(DISTINCT Transactions) as Total_Transaction
  FROM GettingData
  GROUP BY 
    MyValueId,
    CustomerName,
    phone
  HAVING 
    COUNT(DISTINCT Transactions) >= 2
),

-- 3. Rank each MyValue’s full categories by count (highest first), allowing ties
RankedFullCategory AS (
  SELECT
    dcs.MyValueId,
    dcs.DeptName,
	dcs.GroupName,
    dcs.DistinctCountItem,
    ROW_NUMBER() OVER (
      PARTITION BY dcs.MyValueId 
      ORDER BY dcs.DistinctCountItem DESC
    ) AS rk
  FROM 
    DeptsClassSubclassTotal AS dcs
    JOIN TransactionMyValue AS t
      ON dcs.MyValueId = t.MyValueId
)

-- Final selection: pick only the top-ranked (rk = 1) full category per MyValue
SELECT DISTINCT
  t.MyValueId,
  t.CustomerName,
  t.phone,
  rf.DeptName,
  rf.GroupName as GroupName,
  rf.DistinctCountItem,
  t.Total_Transaction
FROM 
  TransactionMyValue AS t
  LEFT JOIN RankedFullCategory AS rf
    ON t.MyValueId = rf.MyValueId 
   AND rf.rk = 1
ORDER BY 
t.Total_Transaction desc;


/*(
   SELECT
  MemberId,
  CONCAT(DeptName, ' - ', ClassName, ' - ', SubClassName) AS FullCategoryName,
  COUNT(ItemID) AS DistinctCountItem
FROM GettingData
GROUP BY 
  MemberId,
  CONCAT(DeptName, ' - ', ClassName, ' - ', SubClassName);
  */