With GettingTransaction as (
SELECT
rs.MyValueId,rs.DataareaID,
count(rs.TransactionID) as Jumlah_Transaksi,
count(rs.TransactionDate) as Jumlah_visits,
SUM(rs.Netto) as Total_Sales,
SUM(rs.Netto)/count(rs.TransactionID) as Average_sales
FROM [SharedDB].[dbo].[RetailSalesDotCom] rs with (nolock)
where SalesPoolID IN ('001')
group by MyValueId, rs.DataareaID
HAVING COUNT(CASE 
              WHEN rs.TransactionDate BETWEEN '2024-06-01' AND '2024-07-31' 
              THEN 1 ELSE 0 
           END) > 0
           and MAX(rs.TransactionDate) <= '2024-12-31'
           and sum(rs.Netto) >= 500000),

GettingTrader as (
SELECT
dc.MyValueId,
dc.DataAreaId,
dc.CustomerName,
dc.Phone,
dc.EmailAddress
from GORPDWHBI..DimCustomer dc with (nolock)
INNER JOIN GORPDWHBI..ViewRFMMei rfm WITH (NOLOCK) ON rfm.MyValueId = dc.MyValueId 
where rfm.Status  not in ('Trader') )


SELECT
gm.MyValueId,
gm.CustomerName,
gm.Phone,
gm.EmailAddress,
gt.Jumlah_Transaksi as 'Jumlah Transaksi',
gt.Jumlah_visits as 'Jumlah Visits',
gt.Total_Sales as 'Total Sales',
gt.Average_sales as 'Average Sales'
FROM GettingTrader gm
inner join GettingTransaction gt on gm.MyValueId = gt.MyValueId and gm.DataAreaId = gt.DataareaID
Order by gm.MyValueId
