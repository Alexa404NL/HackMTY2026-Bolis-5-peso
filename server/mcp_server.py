"""Servidor MCP: expone los motores de Metas, Presupuesto e Inversión y el Dashboard.

Tools = datos y acciones. Resources = plantillas A2UI (application/a2ui+json).
Cada tool que genera UI regresa un EmbeddedResource con los mensajes A2UI v0.9 ya llenos.

Módulos:
  - savings_goal : metas de ahorro (módulo original)
  - budget       : presupuesto mensual (nuevo)
  - investment   : proyección de inversión (nuevo)
  - dashboard    : configuración del dashboard y widgets (nuevo)
"""

import json
import os
import sqlite3
from contextlib import closing
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, TypedDict

from mcp.server.mcpserver import MCPServer
from mcp_types import CallToolResult, EmbeddedResource, TextContent, TextResourceContents, ToolAnnotations

import budget
import cards
import investment

A2UI_MIME = "application/a2ui+json"
SURFACE = "ahorro"
CATALOGO = "banorte-ahorro/v1"
DB = Path(os.environ.get("GOALS_DB", Path(__file__).parent / "data" / "goals.db"))
USER_ID_DEFAULT = "default"

mcp = MCPServer("banorte-ahorro")


class Respuesta(TypedDict):
    campo: str
    valor: str | int | float | bool


# --- Plantillas A2UI (Resources) -------------------------------------------------

ESTADO = {"path": "/estado"}
GOAL_ID = {"path": "/goal_id"}


def _evento(nombre):
    return {"event": {"name": nombre, "context": {"estado": ESTADO, "goal_id": GOAL_ID}}}


TEMPLATES = {
    # --- Metas de ahorro (módulo original) ---
    "tarjeta_pregunta": {"component": "TarjetaPregunta", "action": _evento("responder")},
    "proyeccion_ahorro_simple": {
        "component": "ProyeccionAhorroSimple",
        "accionEditar": _evento("editar_meta"),
        "accionGuardar": _evento("guardar_meta"),
    },
    "proyeccion_ahorro_multi": {
        "component": "ProyeccionAhorroMulti",
        "accionEditar": _evento("editar_meta"),
        "accionGuardar": _evento("guardar_meta"),
    },
    "resumen_meta_guardada": {"component": "ResumenMetaGuardada"},
    # --- Presupuesto (nuevo) ---
    "tarjeta_pregunta_budget": {"component": "TarjetaPregunta", "action": _evento("responder_budget")},
    "plan_presupuesto": {
        "component": "PlanPresupuesto",
        "accionGuardar": _evento("guardar_presupuesto"),
        "accionAgregarWidget": _evento("agregar_widget_budget"),
    },
    "resumen_presupuesto_guardado": {"component": "ResumenPresupuestoGuardado"},
    # --- Inversión (nuevo) ---
    "tarjeta_pregunta_investment": {"component": "TarjetaPregunta", "action": _evento("responder_investment")},
    "plan_inversion": {
        "component": "PlanInversion",
        "accionGuardar": _evento("guardar_inversion"),
        "accionAgregarWidget": _evento("agregar_widget_investment"),
    },
    "resumen_inversion_guardada": {"component": "ResumenInversionGuardada"},
    # --- Dashboard (nuevo) ---
    "dashboard_vacio": {
        "component": "DashboardVacio",
        "accionAgregarWidget": _evento("abrir_selector_widget"),
    },
    "dashboard_layout": {
        "component": "DashboardLayout",
        "accionAgregarWidget": _evento("abrir_selector_widget"),
        "accionReordenar": _evento("reordenar_widgets"),
    },
}


def _registrar_template(nombre):
    @mcp.resource(f"a2ui://templates/{nombre}", name=nombre, mime_type=A2UI_MIME)
    def leer() -> str:
        return json.dumps(TEMPLATES[nombre], ensure_ascii=False)


for _nombre in TEMPLATES:
    _registrar_template(_nombre)


def _componente(template, id, **props):
    return {**deepcopy(TEMPLATES[template]), "id": id, **props}


def _resultado(datos, componentes=None, estado=None, goal_id=None):
    contenido = [TextContent(type="text", text=json.dumps(datos, ensure_ascii=False))]
    if componentes:
        value = {"estado": estado, "goal_id": goal_id}
        if "widget" in datos:
            value["widget"] = datos["widget"]
        mensajes = [
            {"version": "v0.9", "createSurface": {"surfaceId": SURFACE, "catalogId": CATALOGO}},
            {
                "version": "v0.9",
                "updateDataModel": {"surfaceId": SURFACE, "path": "/", "value": value},
            },
            {
                "version": "v0.9",
                "updateComponents": {
                    "surfaceId": SURFACE,
                    "components": [
                        {"id": "root", "component": "Column", "children": [c["id"] for c in componentes]},
                        *componentes,
                    ],
                },
            },
        ]
        contenido.append(
            EmbeddedResource(
                type="resource",
                resource=TextResourceContents(
                    uri=f"a2ui://surface/{SURFACE}", mime_type=A2UI_MIME, text=json.dumps(mensajes, ensure_ascii=False)
                ),
            )
        )
    return CallToolResult(content=contenido)


def _opciones(nodo):
    if nodo["tipo_respuesta"] == "si_no":
        return [{"valor": True, "etiqueta": "Sí"}, {"valor": False, "etiqueta": "No"}]
    if nodo["opciones"] is None:
        return None
    if nodo["campo"] == "plazo_meses":
        return [{"valor": m, "etiqueta": f"{m} meses"} for m in nodo["opciones"]]
    return [{"valor": o, "etiqueta": o[0].upper() + o[1:]} for o in nodo["opciones"]]


def _elegido(proyeccion):
    return next(
        (e for e in proyeccion["escenarios"] if e["perfil"] == proyeccion["perfil_elegido"]),
        proyeccion["escenarios"][0],
    )


def _componentes_meta(estado, goal_id):
    p = cards.simulate_projection(estado)
    proyeccion = _componente(
        f"proyeccion_ahorro_{p['variante']}",
        "proyeccion",
        objetivo=estado["objetivo"],
        aportacion_inicial=estado["aportacion_inicial"],
        aportacion_periodica=estado["aportacion_periodica"],
        guardada=goal_id is not None,
        **p,
    )
    componentes = [proyeccion]
    if goal_id is not None:
        e = _elegido(p)
        resumen = _componente(
            "resumen_meta_guardada",
            "resumen",
            goal_id=goal_id,
            objetivo=estado["objetivo"],
            monto_meta=estado["monto_meta"],
            plazo_meses=estado["plazo_meses"],
            aportacion_periodica=estado["aportacion_periodica"],
            perfil=e["perfil"],
            saldo_final=e["saldo_final"],
            mes_meta=e["mes_meta"],
        )
        componentes.insert(0, resumen)
    return p, componentes


def _aplicar(estado, respuestas):
    estado = {c: (estado or {}).get(c) for c in cards.CAMPOS}
    for r in respuestas or []:
        estado = cards.aplicar_respuesta(estado, r["campo"], r["valor"])
    return estado


# --- Persistencia ---------------------------------------------------------------


def _db():
    DB.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(DB)
    # Metas de ahorro (original)
    con.execute(
        "CREATE TABLE IF NOT EXISTS goals (id INTEGER PRIMARY KEY AUTOINCREMENT, creado TEXT NOT NULL,"
        " actualizado TEXT NOT NULL, estado TEXT NOT NULL, proyeccion TEXT NOT NULL)"
    )
    # Presupuestos (nuevo)
    con.execute(
        "CREATE TABLE IF NOT EXISTS budgets (id INTEGER PRIMARY KEY AUTOINCREMENT, creado TEXT NOT NULL,"
        " actualizado TEXT NOT NULL, estado TEXT NOT NULL, plan TEXT NOT NULL)"
    )
    # Inversiones (nuevo)
    con.execute(
        "CREATE TABLE IF NOT EXISTS investments (id INTEGER PRIMARY KEY AUTOINCREMENT, creado TEXT NOT NULL,"
        " actualizado TEXT NOT NULL, estado TEXT NOT NULL, plan TEXT NOT NULL)"
    )
    # Dashboard config (nuevo)
    con.execute(
        "CREATE TABLE IF NOT EXISTS dashboard_config (user_id TEXT PRIMARY KEY, actualizado TEXT NOT NULL,"
        " widgets TEXT NOT NULL)"
    )
    return con


def _ahora():
    return datetime.now(timezone.utc).isoformat()


# --- Helpers de persistencia: Metas de ahorro ---

def db_insertar(estado, proyeccion):
    with closing(_db()) as con, con:
        cur = con.execute(
            "INSERT INTO goals (creado, actualizado, estado, proyeccion) VALUES (?, ?, ?, ?)",
            (_ahora(), _ahora(), json.dumps(estado), json.dumps(proyeccion)),
        )
        return cur.lastrowid


def db_actualizar(goal_id, estado, proyeccion):
    with closing(_db()) as con, con:
        cur = con.execute(
            "UPDATE goals SET actualizado = ?, estado = ?, proyeccion = ? WHERE id = ?",
            (_ahora(), json.dumps(estado), json.dumps(proyeccion), goal_id),
        )
        if cur.rowcount == 0:
            raise ValueError(f"la meta {goal_id} no existe")


def db_leer(goal_id):
    with closing(_db()) as con:
        fila = con.execute("SELECT id, creado, actualizado, estado, proyeccion FROM goals WHERE id = ?", (goal_id,)).fetchone()
    if fila is None:
        return None
    return {"id": fila[0], "creado": fila[1], "actualizado": fila[2], "estado": json.loads(fila[3]), "proyeccion": json.loads(fila[4])}


# --- Helpers de persistencia: Presupuestos ---

def db_insertar_budget(estado, plan):
    with closing(_db()) as con, con:
        cur = con.execute(
            "INSERT INTO budgets (creado, actualizado, estado, plan) VALUES (?, ?, ?, ?)",
            (_ahora(), _ahora(), json.dumps(estado), json.dumps(plan)),
        )
        return cur.lastrowid


def db_leer_budget(budget_id):
    with closing(_db()) as con:
        fila = con.execute("SELECT id, creado, actualizado, estado, plan FROM budgets WHERE id = ?", (budget_id,)).fetchone()
    if fila is None:
        return None
    return {"id": fila[0], "creado": fila[1], "actualizado": fila[2], "estado": json.loads(fila[3]), "plan": json.loads(fila[4])}


# --- Helpers de persistencia: Inversiones ---

def db_insertar_investment(estado, plan):
    with closing(_db()) as con, con:
        cur = con.execute(
            "INSERT INTO investments (creado, actualizado, estado, plan) VALUES (?, ?, ?, ?)",
            (_ahora(), _ahora(), json.dumps(estado), json.dumps(plan)),
        )
        return cur.lastrowid


def db_leer_investment(investment_id):
    with closing(_db()) as con:
        fila = con.execute("SELECT id, creado, actualizado, estado, plan FROM investments WHERE id = ?", (investment_id,)).fetchone()
    if fila is None:
        return None
    return {"id": fila[0], "creado": fila[1], "actualizado": fila[2], "estado": json.loads(fila[3]), "plan": json.loads(fila[4])}


# --- Helpers de persistencia: Dashboard ---

def db_leer_dashboard(user_id: str = USER_ID_DEFAULT) -> dict:
    with closing(_db()) as con:
        fila = con.execute("SELECT user_id, actualizado, widgets FROM dashboard_config WHERE user_id = ?", (user_id,)).fetchone()
    if fila is None:
        return {"user_id": user_id, "widgets": []}
    return {"user_id": fila[0], "actualizado": fila[1], "widgets": json.loads(fila[2])}


def db_guardar_dashboard(config: dict, user_id: str = USER_ID_DEFAULT):
    widgets_json = json.dumps(config.get("widgets", []))
    with closing(_db()) as con, con:
        con.execute(
            "INSERT INTO dashboard_config (user_id, actualizado, widgets) VALUES (?, ?, ?)"
            " ON CONFLICT(user_id) DO UPDATE SET actualizado = excluded.actualizado, widgets = excluded.widgets",
            (user_id, _ahora(), widgets_json),
        )


# --- Tools ----------------------------------------------------------------------


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def get_next_question(estado: dict[str, Any], respuestas: list[Respuesta] | None = None) -> CallToolResult:
    """Valida y aplica respuestas del perfilamiento y regresa la siguiente tarjeta de pregunta.
    Si el perfilamiento queda completo, regresa directamente la proyección (completo=true)."""
    error = None
    estado = _aplicar(estado, None)
    for r in respuestas or []:
        try:
            estado = cards.aplicar_respuesta(estado, r["campo"], r["valor"])
        except ValueError as e:
            error = str(e)
    tarjeta = cards.get_next_question(estado)
    if tarjeta is None:
        # No depender de que el LLM encadene simulate_projection: la proyección sale en el mismo turno.
        p, componentes = _componentes_meta(estado, None)
        datos = {"completo": True, "variante": p["variante"], "saldo_final": _elegido(p)["saldo_final"], "estado": estado}
        return _resultado(datos, componentes, estado)
    componente = _componente(
        "tarjeta_pregunta",
        "tarjeta",
        pregunta=tarjeta["pregunta"],
        tipo_respuesta=tarjeta["tipo_respuesta"],
        campo=tarjeta["campo"],
        opciones=_opciones(tarjeta),
        paso=tarjeta["paso"],
        total=tarjeta["total"],
        error=error,
    )
    datos = {"completo": False, "campo_preguntado": tarjeta["campo"], "error": error, "estado": estado}
    return _resultado(datos, [componente], estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def simulate_projection(estado: dict[str, Any]) -> CallToolResult:
    """Calcula la proyección de ahorro de un estado de perfilamiento completo y regresa el componente de proyección."""
    estado = _aplicar(estado, None)
    p, componentes = _componentes_meta(estado, None)
    datos = {"variante": p["variante"], "saldo_final": _elegido(p)["saldo_final"], "estado": estado}
    return _resultado(datos, componentes, estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=True))
def update_savings_goal(
    estado: dict[str, Any], cambios: list[Respuesta], goal_id: int | None = None
) -> CallToolResult:
    """Aplica cambios del usuario (ej. aportacion_periodica, plazo_meses) sobre la proyección ya generada y recalcula.
    Si la meta ya está guardada, también actualiza el registro."""
    estado = _aplicar(estado, cambios)
    p, componentes = _componentes_meta(estado, goal_id)
    if goal_id is not None:
        db_actualizar(goal_id, estado, p)
    datos = {"variante": p["variante"], "saldo_final": _elegido(p)["saldo_final"], "goal_id": goal_id, "estado": estado}
    return _resultado(datos, componentes, estado, goal_id)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
def save_savings_goal(estado: dict[str, Any], display_mode: str = "progress_tracker") -> CallToolResult:
    """Guarda la meta de ahorro de forma persistente y regresa el resumen de la meta guardada."""
    estado = _aplicar(estado, None)
    p = cards.simulate_projection(estado)
    goal_id = db_insertar(estado, p)
    _, componentes = _componentes_meta(estado, goal_id)
    e = _elegido(p)
    widget = {
        "module_type": "savings_goal",
        "title": estado.get("objetivo", "Meta de ahorro"),
        "display_mode": display_mode,
        "module_data_id": goal_id,
        "summary": {
            "primary_metric": f"{min(100.0, e['saldo_final'] / estado['monto_meta'] * 100):.0f}% completado",
            "secondary_metric": f"Meta: ${estado['monto_meta']:,.0f}",
            "status_color": "green",
        },
    }
    return _resultado({"goal_id": goal_id, "widget": widget, "estado": estado}, componentes, estado, goal_id)


# =============================================================================
# Tools: Presupuesto
# =============================================================================


def _aplicar_budget(estado, respuestas):
    estado = {c: (estado or {}).get(c) for c in budget.CAMPOS}
    for r in respuestas or []:
        estado = budget.aplicar_respuesta(estado, r["campo"], r["valor"])
    return estado


def _resultado_modulo(datos, componentes=None, superficie="ahorro", estado=None, record_id=None):
    """Variante de _resultado que permite especificar la superficie A2UI del módulo."""
    contenido = [TextContent(type="text", text=json.dumps(datos, ensure_ascii=False))]
    if componentes:
        value = {"estado": estado, "record_id": record_id}
        if "widget" in datos:
            value["widget"] = datos["widget"]
        mensajes = [
            {"version": "v0.9", "createSurface": {"surfaceId": superficie, "catalogId": CATALOGO}},
            {
                "version": "v0.9",
                "updateDataModel": {
                    "surfaceId": superficie,
                    "path": "/",
                    "value": value,
                },
            },
            {
                "version": "v0.9",
                "updateComponents": {
                    "surfaceId": superficie,
                    "components": [
                        {"id": "root", "component": "Column", "children": [c["id"] for c in componentes]},
                        *componentes,
                    ],
                },
            },
        ]
        contenido.append(
            EmbeddedResource(
                type="resource",
                resource=TextResourceContents(
                    uri=f"a2ui://surface/{superficie}",
                    mime_type=A2UI_MIME,
                    text=json.dumps(mensajes, ensure_ascii=False),
                ),
            )
        )
    return CallToolResult(content=contenido)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def get_budget_questions(estado: dict[str, Any], respuestas: list[Respuesta] | None = None) -> CallToolResult:
    """Aplica respuestas del perfilamiento de presupuesto y regresa la siguiente tarjeta.
    Si el perfilamiento está completo, regresa directamente el plan de presupuesto simulado."""
    error = None
    estado = _aplicar_budget(estado, None)
    for r in respuestas or []:
        try:
            estado = budget.aplicar_respuesta(estado, r["campo"], r["valor"])
        except ValueError as e:
            error = str(e)
    tarjeta = budget.get_next_question(estado)
    if tarjeta is None:
        plan = budget.simulate_budget(estado)
        comp = _componente("plan_presupuesto", "plan_budget", guardado=False, **plan)
        datos = {"completo": True, "balance_disponible": plan["balance_disponible"], "estado": estado}
        return _resultado_modulo(datos, [comp], "presupuesto", estado)
    comp = _componente(
        "tarjeta_pregunta_budget",
        "tarjeta_budget",
        pregunta=tarjeta["pregunta"],
        tipo_respuesta=tarjeta["tipo_respuesta"],
        campo=tarjeta["campo"],
        opciones=_opciones(tarjeta),
        paso=tarjeta["paso"],
        total=tarjeta["total"],
        error=error,
    )
    datos = {"completo": False, "campo_preguntado": tarjeta["campo"], "error": error, "estado": estado}
    return _resultado_modulo(datos, [comp], "presupuesto", estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def simulate_budget_plan(estado: dict[str, Any]) -> CallToolResult:
    """Calcula el plan de presupuesto de un estado de perfilamiento completo y regresa el componente de visualización."""
    estado = _aplicar_budget(estado, None)
    plan = budget.simulate_budget(estado)
    comp = _componente("plan_presupuesto", "plan_budget", guardado=False, **plan)
    datos = {"balance_disponible": plan["balance_disponible"], "status_color": plan["status_color"], "estado": estado}
    return _resultado_modulo(datos, [comp], "presupuesto", estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
def save_budget_plan(estado: dict[str, Any], display_mode: str = "compact_summary") -> CallToolResult:
    """Guarda el plan de presupuesto de forma persistente y regresa el resumen y el widget listo para el Dashboard.
    display_mode: compact_summary | chart_preview | progress_tracker"""
    estado = _aplicar_budget(estado, None)
    plan = budget.simulate_budget(estado)
    budget_id = db_insertar_budget(estado, plan)
    resumen = _componente(
        "resumen_presupuesto_guardado",
        "resumen_budget",
        budget_id=budget_id,
        guardado=True,
        **plan,
    )
    widget = {
        "module_type": "budget",
        "title": "Presupuesto Mensual",
        "display_mode": display_mode,
        "module_data_id": budget_id,
        "summary": {
            "primary_metric": f"Balance: ${plan['balance_disponible']:,.0f}",
            "secondary_metric": f"Gasto total: ${plan['total_gastos']:,.0f}",
            "status_color": plan["status_color"],
        },
    }
    datos = {"budget_id": budget_id, "widget": widget, "estado": estado}
    return _resultado_modulo(datos, [resumen], "presupuesto", estado, budget_id)


# =============================================================================
# Tools: Inversión
# =============================================================================


def _aplicar_investment(estado, respuestas):
    estado = {c: (estado or {}).get(c) for c in investment.CAMPOS}
    for r in respuestas or []:
        estado = investment.aplicar_respuesta(estado, r["campo"], r["valor"])
    return estado


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def get_investment_questions(estado: dict[str, Any], respuestas: list[Respuesta] | None = None) -> CallToolResult:
    """Aplica respuestas del perfilamiento de inversión y regresa la siguiente tarjeta.
    Si el perfilamiento está completo, regresa directamente la proyección de inversión."""
    error = None
    estado = _aplicar_investment(estado, None)
    for r in respuestas or []:
        try:
            estado = investment.aplicar_respuesta(estado, r["campo"], r["valor"])
        except ValueError as e:
            error = str(e)
    tarjeta = investment.get_next_question(estado)
    if tarjeta is None:
        plan = investment.simulate_investment(estado)
        comp = _componente("plan_inversion", "plan_inv", guardado=False, **plan)
        datos = {
            "completo": True,
            "monto_final_proyectado": plan["monto_final_proyectado"],
            "rendimiento_porcentual": plan["rendimiento_porcentual"],
            "estado": estado,
        }
        return _resultado_modulo(datos, [comp], "inversion", estado)
    # Opciones especiales: plazo en meses y perfil de riesgo
    opciones = None
    if tarjeta["opciones"] is not None:
        if tarjeta["campo"] == "plazo_meses":
            opciones = [{"valor": m, "etiqueta": f"{m} meses"} for m in tarjeta["opciones"]]
        else:
            opciones = [{"valor": o, "etiqueta": o[0].upper() + o[1:]} for o in tarjeta["opciones"]]
    comp = _componente(
        "tarjeta_pregunta_investment",
        "tarjeta_inv",
        pregunta=tarjeta["pregunta"],
        tipo_respuesta=tarjeta["tipo_respuesta"],
        campo=tarjeta["campo"],
        opciones=opciones,
        paso=tarjeta["paso"],
        total=tarjeta["total"],
        error=error,
    )
    datos = {"completo": False, "campo_preguntado": tarjeta["campo"], "error": error, "estado": estado}
    return _resultado_modulo(datos, [comp], "inversion", estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def simulate_investment_growth(estado: dict[str, Any]) -> CallToolResult:
    """Calcula la proyección de inversión de un estado completo y regresa el componente de visualización."""
    estado = _aplicar_investment(estado, None)
    plan = investment.simulate_investment(estado)
    comp = _componente("plan_inversion", "plan_inv", guardado=False, **plan)
    datos = {
        "monto_final_proyectado": plan["monto_final_proyectado"],
        "rendimiento_porcentual": plan["rendimiento_porcentual"],
        "estado": estado,
    }
    return _resultado_modulo(datos, [comp], "inversion", estado)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
def save_investment_plan(estado: dict[str, Any], display_mode: str = "chart_preview") -> CallToolResult:
    """Guarda el plan de inversión de forma persistente y regresa el resumen y el widget listo para el Dashboard.
    display_mode: compact_summary | chart_preview | progress_tracker"""
    estado = _aplicar_investment(estado, None)
    plan = investment.simulate_investment(estado)
    investment_id = db_insertar_investment(estado, plan)
    resumen = _componente(
        "resumen_inversion_guardada",
        "resumen_inv",
        investment_id=investment_id,
        guardado=True,
        **plan,
    )
    signo = "+" if plan["rendimiento_porcentual"] >= 0 else ""
    widget = {
        "module_type": "investment",
        "title": "Portafolio de Inversión",
        "display_mode": display_mode,
        "module_data_id": investment_id,
        "summary": {
            "primary_metric": f"{signo}{plan['rendimiento_porcentual']:.1f}% rendimiento",
            "secondary_metric": f"Final: ${plan['monto_final_proyectado']:,.0f}",
            "status_color": "green" if plan["rendimiento_porcentual"] > 0 else "yellow",
        },
    }
    datos = {"investment_id": investment_id, "widget": widget, "estado": estado}
    return _resultado_modulo(datos, [resumen], "inversion", estado, investment_id)


# =============================================================================
# Tools: Dashboard
# =============================================================================


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
def get_dashboard_config(user_id: str = USER_ID_DEFAULT) -> CallToolResult:
    """Lee la configuración actual del Dashboard (lista de widgets y su orden).
    Si no existe, regresa un Dashboard vacío."""
    config = db_leer_dashboard(user_id)
    widgets = config.get("widgets", [])
    if not widgets:
        comp = _componente("dashboard_vacio", "dashboard")
        return _resultado_modulo({"vacio": True, "widgets": []}, [comp], "dashboard")
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"vacio": False, "widgets": widgets}, [comp], "dashboard")


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=True))
def save_dashboard_config(widgets: list[dict[str, Any]], user_id: str = USER_ID_DEFAULT) -> CallToolResult:
    """Guarda el layout completo del Dashboard (incluido el nuevo orden de widgets tras un reordenamiento).
    Sobreescribe la configuración anterior — es idempotente si se manda el mismo payload."""
    # Re-asignar order según posición en la lista
    for i, w in enumerate(widgets):
        w["order"] = i
    config = {"user_id": user_id, "widgets": widgets}
    db_guardar_dashboard(config, user_id)
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"guardado": True, "widgets": widgets}, [comp], "dashboard")


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
def add_widget(
    module_type: str,
    title: str,
    module_data_id: int,
    summary: dict[str, str],
    display_mode: str = "compact_summary",
    user_id: str = USER_ID_DEFAULT,
) -> CallToolResult:
    """Agrega un nuevo widget al Dashboard del usuario y guarda la configuración actualizada.
    module_type: savings_goal | budget | investment
    summary: {primary_metric, secondary_metric, status_color}
    display_mode: compact_summary | chart_preview | progress_tracker"""
    config = db_leer_dashboard(user_id)
    widgets = config.get("widgets", [])
    import uuid
    nuevo_widget = {
        "id": str(uuid.uuid4()),
        "module_type": module_type,
        "title": title,
        "order": len(widgets),
        "display_mode": display_mode,
        "module_data_id": module_data_id,
        "summary": summary,
    }
    widgets.append(nuevo_widget)
    db_guardar_dashboard({"user_id": user_id, "widgets": widgets}, user_id)
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"agregado": True, "widget": nuevo_widget, "widgets": widgets}, [comp], "dashboard")


if __name__ == "__main__":
    mcp.run()
