--Getting RFM

	DECLARE @StartDt date = DATEADD(day, -730, CAST(GETDATE() AS date));  -- one year ago
	DECLARE @EndDt   date = DATEADD(day, -1, CAST(GETDATE() AS date));       -- yesterday
	
	-- data transaksi member 
SELECT  a.TRANSACTIONID AS TRANSACTIONID 
		,a.[TRANSDATE] AS transaction_date
	  ,d.MyValueId AS MyValueId
	  ,d.EmailAddress as email
      ,b.[ITEMID] AS ItemId
	  ,(b.QTY * -1) AS Quantity
	  ,(b.NETAMOUNT * -1) AS Sales_Netto
 FROM [GORPDWH365].[dbo].[RETAILTRANSACTIONTABLE] a with(nolock)
  inner join [GORPDWH365].[dbo].[RETAILTRANSACTIONSALESTRANS] b with(nolock) on b.TRANSACTIONID = a.TRANSACTIONID and b.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimProduct c with(nolock) on b.ITEMID = c.ItemID and b.DATAAREAID = c.DataAreaId
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=b.DataAreaId
WHERE a.TYPE in (2,19)
  and a.ENTRYSTATUS in (0,2)
  and b.TRANSACTIONSTATUS in (0,2)
  and a.RECEIPTID is not null
  and isnull(b.RECEIPTID,'')<>'' 
  and b.TRANSDATE between @StartDt and @EndDt
  and d.MyValueId IS NOT NULL and d.MyValueId <> ''
  and d.CustGroup = 'KGVC'