import os, httpx, time
from fastapi import FastAPI, Request
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
from circuitbreaker import circuit

BOT_TOKEN = os.environ["BOT_TOKEN"]
API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}"
TOXICITY_URL = os.environ.get("TOXICITY_URL","http://toxicity-svc:8080/analyze")
MOD_CHAT_ID = os.environ["MOD_CHAT_ID"]
ALERT_IF_TOXIC = float(os.environ.get("TOX_THRESHOLD","0.5"))
TIMEOUT = float(os.environ.get("TIMEOUT", "5.0"))

app = FastAPI(title="telegram-bot-svc")
client = httpx.AsyncClient(timeout=TIMEOUT)

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
TOXICITY_CALL_DURATION = Histogram('toxicity_call_duration_seconds', 'Toxicity service call duration')
TOXICITY_ERRORS = Counter('toxicity_errors_total', 'Toxicity service errors', ['error_type'])
CIRCUIT_BREAKER_STATE = Gauge('circuit_breaker_open', 'Circuit breaker state (1=open, 0=closed)')
MESSAGES_PROCESSED = Counter('messages_processed_total', 'Total messages processed', ['toxic'])

class Update(BaseModel):
    update_id: int
    message: dict | None = None
    edited_message: dict | None = None

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.url.path,
        status=response.status_code
    ).inc()
    REQUEST_DURATION.labels(
        method=request.method,
        endpoint=request.url.path
    ).observe(duration)
    
    return response

@app.get("/healthz")
def healthz(): return {"ok": True}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

async def send_msg(chat_id, text):
    try:
        await client.post(f"{API_BASE}/sendMessage", json={"chat_id": chat_id, "text": text}, timeout=5.0)
    except Exception as e:
        print(f"Failed to send alert: {e}")

@circuit(failure_threshold=5, recovery_timeout=30, expected_exception=Exception)
async def call_toxicity_service(text: str):
    """Call toxicity service with circuit breaker protection"""
    start_time = time.time()
    try:
        r = await client.post(TOXICITY_URL, json={"text": text}, timeout=TIMEOUT)
        duration = time.time() - start_time
        TOXICITY_CALL_DURATION.observe(duration)
        CIRCUIT_BREAKER_STATE.set(0)
        
        if r.status_code != 200:
            TOXICITY_ERRORS.labels(error_type=f"http_{r.status_code}").inc()
            return None
            
        return r.json()
    except httpx.TimeoutException:
        TOXICITY_ERRORS.labels(error_type="timeout").inc()
        CIRCUIT_BREAKER_STATE.set(1)
        raise
    except Exception as e:
        TOXICITY_ERRORS.labels(error_type="connection_error").inc()
        CIRCUIT_BREAKER_STATE.set(1)
        raise

@app.post("/webhook")
async def webhook(update: Update):
    msg = update.message or update.edited_message
    if not msg or "text" not in msg:
        return {"ok": True}

    chat = msg["chat"]; text = msg["text"]; mid = msg["message_id"]
    user = msg.get("from", {}).get("username") or str(msg.get("from", {}).get("id"))

    try:
        data = await call_toxicity_service(text)
        if data is None:
            MESSAGES_PROCESSED.labels(toxic="error").inc()
            return {"ok": True}
    except Exception as e:
        print(f"Toxicity service unavailable: {e}")
        MESSAGES_PROCESSED.labels(toxic="error").inc()
        return {"ok": True}

    is_toxic = data.get("toxic", False)
    MESSAGES_PROCESSED.labels(toxic=str(is_toxic).lower()).inc()

    if is_toxic:
        reasons = ", ".join(data.get("reasons", [])) or "toxic"
        alert = (
            "[ALERT] Toxic message detected\n"
            f"User: @{user}\n"
            f"Score: {data.get('toxicity',0):.2f}  ({reasons})\n"
            f"Text: {text}"
        )
        await send_msg(MOD_CHAT_ID, alert)

    return {"ok": True}
