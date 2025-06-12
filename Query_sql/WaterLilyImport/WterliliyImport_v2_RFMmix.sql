With TotalNetSales as (
select
st.SALESID as SalesId,
sum(distinct ci.LINEAMOUNT) as price,
sum(ci.qty) as qty
FROM [GORPDWH365].[dbo].[CUSTINVOICETRANS] ci with(nolock) --data transaksi dari tabel ini
  inner join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = ci.ORIGSALESID AND st.DATAAREAID = ci.DATAAREAID --data transaksi dari tabel ini 
  inner join [GORPDWH365].[dbo].[SALESPOOL]sp with(nolock) on sp.SALESPOOLID = isnull (st.SALESPOOLID,'001') AND st.DATAAREAID=sp.DATAAREAID
  inner join GORPDWHBI..DimProduct p  with(nolock) on ci.ITEMID = p.ItemID
where p.ProdOwner in ('WATER LILY DISTRIBUTION','IMPORT BOOKS')
and (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030')
and ci.INVOICEDATE BETWEEN '20250101' AND '20250531'
group by st.SALESID
),

GettingDATA as(
SELECT DISTINCT --Kolom myvalueid, phone_number, email, jumlah transaksi, net_sales
d.MyValueId,
gm.Gender,
d.Phone,
d.EmailAddress,
d.Profession,
st.SALESID as SalesId
FROM [GORPDWH365].[dbo].[CUSTINVOICETRANS] ci with(nolock) --data transaksi dari tabel ini
  inner join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = ci.ORIGSALESID AND st.DATAAREAID = ci.DATAAREAID --data transaksi dari tabel ini 
  inner join [GORPDWH365].[dbo].[SALESPOOL]sp with(nolock) on sp.SALESPOOLID = isnull (st.SALESPOOLID,'001') AND st.DATAAREAID=sp.DATAAREAID
  inner join GORPDWHBI..DimCustomer d with(nolock) on st.CUSTACCOUNT = d.CustomerId and st.DATAAREAID = d.DataAreaId 
  inner join GORPDWHBI..DimProduct p   with(nolock) on ci.ITEMID = p.ItemID
  inner join GORPDWHBI..ViewMasterDataGenderMember gm   with(nolock) on gm.MyValueId = d.MyValueId
  inner join GORPDWHBI..ViewRFMMei rfm with(nolock) on d.MyValueId = rfm.MyValueId
WHERE  ci.INVOICEDATE BETWEEN '20250101' AND '20250531'
and (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030')
and isnull (d.MyValueId,'')<>''
and isnull (d.phone,'')<>''
and isnull (d.EmailAddress,'')<>''
and isnull (gm.gender,'')<>''
and rfm.Status in ('Hero Customer', 'Mid attention')
and p.ProdOwner in ('WATER LILY DISTRIBUTION','IMPORT BOOKS')
)

Select 
g.MyValueId,
g.Gender,
g.Profession,
g.Phone,
g.EmailAddress,
count(g.SalesId) as jumlah_transaksi,
sum(t.price) as net_sales,
sum (t.qty) as	qty
from GettingDATA g
inner join TotalNetSales t on g.SalesId = t.SalesId
group by g.MyValueId, g.Phone, g.EmailAddress, g.gender, G.Profession
HAVING SUM(t.price) > 0
order by jumlah_transaksi DESC, net_sales DESC