/*request customer profile emerald bintaro (10161):
- periode: jan to 11 mei 2025 
- 1. Demografi member Emerald Bintaro : Umur, Gender 
- 2. Jumlah member aktif (di periode tersebut) & frekuensi member ke store (ini dari aku)*/
With TotalNetSales as (
select distinct
st.SALESID as SalesId,
ci.INVOICEDATE as transaction_date
FROM [GORPDWH365].[dbo].[CUSTINVOICETRANS] ci with(nolock) --data transaksi dari tabel ini
  inner join [GORPDWH365].[dbo].[SALESTABLE] st with(nolock) on st.SALESID = ci.ORIGSALESID AND st.DATAAREAID = ci.DATAAREAID --data transaksi dari tabel ini 
  inner join [GORPDWH365].[dbo].[SALESPOOL]sp with(nolock) on sp.SALESPOOLID = isnull (st.SALESPOOLID,'001') AND st.DATAAREAID=sp.DATAAREAID
  inner join GORPDWHBI..DimProduct p  with(nolock) on ci.ITEMID = p.ItemID
where (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030')
and ci.INVOICEDATE BETWEEN '20250101' AND '20250511'
and st.INVENTLOCATIONID in ('10161')

),

GettingDATA as(
SELECT DISTINCT --Kolom myvalueid, phone_number, email, jumlah transaksi, net_sales
d.MyValueId,
d.CustomerName,
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
WHERE  ci.INVOICEDATE BETWEEN '20250101' AND '20250511'
and (isnull (st.SALESPOOLID,'001') ='001' or isnull (st.SALESPOOLID,'001')='030')
and isnull (d.MyValueId,'')<>''
and isnull (d.MyValueId,'')<>''
and st.INVENTLOCATIONID in ('10161')
)

Select 
g.MyValueId,
g.CustomerName,
g.Gender,
count(t.transaction_date) as total_visit
from GettingDATA g
inner join TotalNetSales t on g.SalesId = t.SalesId
group by g.MyvalueId, g.Gender, g.CustomerName
order by  g.MyValueId 