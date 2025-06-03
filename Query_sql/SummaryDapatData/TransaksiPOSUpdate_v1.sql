-- data transaksi member 
SELECT TOP 50 a.TRANSACTIONID AS TRANSACTIONID 
		,a.Dataareaid AS Dataareaid 
		,a.[TRANSDATE] AS transaction_date
		,CONVERT(VARCHAR(8), DATEADD(SECOND, a.TRANSTIME,0),108) AS Time_2
		,a.RECEIPTID AS RECEIPTID
	  ,case when a.[CUSTACCOUNT] is null then a.STORE else a.CUSTACCOUNT end AS CustomerId
	  ,d.CustomerName AS CustomerName
	  ,d.MyValueId AS MyValueId
	  ,g.[EMAIL] AS email
      ,g.[PHONE] AS phone
      ,b.[ITEMID] AS ItemId
	  ,c.ItemDesc AS ItemDesc
	  ,c.DivName AS DivName
	  ,c.DeptName AS DeptName
	  ,c.ClassName AS ClassName
	  ,c.SubClassName AS SubClassName
	  ,c.ProdOwner AS ProdOwner 
	  ,a.STORE AS StoreId
	  ,e.StoreName AS StoreName
	  ,h.Regionname AS Regionname
      ,e.City AS City
	  ,e.Province AS Province
	  ,e.Latitude AS Lat
      ,e.Longitude AS Long
	  --,dm.PromotionId AS Promotion_Id
	  --,dm.Name AS Promotion_Name
	  ,(b.QTY * -1) AS Quantity
	  ,(b.NETAMOUNT * -1) AS Sales_Netto
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
  and b.TRANSDATE between '20250101' and '20250320'
  and d.MyValueId IS NOT NULL and d.MyValueId <> ''
  and b.STORE IN (10155)
  ORDER BY 3,1 ASC