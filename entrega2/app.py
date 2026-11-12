# -*- coding: utf-8 -*-
"""
app.py - Servidor web del chatbot de mobs de Minecraft (Punto 5).

Frontend:  http://localhost:8000  (interfaz de chat en static/index.html)
API:       POST /api/chat  {"pregunta": "...", "motor": "prolog" | "llm"}

Ejecutar:  uvicorn app:app --reload        (o: python app.py)
Requisitos: Python 3.10+, fastapi, uvicorn.
            Para el motor "prolog": SWI-Prolog instalado (swipl en el PATH).
            Para el motor "llm":   variable de entorno OPENAI_API_KEY
            (sin key, el motor LLM usa el motor local determinístico).
"""
import json, shutil, subprocess
from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import chatbot_llm

BASE_DIR = Path(__file__).parent
PROLOG_CHATBOT = BASE_DIR / "prolog" / "chatbot.pl"

app = FastAPI(title="Chatbot Mobs Minecraft")
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")


class Consulta(BaseModel):
    pregunta: str
    motor: str = "llm"          # "prolog" | "llm"


# --- Motor Prolog: invoca a SWI-Prolog por cada pregunta -------------------
def consultar_prolog(pregunta: str) -> str:
    swipl = shutil.which("swipl")
    if not swipl:
        return ("El motor Prolog no está disponible en este servidor "
                "(no se encontró 'swipl'). Instala SWI-Prolog o usa el motor LLM.")
    # escapar comillas simples para el átomo Prolog
    q = pregunta.replace("\\", "\\\\").replace("'", "\\'")
    goal = f"responder_frase('{q}'),flush_output,halt"
    try:
        r = subprocess.run(
            [swipl, "-q", "-s", str(PROLOG_CHATBOT), "-g", goal, "-t", "halt"],
            capture_output=True, timeout=30)
        salida = r.stdout.decode("utf-8", errors="replace")
        # la respuesta viene tras el marcador "-> "
        if "->" in salida:
            salida = salida.split("->", 1)[1]
        salida = salida.strip()
        if salida:
            return salida
        err = r.stderr.decode("utf-8", errors="replace").strip()
        return f"El motor Prolog no produjo respuesta. {err[:200]}"
    except subprocess.TimeoutExpired:
        return "El motor Prolog agotó el tiempo de respuesta."
    except Exception as e:                       # noqa: BLE001
        return f"Error al ejecutar Prolog: {e}"


@app.post("/api/chat")
def chat(consulta: Consulta):
    pregunta = consulta.pregunta.strip()
    if not pregunta:
        return {"respuesta": "Escribe una pregunta primero."}
    if consulta.motor == "prolog":
        respuesta = consultar_prolog(pregunta)
    else:
        respuesta = chatbot_llm.responder(pregunta, modo="auto")
    return {"respuesta": respuesta}


@app.get("/")
def home():
    return FileResponse(BASE_DIR / "static" / "index.html")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
