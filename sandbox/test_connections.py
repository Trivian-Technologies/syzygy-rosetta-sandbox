"""
Syzygy Rosetta Sandbox — Connection Test Script

Tests all external dependencies:
1. Environment variables loading
2. Gemini API connection
3. Rosetta API connection
"""

import os
import sys
import requests
from pathlib import Path

from rosetta_probe import check_rosetta_reachable

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

print("\n" + "=" * 60)
print("  CONNECTION TEST SCRIPT")
print("=" * 60)

# =============================================================================
# TEST 1: Environment Variables
# =============================================================================
print("\n[TEST 1] Environment Variables")
print("-" * 40)

# Load .env file
from dotenv import load_dotenv
env_path = Path(__file__).parent.parent / ".env"
print(f"Looking for .env at: {env_path}")
print(f".env exists: {env_path.exists()}")

if env_path.exists():
    load_dotenv(env_path)
    print("[OK] .env file loaded")
else:
    print("[ERROR] .env file not found!")

# Check key variables
variables = [
    "LLM_PROVIDER",
    "GEMINI_API_KEY", 
    "GEMINI_MODEL",
    "ROSETTA_URL",
    "ENVIRONMENT"
]

print("\nEnvironment Variables:")
for var in variables:
    value = os.getenv(var)
    if value:
        # Mask API key
        if "KEY" in var and value:
            display = value[:10] + "..." + value[-4:] if len(value) > 14 else "***"
        else:
            display = value
        print(f"  {var} = {display}")
    else:
        print(f"  {var} = [NOT SET]")

# =============================================================================
# TEST 2: Rosetta API Connection
# =============================================================================
print("\n[TEST 2] Rosetta API Connection")
print("-" * 40)

rosetta_url = os.getenv("ROSETTA_URL", "http://localhost:8000")
print(f"ROSETTA_URL: {rosetta_url}")

# Probe without /healthz (GET / home, /health, then POST /evaluate)
print("\nTesting: rosetta_probe (home + evaluate, no /healthz)")
try:
    ok, detail = check_rosetta_reachable(rosetta_url, timeout=15)
    if ok:
        print(f"[OK] Rosetta reachable: {detail}")
    else:
        print(f"[ERROR] Rosetta probe failed: {detail}")
except Exception as e:
    print(f"[ERROR] {type(e).__name__}: {e}")

# =============================================================================
# TEST 3: Gemini API Connection
# =============================================================================
print("\n[TEST 3] Gemini API Connection")
print("-" * 40)

gemini_key = os.getenv("GEMINI_API_KEY")
gemini_model = os.getenv("GEMINI_MODEL", "gemma-3-27b-it")

if not gemini_key:
    print("[ERROR] GEMINI_API_KEY not set!")
else:
    print(f"API Key: {gemini_key[:10]}...{gemini_key[-4:]}")
    print(f"Model: {gemini_model}")
    
    try:
        import google.generativeai as genai
        
        print("\nInitializing Gemini client...")
        genai.configure(api_key=gemini_key)
        model = genai.GenerativeModel(gemini_model)
        
        print("Sending test message...")
        response = model.generate_content("Say 'Hello, connection test successful!' in one line.")
        
        print(f"Response: {response.text[:200]}")
        print("[OK] Gemini API connection successful!")
        
    except ImportError:
        print("[ERROR] google-generativeai package not installed")
    except Exception as e:
        print(f"[ERROR] {type(e).__name__}: {e}")

# =============================================================================
# Summary
# =============================================================================
print("\n" + "=" * 60)
print("  SUMMARY")
print("=" * 60)

issues = []

if not env_path.exists():
    issues.append("- .env file not found (copy from .env.example)")
    
if not os.getenv("GEMINI_API_KEY"):
    issues.append("- GEMINI_API_KEY not configured")
    
rosetta_url = os.getenv("ROSETTA_URL")
if not rosetta_url:
    issues.append("- ROSETTA_URL not configured")
else:
    ok, detail = check_rosetta_reachable(rosetta_url, timeout=5)
    if not ok:
        issues.append(f"- Rosetta unreachable: {detail}")

if issues:
    print("\n[!] Issues Found:")
    for issue in issues:
        print(f"    {issue}")
else:
    print("\n[OK] All connections successful!")

print("\n" + "=" * 60 + "\n")
