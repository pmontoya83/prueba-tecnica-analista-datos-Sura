# Sección 3 — Python: automatización y validación de calidad del dato

## Qué hace este script
`validar_calidad_facturacion.py` simula lo que correría automáticamente cada vez
que llega un archivo nuevo de facturación, **antes de que entre al pipeline**:
genera un archivo de prueba con errores intencionales, lo valida contra 5 reglas
de calidad, y separa lo que puede entrar al pipeline de lo que debe
rechazarse y revisarse, dejando evidencia de todo en un reporte JSON.

## Ejecución (3 pasos)
1. Instalar dependencias (desde la raíz del repositorio):
   ```bash
   pip install -r requirements.txt
   ```
2. Ubicarse en esta carpeta y ejecutar:
   ```bash
   cd seccion_3
   python3 validar_calidad_facturacion.py
   ```
3. Revisar los resultados en la carpeta `salidas/` que se crea automáticamente.

No requiere ningún archivo de entrada — el archivo de prueba se genera dentro
del propio script (función `generar_archivo_prueba`).

## Archivo de prueba generado
Se generan **1.200 registros base** (más un 5% de duplicados intencionales, para
un total de ~1.260 filas), con estos 4 problemas insertados a propósito:

| Problema | Cómo se simula |
|---|---|
| **IDs con formatos inconsistentes** | El mismo cliente aparece a veces como `"7"`, a veces como `"CLI-7"`, a veces con espacios `" 7 "`, y a veces vacío |
| **Períodos en formatos de fecha distintos** | La misma fecha se escribe en 4 formatos distintos: `AAAA-MM-DD`, `DD/MM/AAAA`, `AAAA/MM/DD`, `DD-MM-AAAA` |
| **Valores negativos o nulos en campos críticos** | `trabajadores_activos` y `valor_contrato` quedan en negativo o en blanco en una parte de las filas |
| **Duplicados por cliente + período** | Se duplica un 5% de las filas tal cual, además de duplicados "naturales" que surgen del azar en la generación |

## Las 5 reglas de calidad (función `validar_calidad`)
Cada registro se evalúa contra las 5 reglas, en este orden — la primera que falla
queda como su "razón de rechazo" (aunque el reporte cuenta cuántas veces falló
cada regla por separado, no solo la primera):

1. **Completitud** — que `id_cliente`, `periodo`, `trabajadores_activos` y
   `valor_contrato` no estén vacíos (después de normalizar el ID y la fecha, para
   no confundir "formato raro" con "campo realmente vacío").
2. **Validez** — que `trabajadores_activos` y `valor_contrato` no sean negativos,
   y que `id_cliente` no esté en blanco.
3. **Unicidad** — que no exista otra fila con el mismo `id_cliente` + `periodo`
   (usando los valores ya normalizados, para detectar duplicados aunque estén
   escritos con formato distinto).
4. **Consistencia** — que si `valor_contrato` es mayor a 0, `trabajadores_activos`
   también lo sea (un cliente no puede tener contrato activo con cero
   trabajadores).
5. **Oportunidad** — que el `periodo` no sea una fecha futura, ni tenga más de 60
   días de atraso respecto a hoy.

## Salidas (carpeta `seccion_3/salidas/`)
- `facturacion_generada.csv` — el archivo de prueba con los defectos, tal como
  "llegaría" en una carga real.
- `facturacion_validos.parquet` — los registros que pasaron las 5 reglas, listos
  para entrar al pipeline.
- `facturacion_rechazados.xlsx` — los registros que fallaron, con una columna
  `razon_rechazo` indicando cuál regla incumplieron primero.
- `reporte_calidad.json` — resumen con el total de registros, válidos,
  rechazados, cuántos fallaron cada regla, el score (0-100) por dimensión de
  calidad, y un score global (promedio de las 5 dimensiones).

## Organización del código
El script está dividido en 5 bloques, cada uno con su propósito:
1. **Generación de datos** — `generar_archivo_prueba()`.
2. **Parsing tolerante** — `normalizar_id_cliente()`, `normalizar_periodo()`
   (extraen el valor real aunque venga en un formato "sucio").
3. **Motor de validación** — `validar_calidad()`, que aplica las 5 reglas.
4. **Reporte** — `construir_reporte_calidad()`, calcula los scores.
5. **Orquestación** — `main()`, que ejecuta todo en orden y exporta los archivos.

Cada función tiene su docstring, y el script maneja errores explícitamente (por
ejemplo, si falta el motor de Parquet, avisa con un mensaje claro en vez de fallar
en silencio).
