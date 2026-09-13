"""Motor de Inversión: grafo determinista de perfilamiento + proyección multi-activo. Sin LLM.

Sigue el mismo patrón que cards.py / budget.py.
Las tasas de rendimiento son representativas de instrumentos Banorte (datos sintéticos documentados).
"""

from schemas import InstrumentoInv, InvestmentPlan, InvestmentState, PerfilRiesgoInv

# ---------------------------------------------------------------------------
# Campos canónicos del estado
# ---------------------------------------------------------------------------

CAMPOS: list[str] = [
    "monto_inversion",
    "aportacion_mensual",
    "plazo_meses",
    "perfil_riesgo",
]

# ---------------------------------------------------------------------------
# Tasas de rendimiento anual por instrumento y perfil (datos sintéticos)
# Fuente supuesto: CETES ~9-10% (2024-2026), fondos mixtos ~8-11%, renta variable ~10-13%
# ---------------------------------------------------------------------------

PORTAFOLIOS: dict[str, list[InstrumentoInv]] = {
    "conservador": [
        {"nombre": "CETES / Pagaré Banorte", "porcentaje": 70.0, "rendimiento_anual": 0.095},
        {"nombre": "Fondos de Inversión Renta Fija", "porcentaje": 25.0, "rendimiento_anual": 0.085},
        {"nombre": "Renta Variable (mínima exposición)", "porcentaje": 5.0, "rendimiento_anual": 0.10},
    ],
    "moderado": [
        {"nombre": "CETES / Pagaré Banorte", "porcentaje": 40.0, "rendimiento_anual": 0.095},
        {"nombre": "Fondos de Inversión Mixtos", "porcentaje": 40.0, "rendimiento_anual": 0.10},
        {"nombre": "Renta Variable / Acciones", "porcentaje": 20.0, "rendimiento_anual": 0.12},
    ],
    "agresivo": [
        {"nombre": "CETES / Pagaré Banorte", "porcentaje": 15.0, "rendimiento_anual": 0.095},
        {"nombre": "Fondos de Inversión Crecimiento", "porcentaje": 35.0, "rendimiento_anual": 0.11},
        {"nombre": "Renta Variable / Acciones", "porcentaje": 50.0, "rendimiento_anual": 0.13},
    ],
}


def _tasa_ponderada(perfil: PerfilRiesgoInv) -> float:
    """Calcula la tasa de rendimiento anual ponderada del portafolio."""
    return sum(i["rendimiento_anual"] * i["porcentaje"] / 100 for i in PORTAFOLIOS[perfil])


# ---------------------------------------------------------------------------
# Grafo de tarjetas
# ---------------------------------------------------------------------------

GRAFO: list[dict] = [
    {
        "id": "monto_inversion",
        "pregunta": "¿Con cuánto capital quieres empezar a invertir?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "monto_inversion",
        "condicion": None,
    },
    {
        "id": "aportacion_mensual",
        "pregunta": "¿Cuánto puedes aportar cada mes a tu inversión? (puede ser $0)",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "aportacion_mensual",
        "condicion": None,
    },
    {
        "id": "plazo_meses",
        "pregunta": "¿En cuánto tiempo quieres ver crecer tu inversión?",
        "tipo_respuesta": "opciones",
        "opciones": [6, 12, 24, 36, 60, 120],
        "campo": "plazo_meses",
        "condicion": None,
    },
    {
        "id": "perfil_riesgo",
        "pregunta": "¿Cuál es tu perfil como inversionista?",
        "tipo_respuesta": "opciones",
        "opciones": ["conservador", "moderado", "agresivo"],
        "campo": "perfil_riesgo",
        "condicion": None,
    },
]

DESCRIPCIONES_PERFIL = {
    "conservador": "Priorizas seguridad. Rendimientos estables con mínimo riesgo.",
    "moderado": "Equilibrio entre seguridad y crecimiento. Riesgo controlado.",
    "agresivo": "Buscas máximo crecimiento. Toleras mayor volatilidad.",
}


# ---------------------------------------------------------------------------
# Validación
# ---------------------------------------------------------------------------

def _numero(valor, minimo: float, maximo: float, entero: bool = False):
    try:
        n = float(str(valor).replace(",", "").replace("$", "").strip())
    except ValueError:
        raise ValueError(f"'{valor}' no es un número válido")
    if not (minimo <= n <= maximo):
        raise ValueError(f"{n:,.2f} fuera de rango [{minimo:,.0f}, {maximo:,.0f}]")
    if entero:
        if n != int(n):
            raise ValueError(f"{n:g} debe ser entero")
        return int(n)
    return n


def validar(campo: str, valor) -> float | int | str:
    if campo == "monto_inversion":
        return _numero(valor, 500, 100_000_000)  # mínimo $500 para que sea significativo
    if campo == "aportacion_mensual":
        return _numero(valor, 0, 10_000_000)
    if campo == "plazo_meses":
        return _numero(valor, 3, 360, entero=True)
    if campo == "perfil_riesgo":
        texto = str(valor).strip().lower()
        if texto not in PORTAFOLIOS:
            raise ValueError(f"perfil '{valor}' no existe; elige: conservador, moderado o agresivo")
        return texto
    raise ValueError(f"campo '{campo}' no existe en el módulo de inversión")


# ---------------------------------------------------------------------------
# Grafo helpers
# ---------------------------------------------------------------------------

def aplicar_respuesta(estado: InvestmentState, campo: str, valor) -> InvestmentState:
    nuevo = {c: estado.get(c) for c in CAMPOS}
    nuevo[campo] = validar(campo, valor)
    return nuevo


def get_next_question(estado: InvestmentState) -> dict | None:
    for i, nodo in enumerate(GRAFO):
        if estado.get(nodo["campo"]) is None:
            return {**nodo, "paso": i + 1, "total": len(GRAFO)}
    return None


def estado_completo(estado: InvestmentState) -> bool:
    return all(estado.get(c) is not None for c in CAMPOS)


# ---------------------------------------------------------------------------
# Proyección multi-activo (función pura)
# ---------------------------------------------------------------------------

def _serie_mensual(monto_inicial: float, aportacion: float, tasa_anual: float, meses: int) -> list[float]:
    """Interés compuesto mensual con aportaciones periódicas."""
    r = tasa_anual / 12
    saldo = monto_inicial
    serie = [round(saldo, 2)]
    for _ in range(meses):
        saldo = saldo * (1 + r) + aportacion
        serie.append(round(saldo, 2))
    return serie


def simulate_investment(estado: InvestmentState) -> InvestmentPlan:
    """Calcula la proyección de inversión con el portafolio ponderado del perfil elegido."""
    if not estado_completo(estado):
        raise ValueError("el perfilamiento de inversión no está completo")

    monto = float(estado["monto_inversion"])
    aportacion = float(estado["aportacion_mensual"])
    meses = int(estado["plazo_meses"])
    perfil: PerfilRiesgoInv = estado["perfil_riesgo"]

    tasa = _tasa_ponderada(perfil)
    serie = _serie_mensual(monto, aportacion, tasa, meses)

    monto_final = serie[-1]
    capital_aportado = monto + aportacion * meses
    ganancia = round(monto_final - capital_aportado, 2)
    rendimiento_pct = round((ganancia / capital_aportado * 100) if capital_aportado > 0 else 0, 2)

    return {
        "monto_inversion": monto,
        "aportacion_mensual": aportacion,
        "plazo_meses": meses,
        "perfil_riesgo": perfil,
        "instrumentos": PORTAFOLIOS[perfil],
        "serie_mensual": serie,
        "rendimiento_estimado_total": ganancia,
        "rendimiento_porcentual": rendimiento_pct,
        "monto_final_proyectado": round(monto_final, 2),
        "capital_aportado_total": round(capital_aportado, 2),
    }
