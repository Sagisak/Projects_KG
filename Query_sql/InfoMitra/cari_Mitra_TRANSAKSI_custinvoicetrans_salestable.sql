SELECT 
	  m.name  AS CustomerName
	  ,d.MyValueId AS MyValueId
	  ,m.email AS email
      ,d.Phone AS phone
	  FROM
	  [GORPDWHBI]..[MitraAtribut] m with(nolock)
	  left join GORPDWHBI..DimCustomer d with(nolock) on m.email = d.EmailAddress
	   inner join [GORPDWH365].[dbo].SALESTABLE b with(nolock) on  b.CUSTACCOUNT=d.CustomerId and d.DataAreaId=b.DataAreaId 
	inner join [GORPDWH365].dbo.CUSTINVOICETRANS a with(nolock) on b.SALESID  = a.SALESID and b.DATAAREAID = a.DATAAREAID
  --left join [GORPDWH365].[dbo].[RETAILTRANSACTIONDISCOUNTTRANS] rtd with(nolock) on rtd.CHANNEL = b.CHANNEL AND rtd.STOREID = b.STORE
  --left join [GORPDWHBI].[dbo].[DimPromotion] dm with(nolock) on dm.PromotionId = rtd.PERIODICDISCOUNTOFFERID
WHERE 
  a.INVOICEDATE between '20240101' and '20250521'
  and m.email is not null and m.email <> ''
  group by m.name, d.MyValueId, m.email, d.Phone
  order by m.name