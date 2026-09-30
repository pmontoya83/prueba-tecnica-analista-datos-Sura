# Prueba técnica — Analista de Datos y Analítica

Este repositorio de entrega de la prueba técnica del cargo de Analista de Datos y
Analítica, las respuestas estan escritas en las Secciones 1, 2, 5, 6 están en el archivo `respuestas_secciones_1_2_5_6.docx`  en la raíz de esa carpeta de este repositorio.
Tambien se encuentra las Secciones 3, 4 donde tambien se encuentra la explicacion en los archivos README

## Estructura del repositorio

```
├── README.md                              <- este archivo
├── requirements.txt                       <- dependencias de Python (Sección 3)
├── respuestas_secciones_1_2_5_6.docx      <- respuestas escritas (Secciones 1, 2, 5, 6)
├──Secciones 1,2,5,6/
├── seccion2_evidencias/
│   ├──01_tablas empresa de servicios.sql             <- crea el esquema y datos de ejemplo (T-SQL)
│   ├── 02_query_2_1_corregida.sql         <- Pregunta 2.1: versión corregida
│   ├── query_2_2_priorizacion.sql         <- Pregunta 2.2: top 15 clientes prioritarios
│   └── query_2_3_pipeline_diario.sql      <- Pregunta 2.3: pipeline diario del tablero
│   └── Prueba_Tecnica_Sura_FULL.bak       <- Base de datos de las pruebas
├── Secciones3,4
├── seccion_3/
│   ├── validar_calidad_facturacion.py     <- Ejercicio 3.1: validación de calidad
│   └── salidas/                           <- se genera al ejecutar el script
│   └── README.md                          <- detalle de la sección 3 
├── Secciones3,4
├── seccion_4/
│   ├── App.py                             <- Ejercicio 4.1: Tablero Ligero Operativo (Streamlit)
│   └── README.md                          <- detalle de la sección 4
└── evidencia/
    └── IMAGENES, QUERYS, PBIX             <- capturas de SQL Server y Power BI
```

## Sección 2 — SQL
Consultas en T-SQL real, listas para correr en SQL Server Management Studio (SSMS):

1. `01_tablas empresa de servicios.sql` — crea las 5 tablas del enunciado y las llena con
   datos de ejemplo (40 clientes, ~8 meses de facturación, casos e historial
   de prevención). Correr primero.
2. `02_query_2_1_corregida.sql` — versión corregida (sin el bug de fan-out) de
   la consulta de la Pregunta 2.1.
3. `query_2_2_priorizacion.sql` — Pregunta 2.2: top 15 clientes prioritarios.
4. `query_2_3_pipeline_diario.sql` — Pregunta 2.3: pipeline diario del tablero.

Pasos en SSMS:
```sql
CREATE DATABASE Prueba_Tecnica_Sura;
USE Prueba_Tecnica_Sura;
-- pegar y ejecutar 01_tablas empresa de servicios.sql completo
-- luego ejecutar cada consulta por separado y capturar el resultado
```
Evidencia sugerida (capturas de pantalla, ver carpeta `evidencia/`): el conteo de
filas por tabla al final del script, y el resultado (grid) de cada una
de las 3 consultas siguientes.

## Sección 3 — Python

Instalación y ejecución (menos de 5 minutos):

```
python3 -m venv venv
source venv/bin/activate        # En Windows: venv\Scripts\activate
pip install -r requirements.txt
cd seccion_3
python3 validar_calidad_facturacion.py
```

Esto genera, dentro de `seccion_3/salidas/`:
- `facturacion_generada.csv` — archivo de prueba con 1.000+ registros y errores intencionales
- `facturacion_validos.parquet` — registros que pasaron todas las reglas de calidad
- `facturacion_rechazados.xlsx` — registros rechazados con su razón de rechazo
- `reporte_calidad.json` — score de calidad por dimensión (completitud, validez,
  unicidad, consistencia, oportunidad) y score global

## Sección 4 — Tablero ligero en HTML u otra herramienta sin licencia

Ver `seccion_4/README.md` para instrucciones detalladas y
la explicación de cómo se conectaría a datos reales de un Lakehouse en producción.
Resumen: abrir `Secciones 3,4` `seccion_4/App.py`.
