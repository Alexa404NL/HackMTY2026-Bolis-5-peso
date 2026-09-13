import pytest

from cards import GRAFO, aplicar_respuesta, estado_completo, get_next_question, simulate_projection, validar


def responder(**respuestas):
    estado = {}
    for campo, valor in respuestas.items():
        estado = aplicar_respuesta(estado, campo, valor)
    return estado


BASE = dict(objetivo="Viaje", monto_meta=50000, plazo_meses=12, aportacion_inicial=5000, aportacion_periodica=3000)


def test_primera_tarjeta_es_objetivo():
    t = get_next_question({})
    assert t["campo"] == "objetivo" and t["paso"] == 1 and t["total"] == 7


def test_rama_sin_rendimiento_salta_perfil():
    e = responder(**BASE, incluye_rendimiento_estimado=False)
    assert get_next_question(e) is None
    assert estado_completo(e)
    assert e["perfil_riesgo"] is None


def test_rama_con_rendimiento_pregunta_perfil():
    e = responder(**BASE, incluye_rendimiento_estimado=True)
    t = get_next_question(e)
    assert t["campo"] == "perfil_riesgo" and t["paso"] == 7 and t["total"] == 7
    assert not estado_completo(e)
    assert estado_completo(aplicar_respuesta(e, "perfil_riesgo", "moderado"))


def test_cambiar_a_sin_rendimiento_borra_perfil():
    e = responder(**BASE, incluye_rendimiento_estimado=True, perfil_riesgo="agresivo")
    e = aplicar_respuesta(e, "incluye_rendimiento_estimado", "no")
    assert e["perfil_riesgo"] is None and estado_completo(e)


@pytest.mark.parametrize("campo", [n["campo"] for n in GRAFO])
def test_incompleto_si_falta_cualquier_campo_requerido(campo):
    e = responder(**BASE, incluye_rendimiento_estimado=True, perfil_riesgo="moderado")
    e[campo] = None
    assert not estado_completo(e)


@pytest.mark.parametrize(
    "campo,valor",
    [("monto_meta", 0), ("monto_meta", "abc"), ("plazo_meses", 2), ("plazo_meses", 12.5),
     ("aportacion_inicial", -1), ("perfil_riesgo", "yolo"), ("incluye_rendimiento_estimado", "tal vez"),
     ("objetivo", "  "), ("inventado", 1)],
)
def test_validacion_rechaza(campo, valor):
    with pytest.raises(ValueError):
        validar(campo, valor)


def test_validacion_normaliza():
    assert validar("monto_meta", "$50,000") == 50000
    assert validar("plazo_meses", "24") == 24
    assert validar("incluye_rendimiento_estimado", "Sí") is True


def test_proyeccion_sin_rendimiento_es_lineal_y_simple():
    p = simulate_projection(responder(**BASE, incluye_rendimiento_estimado=False))
    assert p["variante"] == "simple" and len(p["escenarios"]) == 1
    esc = p["escenarios"][0]
    assert esc["saldo_final"] == 5000 + 3000 * 12 == p["aportado_total"]
    assert len(esc["serie"]) == 13
    assert esc["mes_meta"] is None  # 41k < 50k


def test_proyeccion_interes_compuesto_mensual():
    e = responder(objetivo="x", monto_meta=1, plazo_meses=12, aportacion_inicial=1000,
                  aportacion_periodica=0, incluye_rendimiento_estimado=True, perfil_riesgo="moderado")
    p = simulate_projection(e)
    assert p["variante"] == "simple"
    assert p["escenarios"][0]["saldo_final"] == round(1000 * (1 + 0.09 / 12) ** 12, 2)


def test_multi_escenario_con_rendimiento_y_plazo_largo():
    e = responder(**{**BASE, "plazo_meses": 24}, incluye_rendimiento_estimado=True, perfil_riesgo="agresivo")
    p = simulate_projection(e)
    assert p["variante"] == "multi"
    assert [x["perfil"] for x in p["escenarios"]] == ["conservador", "moderado", "agresivo"]
    assert p["perfil_elegido"] == "agresivo"


def test_plazo_largo_sin_rendimiento_sigue_simple():
    e = responder(**{**BASE, "plazo_meses": 60}, incluye_rendimiento_estimado=False)
    assert simulate_projection(e)["variante"] == "simple"


def test_proyeccion_rechaza_estado_incompleto():
    with pytest.raises(ValueError):
        simulate_projection(responder(objetivo="Viaje"))
