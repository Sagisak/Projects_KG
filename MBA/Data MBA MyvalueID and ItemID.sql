SELECT 
DISTINCT d.MyValueId AS MyValueID, -- opsional, boleh dihapus jika tidak dibutuhkan
	c.ItemID,
	c.ItemDesc,
	e.StoreName
 FROM GORPDWH365.dbo.RETAILTRANSACTIONSALESTRANS a with(nolock)
    INNER JOIN GORPDWH365.dbo.RETAILTRANSACTIONTABLE b with(nolock)
        ON a.TRANSACTIONID = b.TRANSACTIONID 
    INNER JOIN GORPDWHBI.dbo.DimProduct c with(nolock)
        ON a.ITEMID = c.ItemID AND a.DATAAREAID = c.DataAreaId
    INNER JOIN GORPDWHBI.dbo.DimCustomer d with(nolock)
        ON a.CUSTACCOUNT = d.CustomerId AND a.DATAAREAID = d.DataAreaId
    INNER JOIN GORPDWH365.dbo.SALESTABLE st with(nolock)
        ON st.DATAAREAID = a.DATAAREAID
    LEFT JOIN GORPDWH365.dbo.SALESPOOL sp with(nolock)
        ON (st.SALESPOOLID = sp.SALESPOOLID OR (st.SALESPOOLID IS NULL AND sp.SALESPOOLID = '001'))
        AND st.DATAAREAID = sp.DATAAREAID
	LEFT JOIN GORPDWHBI.dbo.DimStore e with(nolock) on b.STORE = e.StoreId
WHERE 
    a.TRANSDATE >= '2023-01-01'
    AND (
        st.SALESPOOLID IN ('001', '030') 
        OR (st.SALESPOOLID IS NULL AND '001' IN ('001', '030'))
    )
    AND b.TYPE IN (2, 19)
    AND b.ENTRYSTATUS IN (0, 2)
    AND a.TRANSACTIONSTATUS IN (0, 2)
    AND c.DeptName = 'Dep Novels'
    AND c.DivName LIKE 'DIV BOOKS%'
    AND (e.StoreName LIKE '%MARGONDA%' OR e.StoreName IS NULL)
	--and c.ItemID LIKE '%208344367%'
    AND d.myvalueid IS NOT NULL
    AND c.DeptName IS NOT NULL
    AND st.SALESPOOLID IS NOT NULL
	--GROUP BY ItemDesc
	--ORDER BY QTY DESC;
	--GRACOMNYA HARUS ADA


--data set MBA untuk per item
	select  
		d.MyValueId AS MyValueID, -- opsional, boleh dihapus jika tidak dibutuhkan
	c.ItemID,
	c.ItemDesc,
	st.INVENTLOCATIONID,
	isnull (st.SALESPOOLID,'001') SALESPOOLID
FROM [GORPDWH365].[dbo].[CUSTINVOICETRANS] ci with(nolock)
  INNER join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = ci.ORIGSALESID AND st.DATAAREAID = ci.DATAAREAID
  INNER JOIN [GORPDWH365].[dbo].[SALESPOOL] sp WITH (NOLOCK) ON ISNULL(st.SALESPOOLID, '001') = sp.SALESPOOLID  AND st.DATAAREAID = sp.DATAAREAID 
  inner join GORPDWHBI..DimCustomer d with(nolock) on st.CUSTACCOUNT = d.CustomerId and st.DATAAREAID = d.DataAreaId
  INNER JOIN GORPDWHBI.dbo.DimProduct c with(nolock) ON ci.ITEMID = c.ItemID AND ci.DATAAREAID = c.DataAreaId
WHERE ci.invoicedate BETWEEN '2023-01-01' AND '2025-05-14'
    AND (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030') --001 = POS --030 = GRAMEDIA.COM
	--AND st.SALESPOOLID = '001'
	--AND st.SALESPOOLID = '030'
	--AND st.SALESPOOLID IS NULL
    AND c.DeptName = 'Dep Novels'
    AND c.DivName LIKE 'DIV BOOKS%'
    AND d.myvalueid IS NOT NULL 
	AND isnull (d.MyValueId,'')<>''
    AND c.DeptName IS NOT NULL
    --AND st.SALESPOOLID IS NOT NULL
	AND st.INVENTLOCATIONID IN ('10150','10196') -- 10150 GRAMEDIA DEPOK MARGONDA and 10196 GRAMEDIA.COM
ORDER BY st.INVENTLOCATIONID desc



--data set MBA untuk per item
	select  
		distinct c.MyValueId AS MyValueID, -- opsional, boleh dihapus jika tidak dibutuhkan
	d.ItemID,
	d.ItemDesc,
	st.INVENTLOCATIONID,
	isnull (st.SALESPOOLID,'001') SALESPOOLID
FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] a
  inner join [GORPDWH365].[dbo].RETAILTRANSACTIONTABLE b on a.TRANSACTIONID = b.TRANSACTIONID and a.DATAAREAID = b.DATAAREAID
left join gorpdwhbi..dimcustomer c with(nolock) on isnull(a.custaccount,b.description)=c.CustomerId and a.DATAAREAID=b.DataAreaId
  INNER join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = b.SALESORDERID AND st.DATAAREAID = a.DATAAREAID
  INNER JOIN [GORPDWH365].[dbo].[SALESPOOL] sp WITH (NOLOCK) ON ISNULL(st.SALESPOOLID, '001') = sp.SALESPOOLID  AND st.DATAAREAID = sp.DATAAREAID 
  --inner join GORPDWHBI..DimCustomer d with(nolock) on st.CUSTACCOUNT = d.CustomerId and st.DATAAREAID = d.DataAreaId
  INNER JOIN GORPDWHBI.dbo.DimProduct d with(nolock) ON a.ITEMID = d.ItemID AND a.DATAAREAID = d.DataAreaId
WHERE a.TRANSDATE BETWEEN '2023-01-01' AND '2025-05-14'
    AND (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030') --001 = POS 030 = GRAMEDIA.COM
	--AND st.SALESPOOLID = '001'
	--AND st.SALESPOOLID = '030'
	--AND st.SALESPOOLID IS NULL
    AND d.DeptName = 'Dep Novels'
    AND d.DivName LIKE 'DIV BOOKS%'
    AND c.myvalueid IS NOT NULL 
	AND isnull (c.MyValueId,'')<>''
    AND d.DeptName IS NOT NULL
    --AND st.SALESPOOLID IS NOT NULL
	AND st.INVENTLOCATIONID IN ('10150','10196') -- 10150 GRAMEDIA DEPOK MARGONDA and 10196 GRAMEDIA.COM
ORDER BY st.INVENTLOCATIONID desc

--TERBARU SISA DIBENERIN
SELECT distinct d.MyValueId AS MyValueId, --96892
	  c.ItemDesc AS ItemDesc
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
	AND c.ItemDesc IN (
    'PULANG (2023)',
    'CANTIK ITU LUKA',
    'NAMAKU ALAM JILID 1',
    'TERUSLAH BODOH JANGAN PINTAR',
    'MALIOBORO AT MIDNIGHT',
    'HUJAN',
    'DOMPET AYAH SEPATU IBU',
    'TENTANG KAMU',
    'FUNICULI FUNICULA (BEFORE THE COFFEE GETS COLD)',
    'HELLO'
)
AND d.MyValueId NOT IN (
    SELECT DISTINCT MyValueId
    FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DATAAREAID
    WHERE c.ItemDesc = 'LAUT BERCERITA'
)
--AND c.ItemDesc IN ('LAUT BERCERITA')
--GROUP BY ItemDesc




