"""Servidor MCP: expone el motor de tarjetas, la proyección y la persistencia de metas.

Tools = datos y acciones. Resources = plantillas A2UI (application/a2ui+json).
Cada tool que genera UI regresa un EmbeddedResource con los mensajes A2UI v0.9 ya llenos.
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

import cards

A2UI_MIME = "application/a2ui+json"
SURFACE = "ahorro"
CATALOGO = "banorte-ahorro/v1"
DB = Path(os.environ.get("GOALS_DB", Path(__file__).parent / "data" / "goals.db"))

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
        mensajes = [
            {"version": "v0.9", "createSurface": {"surfaceId": SURFACE, "catalogId": CATALOGO}},
            {
                "version": "v0.9",
                "updateDataModel": {"surfaceId": SURFACE, "path": "/", "value": {"estado": estado, "goal_id": goal_id}},
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
    con.execute(
        "CREATE TABLE IF NOT EXISTS goals (id INTEGER PRIMARY KEY AUTOINCREMENT, creado TEXT NOT NULL,"
        " actualizado TEXT NOT NULL, estado TEXT NOT NULL, proyeccion TEXT NOT NULL)"
    )
    return con


def _ahora():
    return datetime.now(timezone.utc).isoformat()


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
def save_savings_goal(estado: dict[str, Any]) -> CallToolResult:
    """Guarda la meta de ahorro de forma persistente y regresa el resumen de la meta guardada."""
    estado = _aplicar(estado, None)
    p = cards.simulate_projection(estado)
    goal_id = db_insertar(estado, p)
    _, componentes = _componentes_meta(estado, goal_id)
    return _resultado({"goal_id": goal_id, "estado": estado}, componentes, estado, goal_id)


if __name__ == "__main__":
    mcp.run()
