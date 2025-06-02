SELECT 
    m.name AS CustomerName,
    d.MyValueId AS MyValueId,
    m.email AS email,
    d.Phone AS phone
FROM 
    [GORPDWHBI]..MitraAtribut m WITH (NOLOCK)
LEFT JOIN 
     [GORPDWHBI]..DimCustomer d WITH (NOLOCK)
    ON m.email = d.EmailAddress
    group by 
    m.name,
    d.MyValueId,
    m.email,
    d.Phone
ORDER BY 
    name asc-- or m.email if you prefer

    
