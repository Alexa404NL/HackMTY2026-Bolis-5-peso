import json

import pytest
from mcp import Client

import mcp_server

ESTADO = dict(objetivo="Viaje", monto_meta=50000, plazo_meses=24, aportacion_inicial=5000,
              aportacion_periodica=3000, incluye_rendimiento_estimado=True, perfil_riesgo="moderado")


@pytest.fixture(autouse=True)
def db_temporal(tmp_path, monkeypatch):
    monkeypatch.setattr(mcp_server, "DB", tmp_path / "goals.db")


def partes(res):
    datos = json.loads(next(c.text for c in res.content if c.type == "text"))
    ui = next((json.loads(c.resource.text) for c in res.content if c.type == "resource"), None)
    return datos, ui


def componentes(ui):
    return {c["id"]: c for m in ui if "updateComponents" in m for c in m["updateComponents"]["components"]}


def test_guardar_persiste_y_editar_despues_actualiza_la_misma_fila():
    datos, ui = partes(mcp_server.save_savings_goal(ESTADO))
    gid = datos["goal_id"]
    assert mcp_server.db_leer(gid)["estado"] == ESTADO
    assert componentes(ui)["resumen"]["goal_id"] == gid

    _, ui = partes(mcp_server.update_savings_goal(ESTADO, [{"campo": "aportacion_periodica", "valor": "4000"}], gid))
    assert mcp_server.db_leer(gid)["estado"]["aportacion_periodica"] == 4000
    assert componentes(ui)["proyeccion"]["component"] == "ProyeccionAhorroMulti"


def test_editar_sin_guardar_recalcula_cambia_variante_y_no_persiste():
    _, ui = partes(mcp_server.update_savings_goal(ESTADO, [{"campo": "plazo_meses", "valor": 12}]))
    comps = componentes(ui)
    assert comps["proyeccion"]["component"] == "ProyeccionAhorroSimple"
    assert "resumen" not in comps
    assert mcp_server.db_leer(1) is None


def test_respuesta_invalida_regresa_la_misma_tarjeta_con_error():
    datos, ui = partes(mcp_server.get_next_question({}, [{"campo": "objetivo", "valor": "Viaje"},
                                                          {"campo": "monto_meta", "valor": "-5"}]))
    tarjeta = componentes(ui)["tarjeta"]
    assert tarjeta["campo"] == "monto_meta" and tarjeta["error"]
    assert datos["estado"]["objetivo"] == "Viaje"
    assert tarjeta["action"]["event"]["name"] == "responder"


def test_ultima_respuesta_regresa_la_proyeccion_en_el_mismo_turno():
    incompleto = {**ESTADO, "perfil_riesgo": None}
    datos, ui = partes(mcp_server.get_next_question(incompleto, [{"campo": "perfil_riesgo", "valor": "moderado"}]))
    comps = componentes(ui)
    assert datos["completo"] is True
    assert "tarjeta" not in comps and comps["proyeccion"]["component"] == "ProyeccionAhorroMulti"
    assert ui[1]["updateDataModel"]["value"]["estado"]["perfil_riesgo"] == "moderado"


@pytest.mark.anyio
async def test_contrato_mcp_anotaciones_y_templates():
    async with Client(mcp_server.mcp) as c:
        tools = {t.name: t.annotations for t in (await c.list_tools()).tools}
        assert tools["get_next_question"].read_only_hint is True
        assert tools["simulate_projection"].read_only_hint is True
        assert tools["update_savings_goal"].read_only_hint is False
        assert tools["save_savings_goal"].read_only_hint is False
        assert tools["save_savings_goal"].idempotent_hint is False
        recursos = (await c.list_resources()).resources
        assert len(recursos) == 4
        assert {r.mime_type for r in recursos} == {"application/a2ui+json"}
