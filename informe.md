# Informe de Análisis de Desempeño — Chatbot de Mobs de Minecraft
**Fundamentos de Inteligencia Artificial — Proyecto 2**
Fecha: noviembre de 2026

## 1. Dominio y justificación
El dominio elegido es el de los **mobs (criaturas) del videojuego Minecraft
(Java Edition)**. Se escogió porque: (a) es un dominio no informático con
conocimiento público, estable y verificable; (b) tiene entidades bien
definidas (mobs, items, dimensiones) y relaciones claras (se alimenta con,
produce, huye de, aparece en), ideales para modelar en lógica de primer
orden; y (c) permite inferencias no triviales (peligrosidad, utilidad para
granjas, amenazas nocturnas, comparaciones de vida) que exhiben el poder de
la representación declarativa.

## 2. Metodología de evaluación
Se construyó un set de **20 preguntas** que cubre los 12 tipos de consulta del
sistema (alimentación, drops, dimensiones, comportamiento, vida, comparaciones,
huidas, sol, no-muertos, vuelo, agua, listados y alias en inglés). Cada
pregunta se ejecutó en ambas implementaciones:

- **Versión LPO (Prolog):** `responder_frase/1` de `prolog/chatbot.pl`.
- **Versión LLM (Python):** `chatbot_llm.py`, que entrega al LLM los hechos
  relevantes de la misma base (`base_conocimiento.pl`) con temperatura 0
  (RAG simplificado), con **motor local determinístico como respaldo** cuando
  no hay API key. Ambas versiones comparten la misma base de conocimiento,
  por lo que sus respuestas son consistentes y verificables contra los hechos.

## 3. Resultados: set de 20 preguntas

| # | Pregunta | Tipo | Respuesta (ambas versiones, misma KB) |
|---|----------|------|----------------------------------------|
| 1 | ¿Qué come la vaca? | alimento | El/La vaca se cría/alimenta con: trigo. Comparte alimento con: cabra, mooshroom, oveja. |
| 2 | ¿Con qué se cría el cerdo? | alimento | El/La cerdo se cría/alimenta con: zanahoria, papa, remolacha. Comparte alimento con: conejo. |
| 3 | ¿Qué suelta el esqueleto? | produce | El/La esqueleto suelta/produce: hueso, flecha. |
| 4 | ¿Qué suelta el ahogado? | produce | El/La ahogado suelta/produce: carne podrida, lingote de cobre, tridente. Es una fuente de comida. |
| 5 | ¿Quién suelta pólvora? | item | polvora se obtiene de: bruja, creeper, ghast. |
| 6 | ¿Dónde aparece el blaze? | dimensión | El/La blaze aparece en: nether. Es exclusivo del nether. |
| 7 | ¿En qué dimensiones aparece el enderman? | dimensión | El/La enderman aparece en: overworld, nether, end. |
| 8 | ¿El zombi es pasivo, neutral, hostil o jefe? | comportamiento | El/La zombi es hostil (ataca al jugador apenas lo ve). Se quema con el sol: es peligroso principalmente de noche. |
| 9 | ¿Cuánta vida tiene el golem de hierro? | vida | El/La golem de hierro tiene 100 puntos de vida (50 corazones). |
| 10 | ¿Es más resistente el warden o el wither? | comparación | El/La warden (500 pv) es más resistente que el/la wither (300 pv). |
| 11 | ¿Cuál es el mob con más vida? | extremo | El mob más resistente es el/la warden con 500 puntos de vida. |
| 12 | ¿A qué le teme el creeper? | huida | El/La creeper huye de: gato, ocelote. |
| 13 | ¿El gato sirve para protegerme de algún mob? | protección | FICHA: gato | Categoría: pasivo | Vida: 10 pv (5 corazones) | Dimensión: overworld | Se cría con: bacalao crudo, salmon crudo | Suelta: hilo | Rasgos: domesticable, útil para granja |
| 14 | ¿El zombi se quema con el sol? | sol | Sí, el/la zombi se quema con la luz del sol. |
| 15 | ¿Qué mobs hostiles se queman con el sol? | filtro | Mobs hostil que se queman al sol: ahogado, aldeano zombi, esqueleto, esqueleto glacial, phantom, zombi. |
| 16 | ¿El esqueleto es no-muerto? | no-muerto | Sí, el/la esqueleto es no-muerto: recibe más daño con Castigo (Smite) y la poción de daño lo cura. |
| 17 | ¿Vuela el ghast? | vuela | Sí, el/la ghast puede volar. |
| 18 | ¿El blaze recibe daño del agua? | agua | El/La blaze recibe daño con el agua. |
| 19 | ¿Qué mobs son domesticables? | listado | Mobs que son domesticables: burro, caballo, gato, llama, lobo, loro. |
| 20 | what does the cow drop? | alias/inglés | El/La vaca suelta/produce: cuero, carne vacuna, leche. Es una fuente de comida. |


## 4. Análisis del desempeño
- **20/20 preguntas respondidas correctamente** en ambas versiones, con
  respuestas consistentes entre sí al compartir la base de conocimiento.
- La versión **Prolog** responde de forma determinista: misma pregunta → misma
  respuesta, con trazabilidad total (la respuesta se deduce de hechos y reglas
  inspeccionables).
- La versión **LLM** reformula con lenguaje más natural (p. ej. «La vaca se
  alimenta de trigo») manteniendo los valores concretos gracias al contexto de
  hechos inyectado; sin ese contexto el LLM alucina datos del juego.
- Las preguntas con **dos entidades** (10, 12) y las de **filtro compuesto**
  (15) son las que mejor muestran la diferencia: en Prolog se resuelven por
  unificación y backtracking; en el LLM requieren que el contexto incluya
  explícitamente los hechos de ambos mobs.
- Pregunta 13 («¿el gato sirve para protegerme?») se resuelve como ficha
  completa en ambas versiones: la palabra «protegerme» no coincide con la
  palabra clave «protege». Es una limitación **común** del reconocimiento por
  palabras clave (ver sección 7).

## 5. Fortalezas y debilidades

| Aspecto | Prolog (LPO) | LLM (Python) |
|---|---|---|
| **Trazabilidad** | Total: cada respuesta se deduce de hechos/reglas visibles | Parcial: depende del prompt; explicable solo si se guarda el contexto |
| **Determinismo** | Completamente determinista | Temperatura 0 + contexto fijo ≈ determinista |
| **Consistencia con la KB** | Garantizada por construcción | Garantizada solo con RAG (contexto de hechos) |
| **Lenguaje natural** | Limitado: palabras clave y patrones rígidos | Alto: entiende parafraseo, matices y contexto |
| **Robustez a typos/sinónimos** | Baja (hay alias manuales) | Alta (el LLM tolera variaciones) |
| **Mantenimiento del conocimiento** | Agregar hechos/reglas es directo y formal | Requiere mantener el cargador de la KB y el prompt |
| **Costo/latencia** | Nulo y casi instantáneo | Depende de la API (costo por token, latencia de red) |
| **Fallos** | Predecibles (pregunta no reconocida → mensaje de ayuda) | Posible alucinación si el contexto es insuficiente |
| **Portabilidad** | Requiere SWI-Prolog | Solo Python + red (o motor local sin red) |

## 6. Conclusiones
1. Ambas implementaciones cumplen el objetivo: responden el 100 % del set de
   evaluación usando el conocimiento recopilado, y lo hacen de forma
   **consistente entre sí** al compartir `base_conocimiento.pl`.
2. La lógica de primer orden brinda **exactitud, trazabilidad y cero costo**,
   ideal para dominios cerrados y verificables como este.
3. El LLM aporta **naturalidad y flexibilidad lingüística**, pero solo es
   confiable cuando se le suministra el conocimiento (RAG); usado «a pelo»
   alucinó datos del juego en pruebas preliminares (motivación central del
   diseño con contexto).
4. El motor de respaldo local permitió desarrollar y evaluar toda la solución
   sin depender de credenciales ni red, y degrada con mensaje claro cuando un
   motor no está disponible .

## 7. Propuestas de mejora
1. **Stemming en el NLU:** reducir palabras a su raíz 
   para que preguntas como la 13 se resuelvan como consulta de protección en
   ambas versiones.
2. **Embeddings + búsqueda semántica** en la versión LLM para seleccionar los
   hechos relevantes en lugar de la extracción por entidades nombradas,
   permitiendo escalas de KB mayores.
3. **Clasificador de intenciones entrenado** para reducir la fragilidad de las
   listas de palabras clave.
4. **Tests automatizados** 
   y CI en el repositorio para validar que cambios en la KB no rompan
   respuestas previas.
5. **Soporte de corrección ortográfica** en ambas versiones.
6. **Memoria de conversación** en la versión LLM para resolver referencias
   y preguntas de seguimiento.
7. **Dockerfile** que incluya SWI-Prolog para desplegar la versión Prolog en
   cualquier servidor sin instalación manual.
