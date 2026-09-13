"""Esquemas de datos compartidos: Dashboard, Presupuesto e Inversión.

Todos los módulos del servidor importan de aquí sus TypedDicts y constantes
de esquema para garantizar consistencia entre el motor de tarjetas, los tools
MCP y la capa A2UI.
"""

from typing import Literal, TypedDict

# ---------------------------------------------------------------------------
# Tipos compartidos
# ---------------------------------------------------------------------------

ModuleType = Literal["savings_goal", "budget", "investment"]
DisplayMode = Literal["compact_summary", "chart_preview", "progress_tracker"]
StatusColor = Literal["green", "yellow", "red"]


class WidgetSummary(TypedDict):
    primary_metric: str        # ej. "Balance: $4,500" o "Rendimiento: +12%"
    secondary_metric: str      # ej. "Sep 2026" o "CETES 40%"
    status_color: StatusColor


class WidgetInstance(TypedDict):
    id: str                    # uuid generado en cliente o servidor
    module_type: ModuleType
    title: str
    order: int                 # posición en el grid del Dashboard (0-indexed)
    display_mode: DisplayMode
    module_data_id: int | None # FK a la tabla del módulo (goal_id, budget_id, etc.)
    summary: WidgetSummary


class DashboardState(TypedDict):
    user_id: str               # por ahora siempre "default" (sin autenticación)
    widgets: list[WidgetInstance]


# ---------------------------------------------------------------------------
# Esquema del módulo de Presupuesto
# ---------------------------------------------------------------------------

class CategoriaBudget(TypedDict):
    nombre: str
    monto: float
    porcentaje: float          # 0–100, calculado automáticamente


class BudgetState(TypedDict):
    ingreso_mensual: float | None
    gastos_fijos: float | None
    # Categorías de gasto variable (se construyen durante el perfilamiento)
    cat_vivienda: float | None
    cat_alimentacion: float | None
    cat_transporte: float | None
    cat_entretenimiento: float | None
    cat_salud: float | None
    cat_otros: float | None


class BudgetPlan(TypedDict):
    """Resultado calculado a partir de BudgetState."""
    ingreso_mensual: float
    gastos_fijos: float
    categorias: list[CategoriaBudget]
    total_gastos: float
    balance_disponible: float
    margen_ahorro_sugerido: float   # 20% del ingreso si es viable, else 0
    status_color: StatusColor       # green = balance positivo, yellow = ajustado, red = déficit


# ---------------------------------------------------------------------------
# Esquema del módulo de Inversión
# ---------------------------------------------------------------------------

PerfilRiesgoInv = Literal["conservador", "moderado", "agresivo"]


class InstrumentoInv(TypedDict):
    nombre: str
    porcentaje: float          # proporción en el portafolio (0–100)
    rendimiento_anual: float   # tasa decimal, ej. 0.11


class InvestmentState(TypedDict):
    monto_inversion: float | None
    aportacion_mensual: float | None
    plazo_meses: int | None
    perfil_riesgo: PerfilRiesgoInv | None


class InvestmentPlan(TypedDict):
    """Resultado calculado a partir de InvestmentState."""
    monto_inversion: float
    aportacion_mensual: float
    plazo_meses: int
    perfil_riesgo: PerfilRiesgoInv
    instrumentos: list[InstrumentoInv]
    serie_mensual: list[float]          # valor del portafolio mes a mes
    rendimiento_estimado_total: float   # ganancia en pesos
    rendimiento_porcentual: float       # % sobre el capital aportado total
    monto_final_proyectado: float
    capital_aportado_total: float
