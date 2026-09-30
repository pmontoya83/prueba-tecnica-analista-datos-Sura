"""
Tablero Ligero de Monitoreo Operativo de Casos
Modulo: seccion_4/app.py
Ejecución: streamlit run Secciones 3,4\seccion_4/app.py
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.express as px
import plotly.graph_objects as go
from datetime import datetime, timedelta

st.set_page_config(page_title="Dashboard de Monitoreo Operativo Sura", layout="wide")

@st.cache_data
def generar_datos_simulados():
    np.random.seed(42)
    n = 800
    clientes = [f"Cliente_{i:02d}" for i in range(1, 25)]
    fechas = pd.date_range(end=datetime.now(), periods=365, freq='D')
    
    df_casos = pd.DataFrame({
        'id_caso': [f"CAS-{i:05d}" for i in range(1, n + 1)],
        'id_cliente': np.random.choice(clientes, n),
        'fecha_ocurrencia': np.random.choice(fechas, n),
        'tipo': np.random.choice(['leve', 'grave'], n, p=[0.7, 0.3]),
        'clase_riesgo': np.random.choice([1, 2, 3, 4, 5], n, p=[0.1, 0.2, 0.4, 0.2, 0.1]),
        'costo': np.random.exponential(scale=1500, size=n).round(2),
        'trabajadores_asociados': np.random.randint(50, 500, n)
    })
    return df_casos

df_casos = generar_datos_simulados()

# Encabezado
st.title("🛡️ Dashboard de Monitoreo Operativo Sura")
st.markdown("Monitoreo Operativo - Generación de Datos.")

# Sidebar - Filtros
st.sidebar.header("Filtros de Control")
clases_seleccionadas = st.sidebar.multiselect(
    "Seleccionar Clase de Riesgo:",
    options=[1, 2, 3, 4, 5],
    default=[1, 2, 3, 4, 5]
)

tipo_seleccionado = st.sidebar.multiselect(
    "Tipo de Caso:",
    options=['leve', 'grave'],
    default=['leve', 'grave']
)

# Filtrado dinámico
df_filtrado = df_casos[
    (df_casos['clase_riesgo'].isin(clases_seleccionadas)) &
    (df_casos['tipo'].isin(tipo_seleccionado))
].copy()

# Cálculo de KPIs (Mes Actual vs Mes Anterior)
df_filtrado['mes_año'] = df_filtrado['fecha_ocurrencia'].dt.to_period('M')
meses_disponibles = sorted(df_filtrado['mes_año'].unique())

mes_actual = meses_disponibles[-1]
mes_anterior = meses_disponibles[-2]

df_m_act = df_filtrado[df_filtrado['mes_año'] == mes_actual]
df_m_ant = df_filtrado[df_filtrado['mes_año'] == mes_anterior]

casos_act = len(df_m_act)
casos_ant = len(df_m_ant)
var_casos = ((casos_act - casos_ant) / casos_ant * 100) if casos_ant > 0 else 0

costo_act = df_m_act['costo'].sum()
costo_ant = df_m_ant['costo'].sum()
var_costo = ((costo_act - costo_ant) / costo_ant * 100) if costo_ant > 0 else 0

tasa_act = (casos_act / df_m_act['trabajadores_asociados'].sum() * 100) if len(df_m_act) > 0 else 0
tasa_ant = (casos_ant / df_m_ant['trabajadores_asociados'].sum() * 100) if len(df_m_ant) > 0 else 0
var_tasa = tasa_act - tasa_ant

# Fila 1: KPIs
kpi1, kpi2, kpi3 = st.columns(3)
kpi1.metric("Casos del Mes Actual", f"{casos_act}", f"{var_casos:.1f}% vs mes ant.")
kpi2.metric("Costo Total del Mes", f"${costo_act:,.0f}", f"{var_costo:.1f}% vs mes ant.")
kpi3.metric("Tasa de Incidencia", f"{tasa_act:.2f}%", f"{var_tasa:+.2f}% p.p. vs mes ant.")

st.markdown("---")

# Fila 2: Tendencia y Distribuciones
col_left, col_right = st.columns([2, 1])

with col_left:
    st.subheader("Tendencia Mensual de Incidentes (Últimos 12 Meses)")
    df_tendencia = df_filtrado.groupby('mes_año').size().reset_index(name='total_casos')
    df_tendencia['mes_str'] = df_tendencia['mes_año'].astype(str)
    promedio_historico = df_tendencia['total_casos'].mean()
    
    fig_line = px.line(df_tendencia, x='mes_str', y='total_casos', markers=True, title="Casos Mensuales vs Promedio")
    fig_line.add_hline(y=promedio_historico, line_dash="dash", line_color="red", annotation_text=f"Promedio: {promedio_historico:.1f}")
    st.plotly_chart(fig_line, use_container_width=True)

with col_right:
    st.subheader("Distribución por Gravedad")
    fig_pie = px.pie(df_filtrado, names='tipo', hole=0.4, color='tipo',
                     color_discrete_map={'leve': '#2b5c8f', 'grave': '#d9534f'})
    st.plotly_chart(fig_pie, use_container_width=True)

st.markdown("---")

# Fila 3: Top Clientes y Distribución de Riesgo
col_t1, col_t2 = st.columns([3, 2])

with col_t1:
    st.subheader("Top 10 Clientes con Mayor Número de Casos")
    df_top = df_filtrado.groupby(['id_cliente', 'clase_riesgo']).agg(
        total_casos=('id_caso', 'count'),
        costo_total=('costo', 'sum')
    ).reset_index().sort_values('total_casos', ascending=False).head(10)
    
    st.dataframe(df_top.style.format({'costo_total': '${:,.2f}'}), use_container_width=True)

with col_t2:
    st.subheader("Casos por Clase de Riesgo")
    fig_bar = px.bar(df_filtrado.groupby('clase_riesgo').size().reset_index(name='casos'), 
                     x='clase_riesgo', y='casos', color='clase_riesgo', labels={'clase_riesgo': 'Riesgo (1-5)'})
    st.plotly_chart(fig_bar, use_container_width=True)