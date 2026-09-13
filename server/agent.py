"""Agente: recibe intención o acciones del cliente, orquesta tools MCP con el LLM y regresa mensajes A2UI.

Correr: uv run uvicorn agent:app --port 8000
"""

import json
import os
import sys
from contextlib import asynccontextmanager
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from mcp import Client
from mcp.client.stdio import StdioServerParameters
from openai import AsyncOpenAI
from pydantic import BaseModel

AQUI = Path(__file__).parent
load_dotenv(AQUI / ".env")

MODELO = os.environ.get("MODELO", "google/gemini-2.5-flash")
A2UI_MIME = "application/a2ui+json"
INYECTADOS = ("estado", "goal_id")  # el agente los pasa a las tools; el LLM nunca los ve ni los escribe
MAX_PASOS = 6
MAX_TOKENS = int(os.environ.get("MAX_TOKENS", 2048))  # el agente solo emite tool calls y una frase corta
LOG = AQUI / "data" / "turns.jsonl"

SISTEMA = """Eres el agente de un simulador de Banorte. Tu trabajo es ORQUESTAR herramientas:
nunca redactes preguntas, nunca calcules ni inventes cifras. Toda la interfaz la generan las herramientas.

Reglas según la entrada:
1. Texto libre: llama get_next_question (ahorro), get_budget_questions (presupuesto), o get_investment_questions (inversión).
2. "ACCIÓN responder": llama get_next_question con respuestas=[{campo, valor}].
3. "ACCIÓN responder_budget": llama get_budget_questions con respuestas=[{campo, valor}].
4. "ACCIÓN responder_investment": llama get_investment_questions con respuestas=[{campo, valor}].
5. "ACCIÓN editar_meta": llama update_savings_goal con cambios = los cambios recibidos.
6. "ACCIÓN guardar_meta": llama save_savings_goal.
7. "ACCIÓN guardar_presupuesto": llama save_budget_plan.
8. "ACCIÓN guardar_inversion": llama save_investment_plan.
9. "ACCIÓN save_dashboard_layout": llama save_dashboard_config con widgets recibidos.
El estado del perfilamiento se maneja internamente; no lo envíes.
Al terminar, responde con UNA frase corta y cálida en español (máximo 15 palabras), sin cifras."""

llm = AsyncOpenAI(base_url="https://openrouter.ai/api/v1", api_key=os.environ["API_ROUTER"])
# ponytail: conversaciones en memoria, se pierden al reiniciar; las metas guardadas sí persisten en SQLite
conversaciones: dict[str, dict] = {}


def _a_openai(tool):
    schema = deepcopy(tool.input_schema)
    for k in INYECTADOS:
        schema.get("properties", {}).pop(k, None)
        if k in schema.get("required", []):
            schema["required"].remove(k)
    return {"type": "function", "function": {"name": tool.name, "description": tool.description or "", "parameters": schema}}


@asynccontextmanager
async def lifespan(app: FastAPI):
    servidor = StdioServerParameters(command=sys.executable, args=[str(AQUI / "mcp_server.py")], cwd=str(AQUI))
    async with Client(servidor) as mcp:
        tools = (await mcp.list_tools()).tools
        app.state.mcp = mcp
        app.state.tools = [_a_openai(t) for t in tools]
        app.state.params = {t.name: set(t.input_schema.get("properties", {})) for t in tools}
        yield


app = FastAPI(lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_methods=["*"],
    allow_headers=["*"],
)


class Turno(BaseModel):
    conversation_id: str
    texto: str | None = None
    action: dict | None = None


def _leer_resultado(res):
    texto = "\n".join(c.text for c in res.content if c.type == "text")
    ui = next(
        (json.loads(c.resource.text) for c in res.content if c.type == "resource" and c.resource.mime_type == A2UI_MIME),
        None,
    )
    return texto, ui


def _con_mensaje(ui, texto):
    """Agrega la frase del agente como primer hijo de la superficie."""
    if ui is None:
        ui = [
            {"version": "v0.9", "createSurface": {"surfaceId": "ahorro", "catalogId": "banorte-ahorro/v1"}},
            {"version": "v0.9", "updateComponents": {"surfaceId": "ahorro", "components": [{"id": "root", "component": "Column", "children": []}]}},
        ]
    ui = deepcopy(ui)
    if not texto:
        return ui
    for m in ui:
        if "updateComponents" in m:
            comps = [c for c in m["updateComponents"]["components"] if c["id"] != "mensaje"]
            root = next(c for c in comps if c["id"] == "root")
            root["children"] = ["mensaje", *[h for h in root["children"] if h != "mensaje"]]
            m["updateComponents"]["components"] = [*comps, {"id": "mensaje", "component": "MensajeAgente", "texto": texto}]
    return ui


@app.post("/turn")
async def turn(t: Turno):
    if not (t.texto or t.action):
        raise HTTPException(422, "se requiere texto o action")
    conv = conversaciones.setdefault(
        t.conversation_id,
        {"mensajes": [{"role": "system", "content": SISTEMA}], "estado": {}, "goal_id": None, "ui": None},
    )

    if t.action:
        # El servidor es la fuente de verdad (se actualiza con cada resultado de tool); el data model del
        # cliente puede estar atrasado. Solo se usa si el servidor no tiene estado (ej. reinicio del backend).
        ctx = t.action.get("context") or {}
        if not conv["estado"]:
            conv["estado"] = ctx.get("estado") or {}
        if conv["goal_id"] is None:
            conv["goal_id"] = ctx.get("goal_id")
        visible = {k: v for k, v in ctx.items() if k not in INYECTADOS}
        entrada = f"ACCIÓN {t.action.get('name')}: {json.dumps(visible, ensure_ascii=False)}"
    else:
        entrada = t.texto

    if entrada == "__get_dashboard__":
        res = await app.state.mcp.call_tool("get_dashboard_config", {})
        texto, ui = _leer_resultado(res)
        return {"messages": _con_mensaje(ui, "")}

    inicio = len(conv["mensajes"])
    conv["mensajes"].append({"role": "user", "content": entrada})
    llamadas, texto_final, ui = [], "", None
    try:
        for _ in range(MAX_PASOS):
            r = await llm.chat.completions.create(
                model=MODELO, messages=conv["mensajes"], tools=app.state.tools, max_tokens=MAX_TOKENS
            )
            msg = r.choices[0].message
            conv["mensajes"].append(msg.model_dump(exclude_none=True))
            if not msg.tool_calls:
                texto_final = msg.content or ""
                break
            for call in msg.tool_calls:
                nombre = call.function.name
                args = json.loads(call.function.arguments or "{}")
                for k in INYECTADOS:
                    if k in app.state.params.get(nombre, ()):
                        args[k] = conv[k]
                res = await app.state.mcp.call_tool(nombre, args)
                texto, nuevo_ui = _leer_resultado(res)
                if not res.is_error:
                    datos = json.loads(texto)
                    conv["estado"] = datos.get("estado", conv["estado"])
                    conv["goal_id"] = datos.get("goal_id", conv["goal_id"])
                    ui = nuevo_ui or ui
                llamadas.append({"tool": nombre, "args": {k: v for k, v in args.items() if k not in INYECTADOS}, "error": res.is_error})
                conv["mensajes"].append({"role": "tool", "tool_call_id": call.id, "content": texto})
        if ui is None and conv["ui"] is None:
            # El LLM no produjo ninguna UI (ej. mandó mal el prefill y se rindió): arrancar el perfilamiento sin prefill.
            res = await app.state.mcp.call_tool("get_next_question", {"estado": conv["estado"]})
            _, ui = _leer_resultado(res)
            llamadas.append({"tool": "get_next_question", "args": {}, "error": res.is_error, "respaldo": True})
            texto_final = ""
    except Exception as e:
        del conv["mensajes"][inicio:]
        raise HTTPException(502, f"falló el turno del agente: {e}") from e

    conv["ui"] = ui or conv["ui"]
    LOG.parent.mkdir(parents=True, exist_ok=True)
    with LOG.open("a") as f:
        registro = {"ts": datetime.now(timezone.utc).isoformat(), "conversation_id": t.conversation_id,
                    "entrada": entrada, "llamadas": llamadas, "texto": texto_final}
        f.write(json.dumps(registro, ensure_ascii=False) + "\n")
    return {"messages": _con_mensaje(conv["ui"], texto_final)}
