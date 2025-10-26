# Test toxicity service locally via port-forward (PowerShell)
# Usage: .\test-toxicity-local.ps1

Write-Host "Setting up port-forward to toxicity-svc..."
$job = Start-Job -ScriptBlock { kubectl port-forward deploy/toxicity-svc 8080:8080 -n telegram }

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "Testing toxicity detection..." -ForegroundColor Cyan
Write-Host ""

Write-Host "Test 1: Toxic message" -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8080/analyze `
    -Method Post `
    -ContentType "application/json" `
    -Body '{"text":"you are an idiot"}' | ConvertTo-Json -Depth 10

Write-Host ""

Write-Host "Test 2: Clean message" -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8080/analyze `
    -Method Post `
    -ContentType "application/json" `
    -Body '{"text":"have a great day!"}' | ConvertTo-Json -Depth 10

Write-Host ""

Write-Host "Test 3: Health check" -ForegroundColor Yellow
Invoke-RestMethod -Uri http://localhost:8080/healthz | ConvertTo-Json

Write-Host ""

Stop-Job $job
Remove-Job $job
Write-Host "Port-forward stopped." -ForegroundColor Green
