Write-Host "🚀 Génération de trafic pour test..." -ForegroundColor Yellow

for ($i = 1; $i -le 20; $i++) {
    Write-Host "Test $i/20" -ForegroundColor Green
    
    # Appels GET simples
    try { Invoke-RestMethod -Uri "http://localhost:3001/" -Method GET | Out-Null } catch {}
    try { Invoke-RestMethod -Uri "http://localhost:3001/api/users" -Method GET | Out-Null } catch {}
    try { Invoke-RestMethod -Uri "http://localhost:3001/api/products" -Method GET | Out-Null } catch {}
    try { Invoke-RestMethod -Uri "http://localhost:3001/api/orders" -Method GET | Out-Null } catch {}
    
    # Appel POST
    try { 
        $user = @{ name = "Test $i"; email = "test$i@example.com" }
        Invoke-RestMethod -Uri "http://localhost:3001/api/users" -Method POST -Body ($user | ConvertTo-Json) -ContentType "application/json" | Out-Null 
    } catch {}
    
    Start-Sleep -Milliseconds 200
}

Write-Host "✅ Trafic généré ! Vérifiez maintenant Grafana." -ForegroundColor Green 