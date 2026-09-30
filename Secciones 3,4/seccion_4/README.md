# Sección 4 — Tablero ligero en HTML u otra herramienta sin licencia

## Herramienta elegida y por qué
**Streamlit + Plotly.** Se eligió porque permite construir un tablero interactivo
completo (filtros, KPIs, gráficos) con muy poco código en Python, sin licencia y
sin necesidad de un servidor propio — solo se necesita el intérprete de Python que
ya se usa en la Sección 3. Streamlit además refresca automáticamente todos los
visuales cuando alguien cambia un filtro, cumpliendo el criterio un coordinador
podría usarlo sin que nadie se lo explique.

## Ejecución
1. Instalar las dependencias (una sola vez):
   ```bash
   pip install -r requirements.txt
   ```
2. Ubicarse en la carpeta y ejecutar:
   ```bash
   streamlit run app.py
   ```
3. Se abre automáticamente en el navegador en `http://localhost:8501`. Usa los
   filtros de "Clase de Riesgo" y "Tipo de Caso" en la barra lateral izquierda —
   todos los visuales se actualizan al instante.

No requiere archivos de datos externos: los casos de prueba se generan dentro del
propio `app.py` al iniciar la aplicación.

## Contenido del tablero
- 3 KPIs con variación vs. mes anterior: casos del mes, costo total, tasa de
  incidencia.
- Tendencia mensual de los últimos 12 meses con línea de promedio histórico.
- Distribución de casos por gravedad (leve/grave).
- Top 10 clientes con más casos, con su costo total y clase de riesgo.
- Distribución de casos por clase de riesgo (1-5).
- Filtros por clase de riesgo y tipo de caso, que afectan todos los visuales a la vez.

## ¿Cómo conectaría este tablero a datos reales de un Lakehouse en producción?
Reemplazaría la función `generar_datos_simulados()` por una función que consulte
el Lakehouse directamente — por ejemplo, usando un conector como `pyodbc` o el SDK
de Fabric/Synapse para ejecutar una consulta SQL contra las tablas Delta (o, mejor
aún, contra el modelo semántico de Power BI certificado, vía API REST o el
conector XMLA, para no duplicar la lógica de negocio ya definida ahí). Envolvería
esa función también en `@st.cache_data` con un tiempo de expiración corto (por
ejemplo `ttl=600` para refrescar cada 10 minutos), de forma que el tablero no
golpee el Lakehouse en cada clic de un usuario, sino que traiga datos frescos cada
cierto intervalo. El resto del código (`filtrar_datos`, `calcular_kpis`, las
funciones `render_*`) no cambiaría en absoluto, porque ya están desacopladas de
cómo se obtienen los datos — solo esperan un DataFrame de pandas con las mismas
columnas.

