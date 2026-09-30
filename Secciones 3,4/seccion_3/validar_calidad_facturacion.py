"""
Validación de calidad del dato — archivo de facturación
=========================================================

Simula lo que correría automáticamente con cada carga nueva del archivo
de facturación antes de que entre al pipeline.

Pasos:
    1. Genera un archivo de prueba con 1.000+ registros con problemas
       intencionales (IDs inconsistentes, fechas en formatos distintos,
       nulos/negativos, duplicados).
    2. Valida cada registro contra 5 dimensiones de calidad:
       completitud, validez, unicidad, consistencia y oportunidad.
    3. Genera un reporte de calidad en JSON (score por dimensión).
    4. Exporta los registros válidos a Parquet y los rechazados a Excel
       (con la razón de rechazo).

Ejecución:
    python validar_calidad_facturacion.py

Salidas (carpeta ./salidas/):
    facturacion_generada.csv   -> archivo de prueba generado
    facturacion_validos.parquet
    facturacion_rechazados.xlsx
    reporte_calidad.json
"""

from __future__ import annotations

import json
import random
import logging
from dataclasses import dataclass, field
from datetime import date, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("validacion_facturacion")

CARPETA_SALIDA = Path(__file__).parent / "salidas"
CARPETA_SALIDA.mkdir(exist_ok=True)

N_REGISTROS = 1200
N_CLIENTES = 600
SEMILLA = 42


# =====================================================================
# 1. Generación del archivo de prueba con problemas intencionales
# =====================================================================

def generar_archivo_prueba(n_registros: int = N_REGISTROS) -> pd.DataFrame:
    """Genera un DataFrame de facturación con defectos intencionales
    para poder probar cada regla de calidad."""
    random.seed(SEMILLA)
    np.random.seed(SEMILLA)

    registros = []
    hoy = date.today()
    # Períodos "normales": mes actual y mes anterior (dentro de la ventana
    # de oportunidad de 60 días) — los períodos fuera de rango se inyectan
    # a propósito más abajo, no como parte de la base.
    mes_actual = hoy.replace(day=1)
    mes_anterior = (mes_actual - timedelta(days=1)).replace(day=1)
    periodos_base = [mes_actual, mes_anterior]
    formatos_fecha = ["%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y"]

    for i in range(n_registros):
        id_cliente_num = random.randint(1, N_CLIENTES)

        # --- Problema: formatos de ID inconsistentes ---
        estilo_id = random.choice(["num", "prefijo", "texto_extra", "vacio"])
        if estilo_id == "num":
            id_cliente = str(id_cliente_num)
        elif estilo_id == "prefijo":
            id_cliente = f"CLI-{id_cliente_num}"
        elif estilo_id == "texto_extra":
            id_cliente = f" {id_cliente_num} "  # espacios en blanco
        else:
            id_cliente = ""  # nulo/ID faltante

        periodo_base = random.choice(periodos_base)
        # --- Problema: periodo en formatos de fecha distintos (como texto) ---
        formato = random.choice(formatos_fecha)
        periodo_str = periodo_base.strftime(formato)

        # --- Problema: valores negativos o nulos en campos críticos ---
        trabajadores_activos = random.randint(5, 500)
        valor_contrato = round(random.uniform(1_000_000, 50_000_000), 0)

        if random.random() < 0.05:
            trabajadores_activos = -abs(trabajadores_activos)  # negativo
        if random.random() < 0.05:
            valor_contrato = None  # nulo
        if random.random() < 0.03:
            trabajadores_activos = None

        # --- Problema: oportunidad (periodo futuro o muy atrasado) ---
        if random.random() < 0.03:
            periodo_str = (date.today() + timedelta(days=random.randint(10, 90))).strftime(formato)
        elif random.random() < 0.03:
            periodo_str = (date.today() - timedelta(days=random.randint(70, 400))).strftime(formato)

        # --- Problema de consistencia intencional ---
        if random.random() < 0.04:
            trabajadores_activos = 0
            valor_contrato = abs(valor_contrato) if valor_contrato else 5_000_000

        registros.append(
            {
                "id_cliente": id_cliente,
                "periodo": periodo_str,
                "trabajadores_activos": trabajadores_activos,
                "valor_contrato": valor_contrato,
            }
        )

    df = pd.DataFrame(registros)

    # --- Problema: duplicados exactos por cliente + período ---
    duplicados = df.sample(frac=0.05, random_state=SEMILLA)
    df = pd.concat([df, duplicados], ignore_index=True)

    df = df.sample(frac=1, random_state=SEMILLA).reset_index(drop=True)  # mezclar filas
    return df


# =====================================================================
# 2. Parsing tolerante de campos "sucios"
# =====================================================================

def normalizar_id_cliente(valor) -> str | None:
    """Extrae el número de cliente de cualquier formato de ID recibido."""
    if valor is None:
        return None
    texto = str(valor).strip()
    if texto == "" or texto.lower() == "nan":
        return None
    digitos = "".join(ch for ch in texto if ch.isdigit())
    return digitos if digitos else None


def normalizar_periodo(valor):
    """Intenta parsear el período probando varios formatos de fecha
    conocidos; devuelve NaT si ninguno funciona."""
    if valor is None or str(valor).strip() == "":
        return pd.NaT
    for formato in ("%Y-%m-%d", "%d/%m/%Y", "%Y/%m/%d", "%d-%m-%Y"):
        try:
            return pd.to_datetime(valor, format=formato)
        except (ValueError, TypeError):
            continue
    # último intento: dejar que pandas infiera
    try:
        return pd.to_datetime(valor, errors="raise")
    except Exception:
        return pd.NaT


# =====================================================================
# 3. Motor de validación por reglas
# =====================================================================

@dataclass
class ResultadoValidacion:
    df_validos: pd.DataFrame
    df_rechazados: pd.DataFrame
    conteos_por_regla: dict = field(default_factory=dict)
    total_registros: int = 0


def validar_calidad(df_crudo: pd.DataFrame) -> ResultadoValidacion:
    """Aplica las 5 reglas de calidad y separa válidos de rechazados.

    Un registro puede fallar más de una regla; se reporta la primera
    razón de rechazo encontrada (orden: completitud, validez, unicidad,
    consistencia, oportunidad), pero el conteo por regla contempla todas
    las veces que cada regla individual falló, para el score.
    """
    df = df_crudo.copy()
    total = len(df)

    df["id_cliente_norm"] = df["id_cliente"].apply(normalizar_id_cliente)
    df["periodo_norm"] = df["periodo"].apply(normalizar_periodo)

    hoy = pd.Timestamp(date.today())
    limite_atraso = hoy - pd.Timedelta(days=60)

    # --- Regla 1: Completitud (campos obligatorios sin nulos) ---
    falla_completitud = (
        df["id_cliente_norm"].isna()
        | df["periodo_norm"].isna()
        | df["trabajadores_activos"].isna()
        | df["valor_contrato"].isna()
    )

    # --- Regla 2: Validez (rangos y formatos esperados) ---
    trabajadores_num = pd.to_numeric(df["trabajadores_activos"], errors="coerce")
    valor_num = pd.to_numeric(df["valor_contrato"], errors="coerce")
    falla_validez = (
        (trabajadores_num < 0)
        | (valor_num < 0)
        | df["id_cliente"].astype(str).str.strip().eq("")
    )
    falla_validez = falla_validez.fillna(False)

    # --- Regla 3: Unicidad (sin duplicados por id_cliente + periodo) ---
    clave = df["id_cliente_norm"].astype(str) + "_" + df["periodo_norm"].astype(str)
    falla_unicidad = clave.duplicated(keep="first")

    # --- Regla 4: Consistencia (trabajadores_activos > 0 si valor_contrato > 0) ---
    falla_consistencia = (valor_num.fillna(0) > 0) & (trabajadores_num.fillna(0) <= 0)

    # --- Regla 5: Oportunidad (periodo no futuro ni > 60 días de atraso) ---
    falla_oportunidad = (
        df["periodo_norm"].notna()
        & ((df["periodo_norm"] > hoy) | (df["periodo_norm"] < limite_atraso))
    )

    conteos_por_regla = {
        "completitud": int(falla_completitud.sum()),
        "validez": int(falla_validez.sum()),
        "unicidad": int(falla_unicidad.sum()),
        "consistencia": int(falla_consistencia.sum()),
        "oportunidad": int(falla_oportunidad.sum()),
    }

    razon = pd.Series([""] * total, index=df.index)
    orden_reglas = [
        (falla_completitud, "completitud"),
        (falla_validez, "validez"),
        (falla_unicidad, "unicidad"),
        (falla_consistencia, "consistencia"),
        (falla_oportunidad, "oportunidad"),
    ]
    for mascara, nombre in orden_reglas:
        razon = razon.mask(mascara & (razon == ""), nombre)

    df["razon_rechazo"] = razon
    rechazados = df[df["razon_rechazo"] != ""].copy()
    validos = df[df["razon_rechazo"] == ""].copy()

    log.info("Registros totales: %d | Válidos: %d | Rechazados: %d",
              total, len(validos), len(rechazados))

    return ResultadoValidacion(
        df_validos=validos,
        df_rechazados=rechazados,
        conteos_por_regla=conteos_por_regla,
        total_registros=total,
    )


# =====================================================================
# 4. Reporte de calidad
# =====================================================================

def construir_reporte_calidad(resultado: ResultadoValidacion) -> dict:
    total = resultado.total_registros
    score_por_dimension = {
        regla: round(100 * (1 - fallas / total), 2) if total else 0.0
        for regla, fallas in resultado.conteos_por_regla.items()
    }
    score_global = round(sum(score_por_dimension.values()) / len(score_por_dimension), 2)

    return {
        "total_registros": total,
        "registros_validos": len(resultado.df_validos),
        "registros_rechazados": len(resultado.df_rechazados),
        "rechazados_por_regla": resultado.conteos_por_regla,
        "score_por_dimension": score_por_dimension,
        "score_global": score_global,
    }


# =====================================================================
# 5. Orquestación principal
# =====================================================================

def main() -> None:
    log.info("Generando archivo de prueba con %d registros...", N_REGISTROS)
    df_crudo = generar_archivo_prueba()
    ruta_crudo = CARPETA_SALIDA / "facturacion_generada.csv"
    df_crudo.to_csv(ruta_crudo, index=False)
    log.info("Archivo de prueba guardado en %s", ruta_crudo)

    log.info("Validando calidad del dato...")
    resultado = validar_calidad(df_crudo)

    reporte = construir_reporte_calidad(resultado)
    ruta_reporte = CARPETA_SALIDA / "reporte_calidad.json"
    with open(ruta_reporte, "w", encoding="utf-8") as f:
        json.dump(reporte, f, ensure_ascii=False, indent=2)
    log.info("Reporte de calidad guardado en %s", ruta_reporte)
    log.info("Score global de calidad: %.2f / 100", reporte["score_global"])

    columnas_finales = ["id_cliente", "periodo", "trabajadores_activos", "valor_contrato"]

    ruta_parquet = CARPETA_SALIDA / "facturacion_validos.parquet"
    try:
        resultado.df_validos[columnas_finales].to_parquet(ruta_parquet, index=False)
        log.info("Registros válidos exportados a %s (%d filas)",
                  ruta_parquet, len(resultado.df_validos))
    except ImportError:
        log.error(
            "Falta un engine de Parquet (pyarrow). Instale con: "
            "pip install pyarrow"
        )
        raise

    ruta_excel = CARPETA_SALIDA / "facturacion_rechazados.xlsx"
    columnas_rechazo = columnas_finales + ["razon_rechazo"]
    resultado.df_rechazados[columnas_rechazo].to_excel(ruta_excel, index=False)
    log.info("Registros rechazados exportados a %s (%d filas)",
              ruta_excel, len(resultado.df_rechazados))

    log.info("Proceso completado sin errores.")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        log.exception("El proceso de validación falló.")
        raise
