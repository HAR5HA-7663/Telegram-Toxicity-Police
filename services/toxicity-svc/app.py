from fastapi import FastAPI, Request
from pydantic import BaseModel
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import torch, time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response

MODEL_NAME = "unitary/toxic-bert"

app = FastAPI(title="toxicity-svc")

tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model = AutoModelForSequenceClassification.from_pretrained(MODEL_NAME)
model.eval()
LABELS = ['toxicity','severe_toxicity','obscene','threat','insult','identity_attack']

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP requests', ['method', 'endpoint', 'status'])
REQUEST_DURATION = Histogram('http_request_duration_seconds', 'HTTP request duration', ['method', 'endpoint'])
INFERENCE_DURATION = Histogram('inference_duration_seconds', 'ML inference duration')

class Item(BaseModel):
    text: str

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

@app.post("/analyze")
def analyze(item: Item):
    start_time = time.time()
    
    text = (item.text or "")[:512]
    inputs = tokenizer(text, return_tensors="pt", truncation=True)
    with torch.no_grad():
        logits = model(**inputs).logits
        probs = torch.sigmoid(logits)[0].tolist()
    
    inference_time = time.time() - start_time
    INFERENCE_DURATION.observe(inference_time)
    
    scores = dict(zip(LABELS, probs))
    toxic = scores["toxicity"] > 0.5 or any(scores[k] > 0.5 for k in LABELS[1:])
    reasons = [k for k,v in scores.items() if v > 0.5]
    
    result = {"toxic": toxic, "toxicity": scores["toxicity"], "labels": scores, "reasons": reasons}
    print(f"Analysis result: toxic={toxic}, toxicity={scores['toxicity']:.4f}, reasons={reasons}, text='{text[:50]}...'")
    
    return result
