#!/bin/bash
# Set up Telegram webhook
# Usage: ./setup-webhook.sh <BOT_TOKEN> <WEBHOOK_URL>

set -e

BOT_TOKEN=$1
WEBHOOK_URL=$2

if [ -z "$BOT_TOKEN" ] || [ -z "$WEBHOOK_URL" ]; then
  echo "Usage: ./setup-webhook.sh <BOT_TOKEN> <WEBHOOK_URL>"
  echo "Example: ./setup-webhook.sh 123456:ABC-DEF http://your-alb.amazonaws.com/webhook"
  exit 1
fi

echo "Setting webhook for Telegram bot..."
curl -X POST "https://api.telegram.org/bot$BOT_TOKEN/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"$WEBHOOK_URL\"}"

echo ""
echo ""
echo "Verifying webhook..."
curl "https://api.telegram.org/bot$BOT_TOKEN/getWebhookInfo"
echo ""
