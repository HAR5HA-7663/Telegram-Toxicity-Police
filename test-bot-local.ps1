# Test bot service locally with mock Telegram updates
# Make sure the bot service is running before running this script

param(
    [string]$BotUrl = "http://localhost:8081"
)

Write-Host "=== Testing Telegram Bot Service ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bot service URL: $BotUrl" -ForegroundColor Gray
Write-Host ""

# Test health check
Write-Host "1. Health check..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "$BotUrl/healthz"
    Write-Host "   Status: OK" -ForegroundColor Green
} catch {
    Write-Host "   Error: Bot service not responding" -ForegroundColor Red
    Write-Host "   Make sure the bot service is running on port 8081" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "2. Sending mock toxic message..." -ForegroundColor Yellow

$toxicUpdate = @{
    update_id = 123456789
    message = @{
        message_id = 1
        from = @{
            id = 12345
            username = "testuser"
        }
        chat = @{
            id = -1001234567890
            type = "group"
        }
        text = "seriously are you that not intelligent to not understand ur brain is of the size of an ant?"
    }
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "$BotUrl/webhook" `
        -Method Post `
        -ContentType "application/json" `
        -Body $toxicUpdate
    
    Write-Host "   Response: OK" -ForegroundColor Green
    Write-Host "   Check your moderator chat for alert!" -ForegroundColor Cyan
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Sending mock clean message..." -ForegroundColor Yellow

$cleanUpdate = @{
    update_id = 123456790
    message = @{
        message_id = 2
        from = @{
            id = 12345
            username = "testuser"
        }
        chat = @{
            id = -1001234567890
            type = "group"
        }
        text = "hello everyone, have a great day!"
    }
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri "$BotUrl/webhook" `
        -Method Post `
        -ContentType "application/json" `
        -Body $cleanUpdate
    
    Write-Host "   Response: OK" -ForegroundColor Green
    Write-Host "   No alert should be sent for clean messages" -ForegroundColor Gray
} catch {
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Tests complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Note: These are mock updates. For real Telegram testing:" -ForegroundColor Yellow
Write-Host "1. Use ngrok to expose your bot service"
Write-Host "2. Set the webhook with Telegram"
Write-Host "3. Send real messages in a group"
Write-Host ""
Write-Host "See LOCAL_TESTING.md for detailed instructions"
