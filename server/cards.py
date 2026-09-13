"""Motor de tarjetas: grafo determinista de perfilamiento + proyección. Sin LLM."""

CAMPOS = [
    "objetivo",
    "monto_meta",
    "plazo_meses",
    "aportacion_inicial",
    "aportacion_periodica",
    "incluye_rendimiento_estimado",
    "perfil_riesgo",
]

TASAS = {"conservador": 0.07, "moderado": 0.09, "agresivo": 0.11}

GRAFO = [
    {
        "id": "objetivo",
        "pregunta": "¿Para qué quieres ahorrar?",
        "tipo_respuesta": "opciones",
        "opciones": ["Fondo de emergencia", "Viaje", "Enganche", "Educación", "Otro"],
        "campo": "objetivo",
        "condicion": None,
    },
    {
        "id": "monto_meta",
        "pregunta": "¿Cuánto quieres juntar?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "monto_meta",
        "condicion": None,
    },
    {
        "id": "plazo_meses",
        "pregunta": "¿En cuánto tiempo?",
        "tipo_respuesta": "opciones",
        "opciones": [6, 12, 24, 36, 60],
        "campo": "plazo_meses",
        "condicion": None,
    },
    {
        "id": "aportacion_inicial",
        "pregunta": "¿Con cuánto empiezas hoy?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "aportacion_inicial",
        "condicion": None,
    },
    {
        "id": "aportacion_periodica",
        "pregunta": "¿Cuánto puedes ahorrar cada mes?",
        "tipo_respuesta": "monto",
        "opciones": None,
        "campo": "aportacion_periodica",
        "condicion": None,
    },
    {
        "id": "incluye_rendimiento_estimado",
        "pregunta": "¿Quieres ver un rendimiento estimado por invertir tu ahorro?",
        "tipo_respuesta": "si_no",
        "opciones": [True, False],
        "campo": "incluye_rendimiento_estimado",
        "condicion": None,
    },
    {
        "id": "perfil_riesgo",
        "pregunta": "¿Qué tanto riesgo estás dispuesto a tomar?",
        "tipo_respuesta": "opciones",
        "opciones": ["conservador", "moderado", "agresivo"],
        "campo": "perfil_riesgo",
        "condicion": {"campo": "incluye_rendimiento_estimado", "igual": True},
    },
]


def _numero(valor, minimo, maximo, entero=False):
    try:
        n = float(str(valor).replace(",", "").replace("$", "").strip())
    except ValueError:
        raise ValueError(f"'{valor}' no es un número")
    if not (minimo <= n <= maximo):
        raise ValueError(f"{n:g} fuera de rango [{minimo:g}, {maximo:g}]")
    if entero:
        if n != int(n):
            raise ValueError(f"{n:g} debe ser entero")
        return int(n)
    return n


def validar(campo, valor):
    """Regresa el valor normalizado o lanza ValueError."""
    if campo == "objetivo":
        texto = str(valor).strip()
        if not 0 < len(texto) <= 80:
            raise ValueError("objetivo vacío o demasiado largo")
        return texto
    if campo == "monto_meta":
        return _numero(valor, 1, 100_000_000)
    if campo == "plazo_meses":
        return _numero(valor, 3, 120, entero=True)
    if campo == "aportacion_inicial":
        return _numero(valor, 0, 100_000_000)
    if campo == "aportacion_periodica":
        return _numero(valor, 0, 10_000_000)
    if campo == "incluye_rendimiento_estimado":
        if isinstance(valor, bool):
            return valor
        texto = str(valor).strip().lower()
        if texto in ("si", "sí", "true"):
            return True
        if texto in ("no", "false"):
            return False
        raise ValueError(f"'{valor}' no es sí/no")
    if campo == "perfil_riesgo":
        texto = str(valor).strip().lower()
        if texto not in TASAS:
            raise ValueError(f"perfil '{valor}' no existe")
        return texto
    raise ValueError(f"campo '{campo}' no existe")


def _visible(nodo, estado):
    cond = nodo["condicion"]
    if cond is None or estado.get(cond["campo"]) is None:
        return True  # dependencia aún sin responder: cuenta como pendiente
    return estado[cond["campo"]] == cond["igual"]


def aplicar_respuesta(estado, campo, valor):
    nuevo = {c: estado.get(c) for c in CAMPOS}
    nuevo[campo] = validar(campo, valor)
    if campo == "incluye_rendimiento_estimado" and not nuevo[campo]:
        nuevo["perfil_riesgo"] = None
    return nuevo


def get_next_question(estado):
    visibles = [n for n in GRAFO if _visible(n, estado)]
    for i, nodo in enumerate(visibles):
        if estado.get(nodo["campo"]) is None:
            return {**nodo, "paso": i + 1, "total": len(visibles)}
    return None


def estado_completo(estado):
    return all(estado.get(n["campo"]) is not None for n in GRAFO if _visible(n, estado))


def _serie(estado, tasa_anual):
    r = tasa_anual / 12
    saldo = estado["aportacion_inicial"]
    serie, mes_meta = [round(saldo, 2)], None
    for mes in range(1, estado["plazo_meses"] + 1):
        saldo = saldo * (1 + r) + estado["aportacion_periodica"]
        serie.append(round(saldo, 2))
        if mes_meta is None and saldo >= estado["monto_meta"]:
            mes_meta = mes
    if estado["aportacion_inicial"] >= estado["monto_meta"]:
        mes_meta = 0
    return {"tasa": tasa_anual, "serie": serie, "saldo_final": serie[-1], "mes_meta": mes_meta}


def simulate_projection(estado):
    if not estado_completo(estado):
        raise ValueError("el perfilamiento no está completo")
    con_rendimiento = estado["incluye_rendimiento_estimado"]
    perfil = estado.get("perfil_riesgo")
    if con_rendimiento and estado["plazo_meses"] >= 24:
        variante = "multi"
        escenarios = [{"perfil": p, **_serie(estado, t)} for p, t in TASAS.items()]
    else:
        variante = "simple"
        tasa = TASAS[perfil] if con_rendimiento else 0.0
        escenarios = [{"perfil": perfil or "sin_rendimiento", **_serie(estado, tasa)}]
    return {
        "variante": variante,
        "monto_meta": estado["monto_meta"],
        "plazo_meses": estado["plazo_meses"],
        "aportado_total": estado["aportacion_inicial"] + estado["aportacion_periodica"] * estado["plazo_meses"],
        "perfil_elegido": perfil,
        "escenarios": escenarios,
    }
