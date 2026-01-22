# Configuration
$ServerIP = "47.129.9.175"
$PemKeyPath = "C:/Users/liuxu/Documents/demo_sin.pem"  # Assumes key.pem is in the same directory as this script. Change if needed.
$User = "admin" # For Debian 12+. Try "debian" or "ec2-user" if this fails.

# Check if PEM file exists
if (-not (Test-Path $PemKeyPath)) {
    Write-Host "Error: PEM file not found at $PemKeyPath" -ForegroundColor Red
    Write-Host "Please ensure your key file is named 'key.pem' and placed in this directory, or update the script path."
    exit
}

# Fix permissions for PEM file (Windows specific issue with SSH)
# SSH on Windows often complains if permissions are too open.
# This part is optional but helpful if you encounter "WARNING: UNPROTECTED PRIVATE KEY FILE!"
Write-Host "Checking/Fixing PEM file permissions..." -ForegroundColor Cyan
icacls $PemKeyPath /reset
icacls $PemKeyPath /grant:r "$($env:USERNAME):(R)"
icacls $PemKeyPath /inheritance:r

# Connect
Write-Host "Connecting to $User@$ServerIP..." -ForegroundColor Green
ssh -i $PemKeyPath $User@$ServerIP
