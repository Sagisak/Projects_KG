-- Ambil transaksi pembelian novel oleh member
WITH MemberTransactions AS (
   SELECT distinct d.MyValueId AS MyValueId,
	  c.ItemDesc AS ItemDesc,
	  d.EmailAddress as email
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DATAAREAID
WHERE b.TRANSDATE BETWEEN '2023-01-01' AND '2025-05-20'
    AND c.DeptName = 'Dep Novels'
    AND c.DivName LIKE 'DIV BOOKS%'
    AND d.myvalueid IS NOT NULL 
	AND isnull (d.MyValueId,'')<>''
    AND c.DeptName IS NOT NULL
    AND d.CustGroup = 'KGVC'
),
-- Filter hanya member yang belum menjadi mitra (belum ada di tabel MitraAtribut)
UnregisteredMembers AS (
    SELECT DISTINCT 
        mt.MyValueId,
        mt.ItemDesc,
		mt.email
        --mt.SalesId
    FROM MemberTransactions mt
    LEFT JOIN GORPDWHBI.dbo.MitraAtribut ma WITH(NOLOCK) ON mt.email = ma.email
    WHERE ma.email IS NULL
)

-- Hasil akhir
SELECT 
    *
FROM UnregisteredMembers
ORDER BY MyValueID ASC 

--VERSI KEDUA
WITH MemberTransactions AS (
   SELECT distinct d.MyValueId AS MyValueId,
	  c.ItemDesc AS ItemDesc,
	  d.EmailAddress as email,
	  e.StoreName,
	  c.DeptName
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DATAAREAID
  inner join GORPDWH365.dbo.DimStore e with(nolock) on a.STORE = e.StoreId and a.DATAAREAID = e.DataAreaId
WHERE b.TRANSDATE BETWEEN '2023-01-01' AND '2025-05-21'
    AND c.DeptName IN ('Dep Novels','Dep Comics', 'Dep Self Improvement')
    AND c.DivName LIKE 'DIV BOOKS%'
    AND d.myvalueid IS NOT NULL 
	AND isnull (d.MyValueId,'')<>''
    AND c.DeptName IS NOT NULL
    AND d.CustGroup = 'KGVC'
    and e.StoreId = '10150'
),
-- Filter hanya member yang belum menjadi mitra (belum ada di tabel MitraAtribut)
UnregisteredMembers AS (
    SELECT DISTINCT 
        mt.MyValueId,
        mt.ItemDesc
		--mt.email
		--mt.StoreName
        --mt.SalesId
    FROM MemberTransactions mt
    LEFT JOIN GORPDWHBI.dbo.MitraAtribut ma WITH(NOLOCK) ON mt.email = ma.email
    WHERE ma.email IS NULL
)

-- Hasil akhir
SELECT 
    *
FROM UnregisteredMembers
ORDER BY MyValueID ASC 
