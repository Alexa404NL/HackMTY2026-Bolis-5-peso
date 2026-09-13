"""Motor de Presupuesto: grafo determinista de perfilamiento + cálculos. Sin LLM.

Sigue el mismo patrón que cards.py: el grafo vive como datos (lista de dicts),
la lógica es funciones puras testables sin servidor.
"""

from schemas import BudgetPlan, BudgetState, CategoriaBudget

# ---------------------------------------------------------------------------
# Campos canónicos del estado (orden importa: lo usa _db y los tools MCP)
# ---------------------------------------------------------------------------

CAMPOS: list[str] = [
    "ingreso_mensual",
    "gastos_fijos",
    "cat_vivienda",
    "cat_alimentacion",
    "cat_transporte",
    "cat_entretenimiento",
    "cat_salud",
    "cat_otros",
]

# ---------------------------------------------------------------------------
# Grafo de tarjetas (determinista, sin LLM)
# ---------------------------------------------------------------------------
# condicion: None → siempre visible
#            dict  → {"campo": ..., "min": ...} visible solo si campo >= min

GRAFO: list[dict] = [
    {
        "id": "ingreso_mensual",
        "pregunta": "¿Cuánto es tu ingreso mensual neto (después de impuestos)?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "ingreso_mensual",
        "condicion": None,
    },
    {
        "id": "gastos_fijos",
        "pregunta": "¿Cuánto pagas al mes en gastos fijos? (renta, servicios, créditos…)",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "gastos_fijos",
        "condicion": None,
    },
    {
        "id": "cat_vivienda",
        "pregunta": "Gastos de vivienda variable este mes (mantenimiento, reparaciones…)",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_vivienda",
        "condicion": None,
    },
    {
        "id": "cat_alimentacion",
        "pregunta": "¿Cuánto gastas en alimentos y despensa al mes?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_alimentacion",
        "condicion": None,
    },
    {
        "id": "cat_transporte",
        "pregunta": "¿Cuánto gastas en transporte al mes? (gasolina, Uber, metro…)",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_transporte",
        "condicion": None,
    },
    {
        "id": "cat_entretenimiento",
        "pregunta": "¿Cuánto destinas a entretenimiento y salidas al mes?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_entretenimiento",
        "condicion": None,
    },
    {
        "id": "cat_salud",
        "pregunta": "¿Cuánto gastas en salud al mes? (medicamentos, consultas, gym…)",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_salud",
        "condicion": None,
    },
    {
        "id": "cat_otros",
        "pregunta": "Otros gastos variables que no cayeron en las categorías anteriores",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "cat_otros",
        "condicion": None,
    },
]

# Nombres amigables de las categorías variables para presentar al usuario
NOMBRES_CATEGORIA: dict[str, str] = {
    "cat_vivienda": "Vivienda",
    "cat_alimentacion": "Alimentación",
    "cat_transporte": "Transporte",
    "cat_entretenimiento": "Entretenimiento",
    "cat_salud": "Salud",
    "cat_otros": "Otros",
}

CATEGORIAS_VARIABLES = list(NOMBRES_CATEGORIA.keys())


# ---------------------------------------------------------------------------
# Validación
# ---------------------------------------------------------------------------

def _numero(valor, minimo: float, maximo: float) -> float:
    try:
        n = float(str(valor).replace(",", "").replace("$", "").strip())
    except ValueError:
        raise ValueError(f"'{valor}' no es un número válido")
    if not (minimo <= n <= maximo):
        raise ValueError(f"{n:,.2f} está fuera del rango [{minimo:,.0f}, {maximo:,.0f}]")
    return n


def validar(campo: str, valor) -> float:
    """Regresa el valor normalizado o lanza ValueError."""
    if campo not in CAMPOS:
        raise ValueError(f"campo '{campo}' no existe en el módulo de presupuesto")
    return _numero(valor, 0, 100_000_000)


# ---------------------------------------------------------------------------
# Grafo helpers
# ---------------------------------------------------------------------------

def aplicar_respuesta(estado: BudgetState, campo: str, valor) -> BudgetState:
    nuevo = {c: estado.get(c) for c in CAMPOS}
    nuevo[campo] = validar(campo, valor)
    return nuevo


def get_next_question(estado: BudgetState) -> dict | None:
    """Devuelve el siguiente nodo del grafo pendiente o None si está completo."""
    visibles = GRAFO  # sin condiciones en este módulo — todas las preguntas se muestran
    for i, nodo in enumerate(visibles):
        if estado.get(nodo["campo"]) is None:
            return {**nodo, "paso": i + 1, "total": len(visibles)}
    return None


def estado_completo(estado: BudgetState) -> bool:
    return all(estado.get(n["campo"]) is not None for n in GRAFO)


# ---------------------------------------------------------------------------
# Cálculo del plan de presupuesto (función pura)
# ---------------------------------------------------------------------------

def simulate_budget(estado: BudgetState) -> BudgetPlan:
    """Calcula el plan de presupuesto a partir del estado completo.

    No lanza si el estado está incompleto: usa 0 como fallback para
    categorías no llenadas, pero sí valida ingreso_mensual.
    """
    if estado.get("ingreso_mensual") is None:
        raise ValueError("se requiere ingreso_mensual para calcular el presupuesto")

    ingreso = float(estado["ingreso_mensual"])
    fijos = float(estado.get("gastos_fijos") or 0)

    categorias: list[CategoriaBudget] = []
    total_variable = 0.0
    for campo in CATEGORIAS_VARIABLES:
        monto = float(estado.get(campo) or 0)
        total_variable += monto
        categorias.append(
            {
                "nombre": NOMBRES_CATEGORIA[campo],
                "monto": round(monto, 2),
                "porcentaje": round((monto / ingreso * 100) if ingreso > 0 else 0, 1),
            }
        )

    total_gastos = round(fijos + total_variable, 2)
    balance = round(ingreso - total_gastos, 2)

    # Margen de ahorro sugerido: idealmente 20% del ingreso (regla 50/30/20)
    meta_ahorro = round(ingreso * 0.20, 2)
    margen_real = round(max(balance, 0), 2)
    margen_sugerido = min(meta_ahorro, margen_real)

    # Semáforo de salud financiera
    ratio_gasto = total_gastos / ingreso if ingreso > 0 else 1.0
    if ratio_gasto <= 0.80:
        color = "green"
    elif ratio_gasto <= 1.00:
        color = "yellow"
    else:
        color = "red"

    return {
        "ingreso_mensual": ingreso,
        "gastos_fijos": fijos,
        "categorias": categorias,
        "total_gastos": total_gastos,
        "balance_disponible": balance,
        "margen_ahorro_sugerido": margen_sugerido,
        "status_color": color,
    }
