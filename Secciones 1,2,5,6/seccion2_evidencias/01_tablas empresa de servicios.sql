
Create database Prueba_Tecnica_Sura;

Use Prueba_Tecnica_Sura;



CREATE TABLE clientes (
    id_cliente        INT PRIMARY KEY,
    nombre            VARCHAR(100),
    sector            VARCHAR(50),
    clase_riesgo      INT,        
    estado            VARCHAR(20),   
    fecha_vinculacion DATE
);

CREATE TABLE trabajadores (
    id_trabajador  INT PRIMARY KEY,
    id_cliente     INT REFERENCES clientes(id_cliente),
    nombre         VARCHAR(100),
    fecha_ingreso  DATE,
    estado         VARCHAR(20)
);

CREATE TABLE casos (
    id_caso           INT PRIMARY KEY,
    id_cliente        INT REFERENCES clientes(id_cliente),
    id_trabajador     INT NULL,
    fecha_ocurrencia  DATE,
    tipo              VARCHAR(10), 
    dias_ausencia     INT,
    costo             DECIMAL(14,2),
    estado            VARCHAR(20)
);

CREATE TABLE facturacion (
    id_cliente            INT REFERENCES clientes(id_cliente),
    periodo               DATE,
    trabajadores_activos  INT,
    valor_contrato        DECIMAL(14,2),
    PRIMARY KEY (id_cliente, periodo)
);

CREATE TABLE prevencion (
    id_actividad   INT PRIMARY KEY,
    id_cliente     INT REFERENCES clientes(id_cliente),
    fecha          DATE,
    tipo           VARCHAR(50),
    participantes  INT
);
GO

/* --------------------------------------------------------------------
   Insercion de clientes (40 clientes, 5 sectores, riesgo 1-5)
   -------------------------------------------------------------------- */
DECLARE @i INT = 1;
DECLARE @sectores TABLE (n INT IDENTITY(0,1), sector VARCHAR(50));
INSERT INTO @sectores (sector) VALUES ('Manufactura'),('Logística'),('Retail'),('Construcción'),('Servicios');

WHILE @i <= 40
BEGIN
    INSERT INTO clientes (id_cliente, nombre, sector, clase_riesgo, estado, fecha_vinculacion)
    SELECT
        @i,
        'Cliente ' + CAST(@i AS VARCHAR),
        (SELECT sector FROM @sectores WHERE n = @i % 5),
        1 + (@i % 5),
        'activo',
        DATEADD(month, -1 * (12 + (@i % 24)), CAST(GETDATE() AS DATE));
    SET @i += 1;
END
GO

/* --------------------------------------------------------------------
   Insercion de Facturación: últimos períodos mensuales por cliente
   -------------------------------------------------------------------- */
DECLARE @c INT, @m INT;
DECLARE cur CURSOR FOR SELECT id_cliente FROM clientes;
OPEN cur;
FETCH NEXT FROM cur INTO @c;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @m = 0;
    WHILE @m < 8
    BEGIN
        INSERT INTO facturacion (id_cliente, periodo, trabajadores_activos, valor_contrato)
        VALUES (
            @c,
            DATEFROMPARTS(YEAR(DATEADD(month, -@m, GETDATE())), MONTH(DATEADD(month, -@m, GETDATE())), 1),
            20 + (@c * 3 % 300),
            1000000 + (@c * 137000 % 40000000)
        );
        SET @m += 1;
    END
    FETCH NEXT FROM cur INTO @c;
END
CLOSE cur; DEALLOCATE cur;
GO

/* --------------------------------------------------------------------
   Insercion de casos para clientes de mayor riesgo,
   concentrados en los últimos 12 meses
   -------------------------------------------------------------------- */
DECLARE @id_caso INT = 1;
DECLARE @c2 INT, @riesgo INT, @n_casos INT, @k INT, @dias_atras INT;
DECLARE cur2 CURSOR FOR SELECT id_cliente, clase_riesgo FROM clientes;
OPEN cur2;
FETCH NEXT FROM cur2 INTO @c2, @riesgo;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @n_casos = @riesgo * 6; 
    SET @k = 0;
    WHILE @k < @n_casos
    BEGIN
        SET @dias_atras = ABS(CHECKSUM(NEWID())) % 365;
        INSERT INTO casos (id_caso, id_cliente, id_trabajador, fecha_ocurrencia, tipo, dias_ausencia, costo, estado)
        VALUES (
            @id_caso,
            @c2,
            NULL,
            DATEADD(day, -@dias_atras, CAST(GETDATE() AS DATE)),
            CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 22 THEN 'grave' ELSE 'leve' END,
            ABS(CHECKSUM(NEWID())) % 30,
            300000 + (ABS(CHECKSUM(NEWID())) % 4000000),
            'cerrado'
        );
        SET @id_caso += 1;
        SET @k += 1;
    END
    FETCH NEXT FROM cur2 INTO @c2, @riesgo;
END
CLOSE cur2; DEALLOCATE cur2;
GO

/* --------------------------------------------------------------------
   Insercion de Prevención: 0 a 4 actividades cliente en el último año
   -------------------------------------------------------------------- */
DECLARE @id_act INT = 1;
DECLARE @c3 INT, @n_act INT, @j INT;
DECLARE cur3 CURSOR FOR SELECT id_cliente FROM clientes;
OPEN cur3;
FETCH NEXT FROM cur3 INTO @c3;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @n_act = ABS(CHECKSUM(NEWID())) % 5;
    SET @j = 0;
    WHILE @j < @n_act
    BEGIN
        INSERT INTO prevencion (id_actividad, id_cliente, fecha, tipo, participantes)
        VALUES (
            @id_act,
            @c3,
            DATEADD(day, -1 * (ABS(CHECKSUM(NEWID())) % 300), CAST(GETDATE() AS DATE)),
            'Capacitación',
            5 + (ABS(CHECKSUM(NEWID())) % 40)
        );
        SET @id_act += 1;
        SET @j += 1;
    END
    FETCH NEXT FROM cur3 INTO @c3;
END
CLOSE cur3; DEALLOCATE cur3;
GO

/* --------------------------------------------------------------------
   Insercion de Trabajadores
   -------------------------------------------------------------------- */

DECLARE @id_trab INT = 1;
DECLARE @c INT, @n_trab INT, @k INT;
DECLARE cur_trab CURSOR FOR SELECT id_cliente FROM clientes;
OPEN cur_trab;
FETCH NEXT FROM cur_trab INTO @c;
WHILE @@FETCH_STATUS = 0
BEGIN
   
    SET @n_trab = 10 + (ABS(CHECKSUM(NEWID())) % 50);
    SET @k = 0;
    WHILE @k < @n_trab
    BEGIN
        INSERT INTO trabajadores (id_trabajador, id_cliente, nombre, fecha_ingreso, estado)
        VALUES (
            @id_trab,
            @c,
            'Trabajador ' + CAST(@id_trab AS VARCHAR),
            DATEADD(day, -1 * (ABS(CHECKSUM(NEWID())) % 1000), CAST(GETDATE() AS DATE)),
            CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 90 THEN 'activo' ELSE 'inactivo' END
        );
        SET @id_trab += 1;
        SET @k += 1;
    END
    FETCH NEXT FROM cur_trab INTO @c;
END
CLOSE cur_trab; DEALLOCATE cur_trab;
GO

-- Select para Verificación
SELECT 'clientes' AS tabla, COUNT(*) AS filas FROM clientes
UNION ALL SELECT 'trabajadores', COUNT(*) FROM trabajadores
UNION ALL SELECT 'casos', COUNT(*) FROM casos
UNION ALL SELECT 'facturacion', COUNT(*) FROM facturacion
UNION ALL SELECT 'prevencion', COUNT(*) FROM prevencion;
