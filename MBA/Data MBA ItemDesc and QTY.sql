--UNTUK MELAKUKAN VISUALISASI AWAL AGAR BISA MELIHAT TREN YANG NANTINYA AKAN DISAMAKAN DENGAN MYVALUEID dan 
--LAMA
SELECT  
    c.ItemDesc, -- opsional, boleh dihapus jika tidak dibutuhkan
	SUM(a.QTY * -1) AS QTY
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
	INNER JOIN GORPDWHBI.dbo.DimStore e with(nolock) on b.STORE = e.StoreId
WHERE 
    a.TRANSDATE BETWEEN '2024-01-01' AND '2024-12-01'
    AND (
        st.SALESPOOLID IN ('001', '030') 
        OR (st.SALESPOOLID IS NULL AND '001' IN ('001', '030'))
    )
    AND b.TYPE IN (2, 19)
    AND b.ENTRYSTATUS IN (0, 2)
    AND a.TRANSACTIONSTATUS IN (0, 2)
    AND c.DeptName = 'Dep Comics'
    AND c.DivName LIKE 'DIV BOOKS%'
    AND e.StoreName LIKE '%MARGONDA%'
    AND d.myvalueid IS NOT NULL
    AND c.DeptName IS NOT NULL
    AND st.SALESPOOLID IS NOT NULL
	GROUP BY ItemDesc
	ORDER BY QTY DESC;


	--UNTUK CARI POOL POS SAMA GRACOM / TERBARU!
	select  
c.ItemDesc, -- opsional, boleh dihapus jika tidak dibutuhkan
	SUM(a.QTY * -1) AS QTY
FROM [GORPDWH365].[dbo].[CUSTINVOICETRANS] ci with(nolock)
  inner join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = ci.ORIGSALESID AND st.DATAAREAID = ci.DATAAREAID
  INNER JOIN [GORPDWH365].[dbo].[SALESPOOL] sp WITH (NOLOCK) ON ISNULL(st.SALESPOOLID, '001') = sp.SALESPOOLID  AND st.DATAAREAID = sp.DATAAREAID AND sp.SALESPOOLID = '030'  -- Filter Hanya '030'
  inner join GORPDWHBI..DimCustomer d with(nolock) on st.CUSTACCOUNT = d.CustomerId and st.DATAAREAID = d.DataAreaId
  INNER JOIN GORPDWHBI.dbo.DimProduct c with(nolock) ON ci.ITEMID = c.ItemID AND ci.DATAAREAID = c.DataAreaId
  LEFT JOIN GORPDWHBI.dbo.DimStore e with(nolock) on c.DataAreaId = e.DataAreaId
WHERE 
 ci.invoicedate between '2023-01-01' AND '2025-05-16'
    AND (
        st.SALESPOOLID IN ('001', '030') 
        OR (st.SALESPOOLID IS NULL AND '001' IN ('001', '030'))
    )
    AND c.DeptName = 'Dep Novels'
    AND c.DivName LIKE 'DIV BOOKS%'
    AND (e.StoreName LIKE '%MARGONDA%' OR e.StoreName IS NULL)
	--and c.ItemID LIKE '%208344367%'
    AND d.myvalueid IS NOT NULL
    AND c.DeptName IS NOT NULL
    AND st.SALESPOOLID IS NOT NULL
