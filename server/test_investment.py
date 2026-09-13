"""Tests unitarios del motor de inversión (investment.py).

Cubre: validación de campos, grafo completo, proyecciones y portafolios.
"""

import pytest
import investment


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _estado_completo(**overrides):
    base = {
        "monto_inversion": 10000,
        "aportacion_mensual": 2000,
        "plazo_meses": 24,
        "perfil_riesgo": "moderado",
    }
    base.update(overrides)
    return base


def _estado_vacio():
    return {c: None for c in investment.CAMPOS}


# ---------------------------------------------------------------------------
# Validación de campos
# ---------------------------------------------------------------------------

class TestValidar:
    def test_monto_valido(self):
        assert investment.validar("monto_inversion", "10,000") == 10000.0

    def test_monto_minimo(self):
        with pytest.raises(ValueError, match="fuera de rango"):
            investment.validar("monto_inversion", 499)

    def test_aportacion_cero_valido(self):
        assert investment.validar("aportacion_mensual", 0) == 0.0

    def test_plazo_valido_entero(self):
        assert investment.validar("plazo_meses", 12) == 12

    def test_plazo_invalido_no_entero(self):
        with pytest.raises(ValueError):
            investment.validar("plazo_meses", 12.5)

    def test_perfil_valido(self):
        assert investment.validar("perfil_riesgo", "agresivo") == "agresivo"

    def test_perfil_invalido(self):
        with pytest.raises(ValueError, match="no existe"):
            investment.validar("perfil_riesgo", "ultra_agresivo")

    def test_campo_inexistente(self):
        with pytest.raises(ValueError, match="no existe"):
            investment.validar("campo_falso", 100)


# ---------------------------------------------------------------------------
# Grafo de tarjetas
# ---------------------------------------------------------------------------

class TestGrafo:
    def test_primera_pregunta_en_estado_vacio(self):
        nodo = investment.get_next_question(_estado_vacio())
        assert nodo["campo"] == "monto_inversion"
        assert nodo["paso"] == 1

    def test_orden_de_preguntas(self):
        campos_esperados = ["monto_inversion", "aportacion_mensual", "plazo_meses", "perfil_riesgo"]
        estado = _estado_vacio()
        for campo_esperado in campos_esperados:
            nodo = investment.get_next_question(estado)
            assert nodo["campo"] == campo_esperado
            estado = investment.aplicar_respuesta(estado, campo_esperado, _estado_completo()[campo_esperado])

    def test_completo_cuando_todos_llenos(self):
        assert investment.get_next_question(_estado_completo()) is None

    def test_estado_completo_true(self):
        assert investment.estado_completo(_estado_completo()) is True

    def test_estado_completo_false_parcial(self):
        estado = {**_estado_vacio(), "monto_inversion": 10000}
        assert investment.estado_completo(estado) is False

    def test_aplicar_respuesta_no_muta(self):
        estado = _estado_vacio()
        investment.aplicar_respuesta(estado, "monto_inversion", 5000)
        assert estado["monto_inversion"] is None


# ---------------------------------------------------------------------------
# simulate_investment — proyecciones
# ---------------------------------------------------------------------------

class TestSimulateInvestment:
    def test_monto_final_mayor_que_capital(self):
        plan = investment.simulate_investment(_estado_completo())
        assert plan["monto_final_proyectado"] > plan["capital_aportado_total"]

    def test_capital_aportado_correcto(self):
        estado = _estado_completo(monto_inversion=10000, aportacion_mensual=2000, plazo_meses=12)
        plan = investment.simulate_investment(estado)
        assert plan["capital_aportado_total"] == pytest.approx(10000 + 2000 * 12, abs=0.01)

    def test_serie_longitud_correcta(self):
        estado = _estado_completo(plazo_meses=24)
        plan = investment.simulate_investment(estado)
        # serie incluye el mes 0, por eso es plazo + 1
        assert len(plan["serie_mensual"]) == 25

    def test_rendimiento_agresivo_mayor_que_conservador(self):
        base = {"monto_inversion": 10000, "aportacion_mensual": 1000, "plazo_meses": 36}
        plan_agresivo = investment.simulate_investment({**base, "perfil_riesgo": "agresivo"})
        plan_conservador = investment.simulate_investment({**base, "perfil_riesgo": "conservador"})
        assert plan_agresivo["monto_final_proyectado"] > plan_conservador["monto_final_proyectado"]

    def test_portafolio_conservador_tiene_70_pct_cetes(self):
        plan = investment.simulate_investment(_estado_completo(perfil_riesgo="conservador"))
        cetes = next(i for i in plan["instrumentos"] if "CETES" in i["nombre"])
        assert cetes["porcentaje"] == 70.0

    def test_portafolio_agresivo_tiene_50_pct_renta_variable(self):
        plan = investment.simulate_investment(_estado_completo(perfil_riesgo="agresivo"))
        rv = next(i for i in plan["instrumentos"] if "Renta Variable" in i["nombre"])
        assert rv["porcentaje"] == 50.0

    def test_sin_aportacion_mensual_crece_solo_por_rendimiento(self):
        estado = _estado_completo(aportacion_mensual=0, plazo_meses=12, perfil_riesgo="moderado")
        plan = investment.simulate_investment(estado)
        assert plan["monto_final_proyectado"] > plan["monto_inversion"]

    def test_estado_incompleto_lanza_error(self):
        with pytest.raises(ValueError, match="no está completo"):
            investment.simulate_investment(_estado_vacio())
