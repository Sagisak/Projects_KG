With GettingTransaction as (
SELECT
rs.MyValueId,rs.DataareaID,
count(rs.TransactionID) as Jumlah_Transaksi,
count(rs.TransactionDate) as Jumlah_visits,
SUM(rs.Netto) as Total_Sales,
SUM(rs.Netto)/count(rs.TransactionID) as Average_sales
FROM [SharedDB].[dbo].[RetailSalesDotCom] rs with (nolock)

group by MyValueId, rs.DataareaID
,

GettingTrader as (
SELECT
dc.MyValueId,
dc.DataAreaId,
dc.CustomerName,
dc.Phone,
dc.EmailAddress
from GORPDWHBI..DimCustomer dc with (nolock)
INNER JOIN GORPDWHBI..ViewRFMMei rfm WITH (NOLOCK) ON rfm.MyValueId = dc.MyValueId 
where rfm.Status in ('Trader') )


SELECT
gm.MyValueId,
gm.CustomerName,
gm.Phone,
gm.EmailAddress,
count(rs.TransactionID) as Jumlah_Transaksi,
count(rs.TransactionDate) as Jumlah_visits,
SUM(rs.Netto) as Total_Sales,
SUM(rs.Netto)/count(rs.TransactionID) as Average_sales
FROM [SharedDB].[dbo].[RetailSalesDotCom] rs with (nolock)
inner join GORPDWHBI..DimCustomer gm WITH (NOLOCK) on gm.MyValueId = rs.MyValueId and gm.DataAreaId = RS.DataareaID
inner join GORPDWHBI..ViewRFMMei rfm WITH (NOLOCK) ON rfm.MyValueId = gm.MyValueId and rfm.Status in ('Trader')
where SalesPoolID IN ('001')
group by gm.MyValueId, gm.CustomerName, gm.Phone, gm.EmailAddress
HAVING COUNT(CASE 
              WHEN rs.TransactionDate BETWEEN '2024-06-01' AND '2024-07-31' 
              THEN 1 ELSE 0 
           END) > 0
           and MAX((rs.TransactionDate) <= '2024-12-31')
Order by gm.MyValueId
