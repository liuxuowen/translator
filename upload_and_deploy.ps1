# Configuration
$ServerIP = "47.129.9.175"
$PemKeyPath = "C:/Users/liuxu/Documents/demo_sin.pem" 
$User = "admin"
$RemoteDir = "/home/$User/translator_demo"

# Check PEM
if (-not (Test-Path $PemKeyPath)) {
    Write-Host "Error: key.pem not found!" -ForegroundColor Red; exit
}

# 1. Create Remote Directory
Write-Host "Creating remote directory..." -ForegroundColor Cyan
ssh -i $PemKeyPath -o StrictHostKeyChecking=no $User@$ServerIP "mkdir -p $RemoteDir"

# 2. Upload Files (excluding venv, .git, etc)
# Using SCP. Note: This uploads everything in current dir. 
# We explicitly list files to avoid uploading huge venv or git folders
Write-Host "Uploading files..." -ForegroundColor Cyan
$files = @("app.py", "Dockerfile", "docker-compose.yml", "requirements.txt", ".env", "deploy.sh", "templates", "Caddyfile")
foreach ($file in $files) {
    if (Test-Path $file) {
        scp -i $PemKeyPath -r $file $User@$ServerIP`:$RemoteDir/
    }
}

# 3. Setup Permissions and Run Deploy Script
Write-Host "Running deployment on server..." -ForegroundColor Green
ssh -i $PemKeyPath $User@$ServerIP "cd $RemoteDir && chmod +x deploy.sh && ./deploy.sh"

Write-Host "Done! Access your app at http://$ServerIP`:8000" -ForegroundColor Yellow
