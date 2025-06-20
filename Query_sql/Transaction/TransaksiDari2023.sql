SELECT rs.[TransactionID] as 'ID Transaksi'
      ,rs.[TransactionDate] as 'Tanggal dan waktu transaksi'
      ,ds.StoreName  as 'Nama Toko'--perlu storename
      ,dp.ItemDesc as 'Nama Produk'
      ,dp.DeptName
      ,dp.ClassName
      ,dp.SubClassName
      ,rs.Qty       as 'Qty Produk'
      ,(rs.Netto + rs.DISCAMOUNT) / RS.QTY     as 'harga produk'   
      ,rs.promoName   as  'Nama Promosi'
      ,rs.DISCAMOUNT as 'Nilai Promosi'
       -- nilai transaksi
       , rs.Netto AS 'Nilai Transaksi'  
      ,rs.[CustomerID] as 'ID Customer'
  FROM [SharedDB].[dbo].[RetailSalesDotCom] rs with (nolock)
  inner join GORPDWHBI..DimProduct dp with (nolock) on dp.ItemID = RS.ItemId and dp.DataAreaId = rs.DataareaID
  inner join GORPDWHBI..DimStore ds with (nolock) on ds.StoreId= rs.Store and ds.DataAreaId = rs.DataareaID
  LEFT JOIN GORPDWHBI..ViewRFMMei rfm WITH (NOLOCK)
    ON rfm.MyValueId = rs.MyValueId AND rfm.Status NOT IN ('Trader')
  WHERE RS.SalesPoolID in ('001')
  and rs.TransactionDate > '2023-01-01'
  order by rs.TransactionDate asc ,rs.TransactionID DESC