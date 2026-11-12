# Chatbot de Mobs de Minecraft — Proyecto 2 (Fundamentos de IA)

Agente inteligente que responde preguntas sobre los mobs de Minecraft (Java
Edition) en **dos implementaciones** sobre el *mismo* conocimiento:

| Versión | Tecnología | Carpeta / archivo |
|---|---|---|
| Lógica de primer orden | SWI-Prolog | `prolog/chatbot.pl` (+ `base_conocimiento.pl`, `reglas.pl`) |
| LLM | Python + API OpenAI-compatible | `chatbot_llm.py` |
| Frontend web | FastAPI + HTML/JS | `app.py` + `static/index.html` |

## 1. Estructura del repositorio

```
minecraft_chatbot/
├── prolog/
│   ├── base_conocimiento.pl   # SOLO hechos (el conocimiento del dominio)
│   ├── reglas.pl              # reglas de inferencia (LPO)
│   └── chatbot.pl             # chatbot Prolog (consola + NLU)
├── minecraft_kb.py            # carga la MISMA base .pl y las reglas en Python
├── chatbot_llm.py             # chatbot LLM (CLI, con respaldo local)
├── app.py                     # servidor web (FastAPI) que une ambos motores
├── static/index.html          # interfaz de chat
├── informe.md                 # análisis de desempeño (20 preguntas)
└── README.md
```

## 2. Ejecución

### 2.1 Chatbot Prolog (consola)
```bash
cd prolog
swipl chatbot.pl
?- iniciar_chatbot.
```

### 2.2 Chatbot LLM (consola)
```bash
pip install -r requirements.txt
export OPENAI_API_KEY="sk-..."        # opcional: sin key usa el motor local
python chatbot_llm.py                 # chat interactivo
python chatbot_llm.py "¿qué come la vaca?"   # una pregunta suelta
```

### 2.3 Interfaz web (ambos motores)
```bash
pip install -r requirements.txt
python app.py          # o: uvicorn app:app --reload
# abrir http://localhost:8000
```
- Pestaña **Versión LLM**: usa la API del LLM si hay `OPENAI_API_KEY`;
  si no, responde con el motor local determinístico (misma base de conocimiento).
- Pestaña **Versión Prolog**: requiere `swipl` instalado en el sistema.

## 3. Versionamiento en Git (punto 6)

```bash
git init
git add .
git commit -m "Chatbot de mobs de Minecraft: versiones Prolog (LPO) y LLM + web"
git branch -M main
git remote add origin <URL-del-repositorio-del-grupo>
git push -u origin main
```

## 4. Cómo agregar conocimiento
Solo se edita `prolog/base_conocimiento.pl` (hechos: `mob/3`, `alimenta_con/2`,
`produce/2`, rasgos, `huye_de/2`, ...). La versión Python **lee ese mismo
archivo** (`minecraft_kb.py`), por lo que ambos chatbots se actualizan juntos.
Si el nuevo conocimiento requiere deducción, se agrega la regla en
`prolog/reglas.pl` y su equivalente en `minecraft_kb.py` (clase `Motor`).
