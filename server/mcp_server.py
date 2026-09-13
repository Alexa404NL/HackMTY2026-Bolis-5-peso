"""Servidor MCP: expone los motores de Metas, Presupuesto e Inversión y el Dashboard.

Tools = datos y acciones. Resources = plantillas A2UI (application/a2ui+json).
Cada tool que genera UI regresa un EmbeddedResource con los mensajes A2UI v0.9 ya llenos.

Módulos:
  - savings_goal : metas de ahorro (módulo original)
  - budget       : presupuesto mensual (nuevo)
  - investment   : proyección de inversión (nuevo)
  - dashboard    : configuración del dashboard y widgets (nuevo)
"""

import asyncio
import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any, TypedDict

import asyncpg
from dotenv import load_dotenv
from mcp.server.mcpserver import MCPServer
from mcp_types import CallToolResult, EmbeddedResource, TextContent, TextResourceContents, ToolAnnotations

import budget
import cards
import investment

A2UI_MIME = "application/a2ui+json"
SURFACE = "ahorro"
CATALOGO = "banorte-ahorro/v1"
# El agente lanza este servidor por stdio y el SDK no hereda su entorno: cargamos .env aquí.
load_dotenv(Path(__file__).parent / ".env")
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


# Postgres (Timescale) usado como almacén de documentos: una tabla, un JSONB por documento.
# Colecciones: metas {estado, proyeccion} · presupuestos / inversiones {estado, plan} · dashboard (clave=user_id) {widgets}

ESQUEMA = """
CREATE TABLE IF NOT EXISTS documentos (
  coleccion   text        NOT NULL,
  id          bigserial,
  clave       text,
  datos       jsonb       NOT NULL,
  creado      timestamptz NOT NULL DEFAULT now(),
  actualizado timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (coleccion, id)
);
CREATE UNIQUE INDEX IF NOT EXISTS documentos_clave ON documentos (coleccion, clave) WHERE clave IS NOT NULL;
"""

_pool: asyncpg.Pool | None = None
_pool_lock = asyncio.Lock()


async def _jsonb(con):
    await con.set_type_codec("jsonb", encoder=json.dumps, decoder=json.loads, schema="pg_catalog")


async def _db() -> asyncpg.Pool:
    """Pool perezoso: se abre y crea el esquema la primera vez que algo toca la BD."""
    global _pool
    async with _pool_lock:
        if _pool is None:
            url = os.environ.get("DATABASE_URL")
            if not url:
                raise RuntimeError("falta DATABASE_URL en server/.env")
            _pool = await asyncpg.create_pool(url, min_size=1, max_size=5, init=_jsonb)
            await _pool.execute(ESQUEMA)
    return _pool


def _id(valor):
    """Los ids llegan de JSON/LLM (int o str); un id inválido equivale a documento inexistente."""
    try:
        return int(valor)
    except (TypeError, ValueError):
        return None


def _doc(fila):
    if fila is None:
        return None
    return {"id": fila["id"], "creado": fila["creado"].isoformat(), "actualizado": fila["actualizado"].isoformat(), **fila["datos"]}


async def doc_insertar(coleccion: str, datos: dict) -> int:
    return await (await _db()).fetchval(
        "INSERT INTO documentos (coleccion, datos) VALUES ($1, $2) RETURNING id", coleccion, datos
    )


async def doc_actualizar(coleccion: str, id, datos: dict) -> bool:
    if (id := _id(id)) is None:
        return False
    estado = await (await _db()).execute(
        "UPDATE documentos SET datos = $3, actualizado = now() WHERE coleccion = $1 AND id = $2", coleccion, id, datos
    )
    return estado != "UPDATE 0"


async def doc_leer(coleccion: str, id) -> dict | None:
    if (id := _id(id)) is None:
        return None
    return _doc(await (await _db()).fetchrow(
        "SELECT id, creado, actualizado, datos FROM documentos WHERE coleccion = $1 AND id = $2", coleccion, id
    ))


async def doc_leer_clave(coleccion: str, clave: str) -> dict | None:
    return _doc(await (await _db()).fetchrow(
        "SELECT id, creado, actualizado, datos FROM documentos WHERE coleccion = $1 AND clave = $2", coleccion, clave
    ))


async def doc_guardar_clave(coleccion: str, clave: str, datos: dict):
    await (await _db()).execute(
        "INSERT INTO documentos (coleccion, clave, datos) VALUES ($1, $2, $3)"
        " ON CONFLICT (coleccion, clave) WHERE clave IS NOT NULL"
        " DO UPDATE SET datos = excluded.datos, actualizado = now()",
        coleccion, clave, datos,
    )


# --- Helpers por módulo (misma forma de retorno que antes) ---

async def db_insertar(estado, proyeccion):
    return await doc_insertar("metas", {"estado": estado, "proyeccion": proyeccion})


async def db_actualizar(goal_id, estado, proyeccion):
    if not await doc_actualizar("metas", goal_id, {"estado": estado, "proyeccion": proyeccion}):
        raise ValueError(f"la meta {goal_id} no existe")


async def db_leer(goal_id):
    return await doc_leer("metas", goal_id)


async def db_insertar_budget(estado, plan):
    return await doc_insertar("presupuestos", {"estado": estado, "plan": plan})


async def db_leer_budget(budget_id):
    return await doc_leer("presupuestos", budget_id)


async def db_insertar_investment(estado, plan):
    return await doc_insertar("inversiones", {"estado": estado, "plan": plan})


async def db_leer_investment(investment_id):
    return await doc_leer("inversiones", investment_id)


async def db_leer_dashboard(user_id: str = USER_ID_DEFAULT) -> dict:
    doc = await doc_leer_clave("dashboard", user_id)
    if doc is None:
        return {"user_id": user_id, "widgets": []}
    return {"user_id": user_id, "actualizado": doc["actualizado"], "widgets": doc.get("widgets", [])}


async def db_guardar_dashboard(config: dict, user_id: str = USER_ID_DEFAULT):
    await doc_guardar_clave("dashboard", user_id, {"widgets": config.get("widgets", [])})


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
async def update_savings_goal(
    estado: dict[str, Any], cambios: list[Respuesta], goal_id: int | None = None
) -> CallToolResult:
    """Aplica cambios del usuario (ej. aportacion_periodica, plazo_meses) sobre la proyección ya generada y recalcula.
    Si la meta ya está guardada, también actualiza el registro."""
    estado = _aplicar(estado, cambios)
    p, componentes = _componentes_meta(estado, goal_id)
    if goal_id is not None:
        await db_actualizar(goal_id, estado, p)
    datos = {"variante": p["variante"], "saldo_final": _elegido(p)["saldo_final"], "goal_id": goal_id, "estado": estado}
    return _resultado(datos, componentes, estado, goal_id)


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
async def save_savings_goal(estado: dict[str, Any], display_mode: str = "progress_tracker") -> CallToolResult:
    """Guarda la meta de ahorro de forma persistente y regresa el resumen de la meta guardada."""
    estado = _aplicar(estado, None)
    p = cards.simulate_projection(estado)
    goal_id = await db_insertar(estado, p)
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
        "preview": _preview_meta(estado, p),
    }
    return _resultado({"goal_id": goal_id, "widget": widget, "estado": estado}, componentes, estado, goal_id)


# --- Preview de widgets del Dashboard (listo para mostrar) ---
# Esquema: {kpi: {valor, etiqueta}, tono, progreso (0-1 | None), detalle,
#           serie ({valores, etiquetas} | None), desglose [{nombre, texto, pct}], filas [{etiqueta, texto}]}


def _pesos(n):
    return f"${n:,.0f}"


def _muestrear(serie, n=12):
    """Reduce una serie mensual a ~n puntos equiespaciados (incluye el último) con su etiqueta de mes."""
    idx = range(len(serie)) if len(serie) <= n else sorted({round(i * (len(serie) - 1) / (n - 1)) for i in range(n)})
    return {"valores": [serie[i] for i in idx], "etiquetas": [f"Mes {i}" for i in idx]}


def _preview_meta(estado, proyeccion):
    e = _elegido(proyeccion)
    meta = estado["monto_meta"]
    # Dato principal: lo ahorrado hoy (aportación inicial); la proyección es secundaria.
    ahorrado = estado["aportacion_inicial"]
    progreso = min(1.0, ahorrado / meta) if meta else 0.0
    proyectado = min(1.0, e["saldo_final"] / meta) if meta else 0.0
    filas = [
        {"etiqueta": "Aportación", "texto": f"{_pesos(estado['aportacion_periodica'])}/mes"},
        {"etiqueta": "Plazo", "texto": f"{estado['plazo_meses']} meses"},
    ]
    return {
        "kpi": {"valor": _pesos(ahorrado), "etiqueta": "ahorrado hoy"},
        "tono": "green" if proyectado >= 1 else "yellow",
        "chip": {"texto": f"Mes {e['mes_meta']}", "tono": "green"}
        if e["mes_meta"] is not None
        else {"texto": "No alcanza", "tono": "yellow"},
        "progreso": round(progreso, 3),
        "progreso_proyectado": round(proyectado, 3),
        "meta_texto": _pesos(meta),
        "meta_valor": meta,
        "proyectado_texto": _pesos(e["saldo_final"]),
        "detalle": f"Meta {_pesos(meta)} en {estado['plazo_meses']} meses",
        "serie": _muestrear(e["serie"]),
        "desglose": [],
        "filas": filas,
    }


def _preview_budget(plan):
    ingreso = plan["ingreso_mensual"]
    top = sorted(plan["categorias"], key=lambda c: c["monto"], reverse=True)
    return {
        "kpi": {"valor": _pesos(plan["balance_disponible"]), "etiqueta": "disponible"},
        "tono": plan["status_color"],
        "chip": {
            "texto": {"green": "Saludable", "yellow": "Ajustado"}.get(plan["status_color"], "Déficit"),
            "tono": plan["status_color"],
        },
        "progreso": round(min(1.0, plan["total_gastos"] / ingreso), 3) if ingreso else None,
        "detalle": f"Gastas {_pesos(plan['total_gastos'])} de {_pesos(ingreso)}",
        "gastos_texto": _pesos(plan["total_gastos"]),
        "serie": None,
        "desglose": [
            {"nombre": c["nombre"], "corto": c["nombre"][:3], "texto": _pesos(c["monto"]), "pct": round(c["monto"] / ingreso, 3) if ingreso else 0}
            for c in top
        ],
        "filas": [{"etiqueta": "Gastos fijos", "texto": _pesos(plan["gastos_fijos"])}],
    }


def _nombre_corto(nombre):
    """'CETES / Pagaré Banorte' → 'CETES'; 'Fondos de Inversión Mixtos' → 'Fondos Mixtos'."""
    return nombre.split(" / ")[0].split(" (")[0].replace("de Inversión ", "")


def _preview_investment(plan):
    signo = "+" if plan["rendimiento_porcentual"] >= 0 else ""
    return {
        "kpi": {"valor": f"{signo}{plan['rendimiento_porcentual']:.1f}%", "etiqueta": "rendimiento"},
        "tono": "green" if plan["rendimiento_porcentual"] > 0 else "yellow",
        "chip": {
            "texto": f"{signo}{_pesos(plan['rendimiento_estimado_total'])}",
            "tono": "green" if plan["rendimiento_porcentual"] > 0 else "yellow",
        },
        "progreso": None,
        "detalle": f"Final {_pesos(plan['monto_final_proyectado'])}",
        "total": _pesos(plan["monto_final_proyectado"]),
        "perfil_texto": f"{plan['perfil_riesgo'].capitalize()} · {plan['plazo_meses']} meses",
        "instrumentos": [
            {"nombre": _nombre_corto(i["nombre"]), "texto": f"{i['porcentaje']:.0f}%", "pct": round(i["porcentaje"] / 100, 3)}
            for i in plan["instrumentos"]
        ],
        "serie": _muestrear(plan["serie_mensual"]),
        "desglose": [],
        "filas": [
            {"etiqueta": "Aportado", "texto": _pesos(plan["capital_aportado_total"])},
            {"etiqueta": "Ganancia", "texto": f"{signo}{_pesos(plan['rendimiento_estimado_total'])}"},
        ],
    }


async def _hidratar(widget):
    """Reconstruye el preview del widget desde el documento de su módulo (None si ya no existe)."""
    tipo, i = widget.get("module_type"), widget.get("module_data_id")
    lector = {"savings_goal": db_leer, "budget": db_leer_budget, "investment": db_leer_investment}.get(tipo)
    r = await lector(i) if lector and i is not None else None
    if r is None:
        preview = None
    elif tipo == "savings_goal":
        preview = _preview_meta(r["estado"], r["proyeccion"])
    else:
        preview = (_preview_budget if tipo == "budget" else _preview_investment)(r["plan"])
    return {**widget, "preview": preview}


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
        if "widgets" in datos:
            value["widgets"] = datos["widgets"]
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
async def save_budget_plan(estado: dict[str, Any], display_mode: str = "compact_summary") -> CallToolResult:
    """Guarda el plan de presupuesto de forma persistente y regresa el resumen y el widget listo para el Dashboard.
    display_mode: compact_summary | chart_preview | progress_tracker"""
    estado = _aplicar_budget(estado, None)
    plan = budget.simulate_budget(estado)
    budget_id = await db_insertar_budget(estado, plan)
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
        "preview": _preview_budget(plan),
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
async def save_investment_plan(estado: dict[str, Any], display_mode: str = "chart_preview") -> CallToolResult:
    """Guarda el plan de inversión de forma persistente y regresa el resumen y el widget listo para el Dashboard.
    display_mode: compact_summary | chart_preview | progress_tracker"""
    estado = _aplicar_investment(estado, None)
    plan = investment.simulate_investment(estado)
    investment_id = await db_insertar_investment(estado, plan)
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
        "preview": _preview_investment(plan),
    }
    datos = {"investment_id": investment_id, "widget": widget, "estado": estado}
    return _resultado_modulo(datos, [resumen], "inversion", estado, investment_id)


# =============================================================================
# Tools: Dashboard
# =============================================================================


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
async def get_dashboard_config(user_id: str = USER_ID_DEFAULT) -> CallToolResult:
    """Lee la configuración actual del Dashboard (lista de widgets y su orden).
    Si no existe, regresa un Dashboard vacío."""
    config = await db_leer_dashboard(user_id)
    widgets = list(await asyncio.gather(*(_hidratar(w) for w in config.get("widgets", []))))
    if not widgets:
        comp = _componente("dashboard_vacio", "dashboard")
        return _resultado_modulo({"vacio": True, "widgets": []}, [comp], "dashboard")
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"vacio": False, "widgets": widgets}, [comp], "dashboard")


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=True))
async def save_dashboard_config(widgets: list[dict[str, Any]], user_id: str = USER_ID_DEFAULT) -> CallToolResult:
    """Guarda el layout completo del Dashboard (incluido el nuevo orden de widgets tras un reordenamiento).
    Sobreescribe la configuración anterior — es idempotente si se manda el mismo payload."""
    # Solo se persiste el layout; el preview se reconstruye al leer (get_dashboard_config)
    widgets = [{k: v for k, v in w.items() if k != "preview"} for w in widgets]
    # Re-asignar order según posición en la lista
    for i, w in enumerate(widgets):
        w["order"] = i
    config = {"user_id": user_id, "widgets": widgets}
    await db_guardar_dashboard(config, user_id)
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"guardado": True, "widgets": widgets}, [comp], "dashboard")


@mcp.tool(annotations=ToolAnnotations(read_only_hint=False, destructive_hint=False, idempotent_hint=False))
async def add_widget(
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
    config = await db_leer_dashboard(user_id)
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
    await db_guardar_dashboard({"user_id": user_id, "widgets": widgets}, user_id)
    comp = _componente("dashboard_layout", "dashboard", widgets=widgets)
    return _resultado_modulo({"agregado": True, "widget": nuevo_widget, "widgets": widgets}, [comp], "dashboard")


@mcp.tool(annotations=ToolAnnotations(read_only_hint=True, destructive_hint=False, idempotent_hint=True))
async def get_module_detail(module_type: str, module_data_id: int) -> CallToolResult:
    """Regresa el detalle guardado de un widget del Dashboard (resumen + plan o proyección) listo para mostrar.
    module_type: savings_goal | budget | investment. Si el registro no existe regresa encontrado=false sin UI."""
    if module_type == "savings_goal" and (r := await db_leer(module_data_id)):
        _, componentes = _componentes_meta(r["estado"], r["id"])
        return _resultado({"encontrado": True, "goal_id": r["id"], "estado": r["estado"]}, componentes, r["estado"], r["id"])
    if module_type == "budget" and (r := await db_leer_budget(module_data_id)):
        plan = r["plan"]
        componentes = [
            _componente("resumen_presupuesto_guardado", "resumen_budget", budget_id=r["id"], guardado=True, **plan),
            _componente("plan_presupuesto", "plan_budget", guardado=True, **plan),
        ]
        return _resultado_modulo({"encontrado": True, "budget_id": r["id"]}, componentes, "presupuesto", r["estado"], r["id"])
    if module_type == "investment" and (r := await db_leer_investment(module_data_id)):
        plan = r["plan"]
        componentes = [
            _componente("resumen_inversion_guardada", "resumen_inv", investment_id=r["id"], guardado=True, **plan),
            _componente("plan_inversion", "plan_inv", guardado=True, **plan),
        ]
        return _resultado_modulo({"encontrado": True, "investment_id": r["id"]}, componentes, "inversion", r["estado"], r["id"])
    return CallToolResult(content=[TextContent(type="text", text=json.dumps({"encontrado": False}))])


if __name__ == "__main__":
    mcp.run()
