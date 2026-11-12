# -*- coding: utf-8 -*-
"""
minecraft_kb.py - Cargador de la base de conocimiento de mobs de Minecraft.

Lee los HECHOS directamente desde 'base_conocimiento.pl' (la misma base que
usa el chatbot en Prolog) y replica en Python las reglas de inferencia de
'reglas.pl', para que ambas versiones del chatbot compartan el MISMO
conocimiento y produzcan respuestas consistentes.
"""
import re
from pathlib import Path

BASE_DIR = Path(__file__).parent
PROLOG_DIR = BASE_DIR / "prolog"

# ---------------------------------------------------------------------------
# 1. CARGA DE HECHOS DESDE EL ARCHIVO PROLOG
# ---------------------------------------------------------------------------

def _atom(s: str) -> str:
    return s.strip().strip("'").rstrip('.,').strip()

def cargar_hechos(ruta=None) -> dict:
    ruta = Path(ruta) if ruta else PROLOG_DIR / "base_conocimiento.pl"
    texto = ruta.read_text(encoding="utf-8")

    def hechos(pred, aridad):
        """Extrae hechos pred(a, b, ...) ignorando reglas (:-) y comentarios (%)."""
        pat = re.compile(rf"\b{pred}\(([^()]*)\)")
        out = []
        for linea in texto.splitlines():
            linea = linea.split("%")[0]          # quitar comentarios
            if ":-" in linea:                     # saltar reglas
                continue
            for m in pat.finditer(linea):         # varios hechos por línea
                args = [_atom(a) for a in m.group(1).split(",")]
                if len(args) == aridad:
                    out.append(tuple(args))
        return out

    # lista de 'solo_otra_dimension' definida con member/2 dentro de la regla
    m = re.search(r"member\(X, \[([^\]]*)\]\)", texto)
    solo_otra = [_atom(x) for x in m.group(1).split(",")] if m else []

    kb = {

        "mobs":      hechos("mob", 3),                 # (nombre, categoria, vida)
        "dimension_facts": hechos("dimension", 2),     # hechos explicitos
        "alimenta":  hechos("alimenta_con", 2),
        "produce":   hechos("produce", 2),
        "comestible": {a[0] for a in hechos("es_comestible", 1)},
        "domesticable": {a[0] for a in hechos("es_domesticable", 1)},
        "montable": {a[0] for a in hechos("es_montable", 1)},
        "no_muerto": {a[0] for a in hechos("es_no_muerto", 1)},
        "quema_sol": {a[0] for a in hechos("se_quema_al_sol", 1)},
        "vuela": {a[0] for a in hechos("vuela", 1)},
        "acuatico": {a[0] for a in hechos("es_acuatico", 1)},
        "danado_agua": {a[0] for a in hechos("danado_por_agua", 1)},
        "ataque_distancia": {a[0] for a in hechos("ataca_a_distancia", 1)},
        "explota": {a[0] for a in hechos("explota", 1)},
        "asalto": {a[0] for a in hechos("participa_en_asalto", 1)},
        "huye": hechos("huye_de", 2),
    }
    nombres = [m[0] for m in kb["mobs"]]
    dims = {}
    for n in nombres:
        d = [] if n in solo_otra else ["overworld"]
        d += [b for a, b in kb["dimension_facts"] if a == n]
        dims[n] = d
    kb["dimension"] = dims
    return kb

# ---------------------------------------------------------------------------
# 2. REGLAS DE INFERENCIA (equivalentes a reglas.pl)
# ---------------------------------------------------------------------------

class Motor:
    def __init__(self, kb):
        self.kb = kb
        self.mobs = {m[0]: {"cat": m[1], "vida": int(m[2])} for m in kb["mobs"]}

    # --- comportamiento ---
    def categoria(self, x): return self.mobs[x]["cat"]
    def es_pasivo(self, x):  return self.categoria(x) == "pasivo"
    def es_neutral(self, x): return self.categoria(x) == "neutral"
    def es_hostil(self, x):  return self.categoria(x) == "hostil"
    def es_jefe(self, x):    return self.categoria(x) == "jefe"
    def es_peligroso(self, x): return self.es_hostil(x) or self.es_jefe(x)
    def es_inofensivo(self, x): return x in self.mobs and not self.es_peligroso(x)

    # --- crianza / granjas ---
    def se_puede_criar(self, x): return x in self.mobs and any(a == x for a, _ in self.kb["alimenta"])
    def alimentos(self, x): return [b for a, b in self.kb["alimenta"] if a == x]
    def compite_alimento(self, x, y):
        return x != y and set(self.alimentos(x)) & set(self.alimentos(y))
    def produce(self, x): return [b for a, b in self.kb["produce"] if a == x]
    def util_para_granja(self, x): return self.se_puede_criar(x) and bool(self.produce(x))
    def fuente_de_comida(self, x):
        return x in self.mobs and any(i in self.kb["comestible"] for i in self.produce(x))
    def fuente_de(self, item): return sorted({a for a, b in self.kb["produce"] if b == item})

    # --- combate ---
    def vulnerable_a_castigo(self, x): return x in self.kb["no_muerto"]
    def se_cura_con_veneno(self, x):  return x in self.kb["no_muerto"]
    def amenaza_nocturna(self, x):    return self.es_peligroso(x) and x in self.kb["quema_sol"]
    def protector_contra(self, p, m): return (m, p) in self.kb["huye"]
    def mascota_protectora(self, p):
        return p in self.kb["domesticable"] and any(self.protector_contra(p, m) and self.es_peligroso(m)
                                                    for m, _ in self.kb["huye"])
    def huye_de(self, x): return [b for a, b in self.kb["huye"] if a == x]
    def ahuyenta_a(self, x): return [a for a, b in self.kb["huye"] if b == x]

    # --- vida / comparaciones ---
    def vida(self, x): return self.mobs[x]["vida"]
    def corazones(self, x): return self.vida(x) / 2
    def mas_resistente(self, x, y): return self.vida(x) > self.vida(y)
    def mob_mas_resistente(self):
        return max(self.mobs, key=lambda m: self.vida(m))
    def mob_mas_debil(self):
        v = min(self.vida(m) for m in self.mobs)
        return sorted(m for m in self.mobs if self.vida(m) == v)
    def exclusivo_de(self, x):
        d = self.kb["dimension"][x]
        return d[0] if len(d) == 1 else None

    # --- listados ---
    def mobs_por_categoria(self, c): return sorted(m for m in self.mobs if self.categoria(m) == c)
    def items_conocidos(self):
        return sorted({b for _, b in self.kb["produce"]} | {b for _, b in self.kb["alimenta"]})
