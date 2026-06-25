WITH ultima_posicion AS (
    SELECT DISTINCT ON (userid) userid, position 
    FROM location_logs 
    ORDER BY userid, reported_at DESC
),
centros AS (
    SELECT 'San José Centro' as zona, ST_GeogFromText('SRID=4326;POINT(-84.0775 9.9331)') as punto
    UNION ALL
    SELECT 'La Fortuna', ST_GeogFromText('SRID=4326;POINT(-84.6450 10.4709)')
    UNION ALL
    SELECT 'Puerto Viejo', ST_GeogFromText('SRID=4326;POINT(-82.7540 9.6554)')
)
SELECT 
    c.zona,
    COUNT(*) FILTER (WHERE ST_DWithin(up.position, c.punto, 100)) as "Radio 100m",
    COUNT(*) FILTER (WHERE ST_DWithin(up.position, c.punto, 500)) as "Radio 500m",
    COUNT(*) FILTER (WHERE ST_DWithin(up.position, c.punto, 1000)) as "Radio 1km"
	
FROM centros c
CROSS JOIN ultima_posicion up
JOIN criminal_records cr ON up.userid = cr.userid
WHERE cr.status = 'Sin antecedentes' AND cr.is_current = TRUE
GROUP BY c.zona;