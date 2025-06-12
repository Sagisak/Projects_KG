select
d.MyValueId,
d.CustomerName,
d.Phone,
d.EmailAddress,
cr.birthdate, -- null tidak apa-apa
rfm.Status
FROM gorpdwh365..retailtransactiontable a WITH (NOLOCK)
	LEFT JOIN gorpdwh365..retailtransactionsalestrans rs WITH (NOLOCK) on rs.TRANSACTIONID = a.TRANSACTIONID and rs.DATAAREAID = a.DATAAREAID
  inner join GORPDWHBI..DimCustomer d with(nolock) on isnull(a.custaccount,a.description)=d.CustomerId and a.DATAAREAID=d.DataAreaId
  inner join GORPDWH365..crm_contact cr with(nolock) on cr.kre_myvalueid = d.MyValueId
  inner join GORPDWHBI..ViewRFMMei rfm with(nolock) on rfm.MyValueId = d.MyValueId
where a.STORE in ('10103')
and isnull (d.MyValueId,'')<>''
and isnull (cr.kre_myvalueid,'')<>''
and isnull (d.phone,'')<>''
and isnull (d.CustomerName,'')<>''
AND a.CREATEDDATETIME BETWEEN '20250101' AND '20250531'
and rfm.Status in ('Hero Customer','Mid Attention','High Attention')
group by d.MyValueId, d.CustomerName, d.Phone,d.EmailAddress, cr.birthdate, rfm.Status
ORDER BY 
  CASE Status
    WHEN 'Hero Customer' THEN 3
    WHEN 'Mid Attention' THEN 2
    else 1
  END desc
, CustomerName asc;

