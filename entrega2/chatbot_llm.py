# -*- coding: utf-8 -*-
"""
chatbot_llm.py - Chatbot de mobs de Minecraft usando un LLM (Punto 4).

Uso:
    python chatbot_llm.py                  # chat interactivo
    python chatbot_llm.py "¿qué come la vaca?"   # una sola pregunta

Requiere la variable de entorno OPENAI_API_KEY para el modo LLM.
Sin API key funciona en "modo local" (motor determinístico que usa la
misma base de conocimiento). En el informe se explica esta decisión.
"""
import os, re, json, urllib.request
from minecraft_kb import cargar_hechos, Motor, BASE_DIR

KB = cargar_hechos()
M = Motor(KB)

# ---------------------------------------------------------------------------
# 1. PROCESAMIENTO DE LENGUAJE NATURAL (normalizar + reconocer entidades)
# ---------------------------------------------------------------------------

TILDES = str.maketrans("áéíóúüñ", "aeiouun")
STOPWORDS = set("de del la el los las un una unos unas al a y lo le les se me en es con por".split())

ALIASES = {
    "zombie": "zombi", "skeleton": "esqueleto", "spider": "arana", "witch": "bruja",
    "husk": "zombi_momificado", "stray": "esqueleto_glacial", "drowned": "ahogado",
    "pillager": "saqueador", "vindicator": "vindicador", "evoker": "evocador",
    "ravager": "devastador", "silverfish": "pececillo", "golem": "golem_de_hierro",
    "dragon": "dragon_ender", "cow": "vaca", "pig": "cerdo", "sheep": "oveja",
    "chicken": "pollo", "wolf": "lobo", "bee": "abeja", "cat": "gato",
    "horse": "caballo", "villager": "aldeano", "magma": "cubo_de_magma",
}

def normalizar(texto):
    t = texto.lower().translate(TILDES)
    t = re.sub(r"[^a-z0-9ñ ]", " ", t)
    return [w for w in t.split() if w not in STOPWORDS]

def _partes(atomo):
    return [p for p in atomo.split("_") if p not in STOPWORDS]

def candidatos(tipo):
    out = []
    if tipo == "mob":
        for m in M.mobs:
            out.append((m, _partes(m)))
        for a, interno in ALIASES.items():
            out.append((interno, [a]))
    else:
        for it in M.items_conocidos():
            out.append((it, _partes(it)))
    return out

def _igual(p, w):
    return p == w or w == p + "s" or w == p + "es"

def entidades_en_frase(tipo, palabras):
    cands = candidatos(tipo)
    out, i = [], 0
    while i < len(palabras):
        mejor, mejor_n = None, 0
        for nombre, partes in cands:
            n = len(partes)
            if n > mejor_n and i + n <= len(palabras) and all(_igual(p, w) for p, w in zip(partes, palabras[i:i+n])):
                mejor, mejor_n = nombre, n
        if mejor:
            out.append(mejor); i += mejor_n
        else:
            i += 1
    return out

# ---------------------------------------------------------------------------
# 2. INTENCIONES (mismo orden de prioridad que el chatbot Prolog)
# ---------------------------------------------------------------------------

CLAVES = [
    ("compite",   ["compite", "compiten", "comparten", "comparte"]),
    ("huye",      ["teme", "temen", "huye", "huyen", "miedo", "asusta", "asustan",
                  "ahuyenta", "ahuyentar", "espanta", "espantar", "protege", "proteger"]),
    ("alimento",  ["come", "comen", "comer", "alimenta", "alimentan", "alimentar",
                  "alimento", "criar", "cria", "crian", "reproducir", "reproduce", "aparear"]),
    ("produce",   ["suelta", "sueltan", "soltar", "dropea", "drop", "drops", "produce",
                  "producen", "da", "dan", "obtener", "obtiene", "obtengo", "consigo",
                  "conseguir", "saca", "sacar"]),
    ("comparar",  ["comparar", "compara", "vs", "versus"]),
    ("vida",      ["vida", "corazones", "corazon", "resistente", "aguanta", "salud",
                  "fuerte", "debil"]),
    ("dimension", ["donde", "dimension", "aparece", "aparecen", "vive", "viven",
                  "encuentra", "encuentro", "spawnea"]),
    ("domestica", ["domesticar", "domesticable", "domestica", "mascota", "domar",
                  "montar", "montable", "domesticables"]),
    ("sol",       ["sol", "quema", "queman", "quemar"]),
    ("no_muerto", ["muerto", "undead", "castigo", "smite"]),
    ("vuela",     ["vuela", "vuelan", "volar", "volador"]),
    ("agua",      ["agua", "nada", "nadar", "acuatico"]),
    ("tipo",      ["peligroso", "peligrosa", "ataca", "atacan", "hostil", "pasivo",
                  "neutral", "agresivo", "tipo", "jefe"]),
    ("lista",     ["lista", "listar", "todos", "cuantos", "mobs", "hostiles",
                  "pasivos", "neutrales", "jefes"]),
]

def intencion(palabras):
    for intent, claves in CLAVES:
        if any(w in claves for w in palabras):
            return intent
    return "ficha"

# ---------------------------------------------------------------------------
# 3. GENERADORES DE RESPUESTA (equivalentes a las reglas r_* de Prolog)
# ---------------------------------------------------------------------------

def nombre(m): return m.replace("_", " ")

def lista_txt(items):
    return ", ".join(nombre(i) for i in items) if items else "ninguno"

def r_alimento(m):
    alim = M.alimentos(m)
    if not alim:
        return f"El/La {nombre(m)} no se puede criar con comida (no hay alimento registrado)."
    msg = f"El/La {nombre(m)} se cría/alimenta con: {lista_txt(alim)}."
    rivales = sorted({o for o in M.mobs if M.compite_alimento(m, o)})
    if rivales:
        msg += f" Comparte alimento con: {lista_txt(rivales)}."
    return msg

def r_produce(m):
    items = M.produce(m)
    if not items:
        return f"El/La {nombre(m)} no suelta items relevantes."
    msg = f"El/La {nombre(m)} suelta/produce: {lista_txt(items)}."
    if M.fuente_de_comida(m):
        msg += " Es una fuente de comida."
    return msg

DESC_CAT = {
    "pasivo": "nunca ataca al jugador",
    "neutral": "ataca solo si lo provocas",
    "hostil": "ataca al jugador apenas lo ve",
    "jefe": "enemigo de alto nivel, muy peligroso",
}

def r_comportamiento(m):
    c = M.categoria(m)
    msg = f"El/La {nombre(m)} es {c} ({DESC_CAT[c]})."
    if M.amenaza_nocturna(m):
        msg += " Se quema con el sol: es peligroso principalmente de noche."
    return msg

def r_vida(m):
    return f"El/La {nombre(m)} tiene {M.vida(m)} puntos de vida ({M.corazones(m):g} corazones)."

def r_dimension(m):
    dims = KB["dimension"][m]
    msg = f"El/La {nombre(m)} aparece en: {lista_txt(dims)}."
    if len(dims) == 1:
        msg += f" Es exclusivo del {dims[0]}."
    return msg

def r_domesticable(m):
    partes = []
    partes.append(f"Sí, el/la {nombre(m)} es domesticable." if m in KB["domesticable"]
                  else f"No, el/la {nombre(m)} no es domesticable.")
    if m in KB["montable"]:
        partes.append("Además se puede montar.")
    if M.mascota_protectora(m):
        partes.append(f"Sirve como protección: ahuyenta a {lista_txt(M.ahuyenta_a(m))}.")
    return " ".join(partes)

def r_huye(m):
    h, a = M.huye_de(m), M.ahuyenta_a(m)
    if not h and not a:
        return f"No tengo registrado que el/la {nombre(m)} huya de algo o ahuyente a otro mob."
    partes = []
    if h: partes.append(f"El/La {nombre(m)} huye de: {lista_txt(h)}.")
    if a: partes.append(f"El/La {nombre(m)} ahuyenta a: {lista_txt(a)}.")
    return " ".join(partes)

def r_huye_par(a, b):
    if (a, b) in KB["huye"]:
        return f"Sí, el/la {nombre(a)} huye del/de la {nombre(b)}."
    if (b, a) in KB["huye"]:
        return f"Al revés: el/la {nombre(b)} huye del/de la {nombre(a)}."
    return f"No hay relación de huida registrada entre {nombre(a)} y {nombre(b)}."

def r_sol(m):
    return (f"Sí, el/la {nombre(m)} se quema con la luz del sol." if m in KB["quema_sol"]
            else f"No, el/la {nombre(m)} no se quema con el sol.")

def r_no_muerto(m):
    if m in KB["no_muerto"]:
        return (f"Sí, el/la {nombre(m)} es no-muerto: recibe más daño con Castigo (Smite) "
                "y la poción de daño lo cura.")
    return f"No, el/la {nombre(m)} no es no-muerto."

def r_vuela(m):
    return (f"Sí, el/la {nombre(m)} puede volar." if m in KB["vuela"]
            else f"No, el/la {nombre(m)} no vuela.")

def r_agua(m):
    if m in KB["acuatico"]:
        return f"El/La {nombre(m)} es acuático, vive en el agua."
    if m in KB["danado_agua"]:
        return f"El/La {nombre(m)} recibe daño con el agua."
    return f"El/La {nombre(m)} no es acuático ni le afecta el agua."

def r_compite(a, b):
    comunes = sorted(set(M.alimentos(a)) & set(M.alimentos(b)))
    if comunes:
        return f"Sí, {nombre(a)} y {nombre(b)} comparten alimento: {lista_txt(comunes)}."
    return f"No, {nombre(a)} y {nombre(b)} no comparten alimento."

def r_comparar(a, b):
    va, vb = M.vida(a), M.vida(b)
    if M.mas_resistente(a, b):
        return f"El/La {nombre(a)} ({va} pv) es más resistente que el/la {nombre(b)} ({vb} pv)."
    if M.mas_resistente(b, a):
        return f"El/La {nombre(b)} ({vb} pv) es más resistente que el/la {nombre(a)} ({va} pv)."
    return f"{nombre(a)} y {nombre(b)} tienen la misma vida ({va} pv)."

def r_quien_suelta(item):
    fuentes = M.fuente_de(item)
    msg = (f"{nombre(item)} se obtiene de: {lista_txt(fuentes)}." if fuentes
           else f"Ningún mob suelta {nombre(item)}.")
    crias = sorted({a for a, b in KB["alimenta"] if b == item})
    if crias:
        msg += f" Además sirve para criar a: {lista_txt(crias)}."
    return msg

def r_categoria(c):
    ms = M.mobs_por_categoria(c)
    return f"Mobs {c} ({len(ms)}): {lista_txt(ms)}."

def r_todos():
    msg = f"Hay {len(M.mobs)} mobs registrados:"
    for c in ["pasivo", "neutral", "hostil", "jefe"]:
        msg += f" [{c}] {lista_txt(M.mobs_por_categoria(c))}."
    return msg

def r_extremo(modo):
    if modo == "mas":
        m = M.mob_mas_resistente()
        return f"El mob más resistente es el/la {nombre(m)} con {M.vida(m)} puntos de vida."
    debiles = M.mob_mas_debil()
    v = M.vida(debiles[0])
    return f"El mob con menos vida es: {lista_txt(debiles)} ({v} puntos de vida)."

def r_ficha(m):
    rasgos = []
    if m in KB["domesticable"]: rasgos.append("domesticable")
    if m in KB["montable"]: rasgos.append("montable")
    if m in KB["no_muerto"]: rasgos.append("no-muerto")
    if m in KB["quema_sol"]: rasgos.append("se quema al sol")
    if m in KB["vuela"]: rasgos.append("vuela")
    if m in KB["acuatico"]: rasgos.append("acuático")
    if m in KB["danado_agua"]: rasgos.append("dañado por agua")
    if m in KB["ataque_distancia"]: rasgos.append("ataca a distancia")
    if m in KB["explota"]: rasgos.append("explota")
    if m in KB["asalto"]: rasgos.append("participa en asaltos")
    if M.util_para_granja(m): rasgos.append("útil para granja")
    if M.amenaza_nocturna(m): rasgos.append("amenaza nocturna")
    c = M.categoria(m)
    return (f"FICHA: {nombre(m)} | Categoría: {c} | Vida: {M.vida(m)} pv "
            f"({M.corazones(m):g} corazones) | Dimensión: {lista_txt(KB['dimension'][m])} "
            f"| Se cría con: {lista_txt(M.alimentos(m))} | Suelta: {lista_txt(M.produce(m))} "
            f"| Rasgos: {lista_txt(rasgos)}")

CAT_EN = {"pasivo": ["pasivo", "pasivos"], "neutral": ["neutral", "neutrales"],
          "hostil": ["hostil", "hostiles", "peligrosos"], "jefe": ["jefe", "jefes"]}

def categoria_en(palabras):
    for c, claves in CAT_EN.items():
        if any(w in claves for w in palabras):
            return c
    return None

def listar_filtro(c, pertenece, desc):
    ms = sorted(m for m in M.mobs_por_categoria(c) if pertenece(m))
    return f"Mobs {c} que {desc}: {lista_txt(ms)}."

def filtrar_categoria(intent, c):
    filtros = {
        "sol":       (lambda m: m in KB["quema_sol"], "se queman al sol"),
        "vuela":     (lambda m: m in KB["vuela"], "vuelan"),
        "no_muerto": (lambda m: m in KB["no_muerto"], "son no-muertos"),
        "agua":      (lambda m: m in KB["acuatico"], "son acuáticos"),
        "domestica": (lambda m: m in KB["domesticable"], "son domesticables"),
    }
    if intent in filtros:
        f, desc = filtros[intent]
        return listar_filtro(c, f, desc)
    return r_categoria(c)


def listado_por_rasgo(intent):
    """Sin mob ni categoría: lista los mobs con el rasgo preguntado."""
    filtros = {
        "sol":       (KB["quema_sol"], "se queman con el sol"),
        "no_muerto": (KB["no_muerto"], "son no-muertos"),
        "vuela":     (KB["vuela"], "vuelan"),
        "agua":      (KB["acuatico"], "son acuáticos"),
        "domestica": (KB["domesticable"], "son domesticables"),
    }
    if intent not in filtros:
        return None
    conj, desc = filtros[intent]
    return f"Mobs que {desc}: {lista_txt(sorted(conj))}."

EJEMPLOS = ("No entendí la pregunta. Prueba con algo como: "
            "'¿Qué come la vaca?', '¿Qué suelta el esqueleto?', '¿Dónde aparece el blaze?', "
            "'¿A qué le teme el creeper?', '¿Quién suelta pólvora?', "
            "'¿Es más resistente el warden o el wither?', '¿Qué mobs hostiles se queman con el sol?'")

def responder_determinista(pregunta):
    """Motor de respaldo: replica la lógica del chatbot Prolog."""
    palabras = normalizar(pregunta)
    mobs = entidades_en_frase("mob", palabras)
    intent = intencion(palabras)
    if intent in ("compite", "huye", "comparar", "vida") and len(mobs) >= 2:
        a, b = mobs[0], mobs[1]
        return {"compite": r_compite, "huye": r_huye_par,
                "comparar": r_comparar, "vida": r_comparar}[intent](a, b)
    if mobs:
        m = mobs[0]
        dispatch = {
            "compite": r_alimento, "huye": r_huye, "alimento": r_alimento,
            "produce": r_produce, "vida": r_vida, "comparar": r_vida,
            "dimension": r_dimension, "domestica": r_domesticable, "sol": r_sol,
            "no_muerto": r_no_muerto, "vuela": r_vuela, "agua": r_agua,
            "tipo": r_comportamiento, "ficha": r_ficha, "lista": r_ficha,
        }
        return dispatch.get(intent, r_ficha)(m)
    # sin mob: item o generales
    if intent in ("produce", "alimento", "ficha"):
        items = entidades_en_frase("item", palabras)
        if items:
            return r_quien_suelta(items[0])
    if intent == "vida":
        return r_extremo("menos" if ("menos" in palabras or "debil" in palabras) else "mas")
    c = categoria_en(palabras)
    if c:
        return filtrar_categoria(intent, c)
    general = listado_por_rasgo(intent)
    if general:
        return general
    if any(w in ("lista", "todos", "cuantos", "mobs") for w in palabras):
        return r_todos()
    return EJEMPLOS

# ---------------------------------------------------------------------------
# 4. MODO LLM (API OpenAI-compatible) con la base de conocimiento como contexto
# ---------------------------------------------------------------------------

def contexto_kb(mobs=None, items=None, max_mobs=6):
    """Serializa los hechos relevantes de la KB para el prompt del LLM."""
    lineas = []
    for m in (mobs or [])[:max_mobs]:
        if m not in M.mobs:
            continue
        lineas.append(
            f"- {nombre(m)}: categoría={M.categoria(m)}, vida={M.vida(m)} pv "
            f"({M.corazones(m):g} corazones), dimensiones={lista_txt(KB['dimension'][m])}, "
            f"se cría con={lista_txt(M.alimentos(m))}, suelta={lista_txt(M.produce(m))}, "
            f"rasgos={lista_txt(rasgos_de(m))}")
    for it in (items or [])[:6]:
        lineas.append(f"- {nombre(it)}: lo sueltan {lista_txt(M.fuente_de(it))}, "
                      f"sirve para criar a {lista_txt(sorted({a for a,b in KB['alimenta'] if b==it}))}")
    return "\n".join(lineas)

def rasgos_de(m):
    r = []
    for conj, txt in [(KB["domesticable"], "domesticable"), (KB["montable"], "montable"),
                      (KB["no_muerto"], "no-muerto"), (KB["quema_sol"], "se quema al sol"),
                      (KB["vuela"], "vuela"), (KB["acuatico"], "acuático"),
                      (KB["danado_agua"], "dañado por agua"),
                      (KB["ataque_distancia"], "ataca a distancia"),
                      (KB["explota"], "explota"), (KB["asalto"], "participa en asaltos")]:
        if m in conj: r.append(txt)
    if M.util_para_granja(m): r.append("útil para granja")
    if M.amenaza_nocturna(m): r.append("amenaza nocturna")
    if m in M.mobs and not M.es_peligroso(m): r.append("inofensivo")
    if M.mascota_protectora(m): r.append(f"ahuyenta a {lista_txt(M.ahuyenta_a(m))}")
    return r

PROMPT_SISTEMA = """Eres un chatbot experto en los mobs de Minecraft (Java Edition).
Responde SOLO con la información entregada en los HECHOS. Si los hechos no
alcanzan, di que no lo sabes. Responde en español, de forma breve y directa
(1 o 2 oraciones), mencionando los valores concretos (vida, items, alimentos)."""

def responder_llm(pregunta):
    """Consulta al LLM usando la KB como contexto (RAG simplificado)."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return None  # sin key: usa el motor determinístico
    palabras = normalizar(pregunta)
    mobs = entidades_en_frase("mob", palabras)
    items = entidades_en_frase("item", palabras)
    ctx = contexto_kb(mobs, items)
    if not ctx:
        ctx = ("\n".join(f"- {nombre(m)}: categoría={M.categoria(m)}, vida={M.vida(m)}"
                for m in list(M.mobs)[:10]))
    body = json.dumps({
        "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
        "messages": [
            {"role": "system", "content": PROMPT_SISTEMA},
            {"role": "user", "content": f"HECHOS:\n{ctx}\n\nPREGUNTA: {pregunta}"},
        ],
        "temperature": 0.0,
    }).encode("utf-8")
    req = urllib.request.Request(
        os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1") + "/chat/completions",
        data=body, headers={"Content-Type": "application/json",
                            "Authorization": f"Bearer {api_key}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = json.loads(r.read().decode("utf-8"))
    return data["choices"][0]["message"]["content"].strip()

def responder(pregunta, modo="auto"):
    """modo: 'auto' (LLM si hay key, si no local) | 'llm' | 'local'"""
    if modo in ("auto", "llm"):
        try:
            r = responder_llm(pregunta)
            if r:
                return r
        except Exception as e:
            if modo == "llm":
                return f"[Error LLM: {e}]"
    return responder_determinista(pregunta)

# ---------------------------------------------------------------------------
# 5. CHAT INTERACTIVO POR CONSOLA
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        print(responder(" ".join(sys.argv[1:])))
        sys.exit(0)
    print("=" * 55)
    print("   Chatbot de Mobs de Minecraft - versión LLM (Python)")
    print("=" * 55)
    print("Escribe tu pregunta en lenguaje natural, o 'salir' para terminar.\n")
    while True:
        try:
            q = input("Tú: ").strip()
        except (EOFError, KeyboardInterrupt):
            break
        if not q or q.lower() in ("salir", "exit", "quit"):
            break
        print("->", responder(q))
    print("\n¡Hasta luego!")
