#!/bin/bash
# Test toxicity service locally via port-forward
# Usage: ./test-toxicity-local.sh

echo "Setting up port-forward to toxicity-svc..."
kubectl port-forward deploy/toxicity-svc 8080:8080 -n telegram &
PF_PID=$!

sleep 3

echo ""
echo "Testing toxicity detection..."
echo ""

echo "Test 1: Toxic message"
curl -X POST http://localhost:8080/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text":"you are an idiot"}'

echo ""
echo ""

echo "Test 2: Clean message"
curl -X POST http://localhost:8080/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text":"have a great day!"}'

echo ""
echo ""

echo "Test 3: Health check"
curl http://localhost:8080/healthz

echo ""
echo ""

kill $PF_PID
echo "Port-forward stopped."
