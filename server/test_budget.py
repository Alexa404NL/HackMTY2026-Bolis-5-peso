"""Tests unitarios del motor de presupuesto (budget.py).

Cubre: validación de campos, grafo completo, cálculos financieros y semáforo.
"""

import pytest
import budget


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _estado_completo(**overrides):
    base = {
        "ingreso_mensual": 20000,
        "gastos_fijos": 8000,
        "cat_vivienda": 500,
        "cat_alimentacion": 3000,
        "cat_transporte": 1500,
        "cat_entretenimiento": 1000,
        "cat_salud": 500,
        "cat_otros": 500,
    }
    base.update(overrides)
    return base


def _estado_vacio():
    return {c: None for c in budget.CAMPOS}


# ---------------------------------------------------------------------------
# Validación de campos
# ---------------------------------------------------------------------------

class TestValidar:
    def test_monto_valido(self):
        assert budget.validar("ingreso_mensual", "20,000") == 20000.0

    def test_monto_con_simbolo(self):
        assert budget.validar("cat_alimentacion", "$3000.50") == 3000.50

    def test_campo_inexistente(self):
        with pytest.raises(ValueError, match="no existe"):
            budget.validar("campo_falso", 100)

    def test_monto_negativo_invalido(self):
        with pytest.raises(ValueError, match="fuera del rango"):
            budget.validar("ingreso_mensual", -1)

    def test_cero_es_valido_para_categorias(self):
        assert budget.validar("cat_entretenimiento", 0) == 0.0


# ---------------------------------------------------------------------------
# Grafo de tarjetas
# ---------------------------------------------------------------------------

class TestGrafo:
    def test_primera_pregunta_en_estado_vacio(self):
        nodo = budget.get_next_question(_estado_vacio())
        assert nodo["campo"] == "ingreso_mensual"
        assert nodo["paso"] == 1
        assert nodo["total"] == len(budget.GRAFO)

    def test_segunda_pregunta_despues_de_ingreso(self):
        estado = {**_estado_vacio(), "ingreso_mensual": 20000}
        nodo = budget.get_next_question(estado)
        assert nodo["campo"] == "gastos_fijos"

    def test_completo_cuando_todos_llenos(self):
        assert budget.get_next_question(_estado_completo()) is None

    def test_estado_completo_true(self):
        assert budget.estado_completo(_estado_completo()) is True

    def test_estado_completo_false_con_ninguno(self):
        assert budget.estado_completo(_estado_vacio()) is False

    def test_aplicar_respuesta_normaliza(self):
        estado = _estado_vacio()
        nuevo = budget.aplicar_respuesta(estado, "ingreso_mensual", "$15,000")
        assert nuevo["ingreso_mensual"] == 15000.0

    def test_aplicar_respuesta_no_muta_original(self):
        estado = _estado_vacio()
        budget.aplicar_respuesta(estado, "ingreso_mensual", 10000)
        assert estado["ingreso_mensual"] is None


# ---------------------------------------------------------------------------
# simulate_budget — cálculos financieros
# ---------------------------------------------------------------------------

class TestSimulateBudget:
    def test_balance_positivo(self):
        plan = budget.simulate_budget(_estado_completo())
        total = 8000 + 500 + 3000 + 1500 + 1000 + 500 + 500
        assert plan["total_gastos"] == pytest.approx(total, abs=0.01)
        assert plan["balance_disponible"] == pytest.approx(20000 - total, abs=0.01)

    def test_semaforo_verde_gasto_bajo(self):
        # Gastos < 80% del ingreso → verde
        estado = _estado_completo(ingreso_mensual=20000, gastos_fijos=5000,
                                   cat_vivienda=0, cat_alimentacion=2000,
                                   cat_transporte=500, cat_entretenimiento=500,
                                   cat_salud=0, cat_otros=0)
        plan = budget.simulate_budget(estado)
        assert plan["status_color"] == "green"

    def test_semaforo_amarillo_gasto_medio(self):
        # Gastos entre 80%-100% → amarillo
        estado = _estado_completo(ingreso_mensual=10000, gastos_fijos=7000,
                                   cat_vivienda=500, cat_alimentacion=1000,
                                   cat_transporte=500, cat_entretenimiento=500,
                                   cat_salud=0, cat_otros=0)
        plan = budget.simulate_budget(estado)
        assert plan["status_color"] == "yellow"

    def test_semaforo_rojo_deficit(self):
        # Gastos > ingreso → rojo
        estado = _estado_completo(ingreso_mensual=5000, gastos_fijos=5000,
                                   cat_vivienda=500, cat_alimentacion=1000,
                                   cat_transporte=0, cat_entretenimiento=0,
                                   cat_salud=0, cat_otros=0)
        plan = budget.simulate_budget(estado)
        assert plan["status_color"] == "red"
        assert plan["balance_disponible"] < 0

    def test_margen_ahorro_sugerido_es_20_pct_cuando_alcanza(self):
        # balance suficiente para el 20%
        estado = _estado_completo(ingreso_mensual=20000, gastos_fijos=5000,
                                   cat_vivienda=0, cat_alimentacion=2000,
                                   cat_transporte=0, cat_entretenimiento=0,
                                   cat_salud=0, cat_otros=0)
        plan = budget.simulate_budget(estado)
        assert plan["margen_ahorro_sugerido"] == pytest.approx(4000, abs=1)

    def test_categorias_porcentaje_suma_razonable(self):
        plan = budget.simulate_budget(_estado_completo())
        total_pct = sum(c["porcentaje"] for c in plan["categorias"])
        # No suma 100% porque los fijos no están en las categorías variables
        assert total_pct <= 100.0

    def test_sin_ingreso_lanza_error(self):
        with pytest.raises(ValueError, match="ingreso_mensual"):
            budget.simulate_budget(_estado_vacio())
