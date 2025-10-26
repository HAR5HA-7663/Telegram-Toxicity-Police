# Set up Telegram webhook (PowerShell)
# Usage: .\setup-webhook.ps1 <BOT_TOKEN> <WEBHOOK_URL>

param(
    [Parameter(Mandatory=$true)]
    [string]$BotToken,
    [Parameter(Mandatory=$true)]
    [string]$WebhookUrl
)

$ErrorActionPreference = "Stop"

Write-Host "Setting webhook for Telegram bot..."
$body = @{
    url = $WebhookUrl
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$BotToken/setWebhook" `
    -Method Post `
    -ContentType "application/json" `
    -Body $body

Write-Host ""
Write-Host "Verifying webhook..."
Invoke-RestMethod -Uri "https://api.telegram.org/bot$BotToken/getWebhookInfo" | ConvertTo-Json -Depth 10
