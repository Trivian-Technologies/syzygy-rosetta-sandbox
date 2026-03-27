"""
Syzygy Rosetta Sandbox — HTTP Server (GCP Cloud Run)

Provides REST API endpoints and Web UI for running simulations.
Designed for deployment to Google Cloud Run.

Usage:
    python sandbox/server.py
    
Web Pages:
    GET  /                 - Dashboard
    GET  /scenarios        - Scenarios list
    GET  /logs             - Log viewer

API Endpoints:
    GET  /health           - Health check
    POST /run              - Run simulation
    GET  /scenarios        - List available scenarios (JSON)
    POST /evaluate-single  - Evaluate a single input
    GET  /api/logs         - List log files
    GET  /api/logs/<file>  - Get log file content
"""

import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional, List
from dataclasses import asdict

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

from flask import Flask, request, jsonify, render_template
from config import settings
from llm_client import create_llm_client, LLMMessage
from agent_sim_gcp import (
    MultiAgentSimulator, 
    RosettaGovernance, 
    Agent, 
    Industry,
    get_test_scenarios
)

# Get template folder path
template_dir = Path(__file__).parent / "templates"
app = Flask(__name__, template_folder=str(template_dir))

# Initialize clients on startup
llm_client = None
rosetta = None
llm_client_by_model: dict[str, object] = {}
models_cache = {"ts": 0.0, "models": []}


def _normalize_model_id(model_id: str) -> str:
    mid = (model_id or "").strip()
    return mid


def get_llm_client_for_model(model_id: Optional[str]):
    """Cache a client per model id; fallback to default client."""
    mid = _normalize_model_id(model_id or "")
    if not mid or mid == settings.gemini_model:
        return get_llm_client()

    if mid not in llm_client_by_model:
        llm_client_by_model[mid] = create_llm_client(
            provider=settings.llm_provider,
            api_key=settings.gemini_api_key,
            model=mid,
        )
    return llm_client_by_model[mid]


def get_llm_client():
    global llm_client
    if llm_client is None:
        llm_client = create_llm_client(
            provider=settings.llm_provider,
            api_key=settings.gemini_api_key,
            model=settings.gemini_model
        )
    return llm_client


def get_rosetta():
    global rosetta
    if rosetta is None:
        rosetta = RosettaGovernance(settings.rosetta_url)
    return rosetta


# ============================================
# Web Pages (HTML)
# ============================================

@app.route('/')
def index():
    """Dashboard page"""
    return render_template('index.html')


@app.route('/scenarios')
def scenarios_page():
    """Scenarios page"""
    # Check if request wants JSON
    if request.headers.get('Accept') == 'application/json':
        return list_scenarios()
    return render_template('scenarios.html')


@app.route('/logs')
def logs_page():
    """Logs viewer page"""
    return render_template('logs.html')


# ============================================
# API Endpoints
# ============================================

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint for Cloud Run"""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": settings.environment,
        "llm_provider": settings.llm_provider,
        "gemini_model": settings.gemini_model,
        "rosetta_url": settings.rosetta_url
    })


@app.route('/api/scenarios', methods=['GET'])
@app.route('/scenarios', methods=['GET'])
def list_scenarios():
    """List all available test scenarios"""
    # Only return JSON for API requests
    if not request.path.startswith('/api') and request.headers.get('Accept') != 'application/json':
        if 'text/html' in request.headers.get('Accept', ''):
            return render_template('scenarios.html')
    
    scenarios = get_test_scenarios()
    return jsonify({
        "total": len(scenarios),
        "scenarios": [
            {
                "id": s["id"],
                "name": s["name"],
                "industry": s["agents"][0].industry.value,
                "inputs": s["inputs"]
            }
            for s in scenarios
        ]
    })


@app.route('/api/models', methods=['GET'])
def api_models():
    """List available Google Generative Language models supporting generateContent."""
    if settings.llm_provider != "gemini":
        return jsonify({"models": [], "error": "LLM_PROVIDER is not gemini"}), 400
    if not settings.gemini_api_key:
        return jsonify({"models": [], "error": "GEMINI_API_KEY not configured"}), 503

    now = time.time()
    if models_cache["models"] and (now - models_cache["ts"] < 300):
        return jsonify({"models": models_cache["models"], "cached": True})

    try:
        import google.generativeai as genai

        genai.configure(api_key=settings.gemini_api_key)
        models = []
        for m in genai.list_models():
            methods = getattr(m, "supported_generation_methods", None) or []
            if "generateContent" in methods:
                models.append(m.name)
        models = sorted(set(models))
        models_cache["models"] = models
        models_cache["ts"] = now
        return jsonify({"models": models, "cached": False})
    except Exception as e:
        return jsonify({"models": [], "error": str(e)}), 500


@app.route('/run', methods=['POST'])
def run_simulation():
    """Run full simulation with all scenarios"""
    try:
        data = request.get_json() or {}
        
        # Options
        use_mock = data.get('mock', False)
        with_governance = data.get('governance', True)
        scenario_ids = data.get('scenarios', None)  # Optional: filter scenarios
        
        # Initialize clients
        if use_mock:
            from llm_client import MockLLMClient
            llm = MockLLMClient()
        else:
            llm = get_llm_client()
        
        rosetta_client = get_rosetta()
        
        # Check governance availability
        if with_governance and not rosetta_client.connected:
            return jsonify({
                "error": "Rosetta governance not available",
                "rosetta_url": settings.rosetta_url,
                "hint": "Set governance=false to run without governance, or ensure Rosetta is running"
            }), 503
        
        simulator = MultiAgentSimulator(rosetta_client, llm)
        
        # Get scenarios (optionally filtered)
        scenarios = get_test_scenarios()
        if scenario_ids:
            scenarios = [s for s in scenarios if s["id"] in scenario_ids]
        
        # Run simulations
        results = []
        for scenario in scenarios:
            conv_log = simulator.run_scenario(
                scenario_id=scenario["id"],
                scenario_name=scenario["name"],
                agents=scenario["agents"],
                user_inputs=scenario["inputs"],
                with_governance=with_governance and rosetta_client.connected
            )
            results.append(asdict(conv_log))
        
        # Summary statistics
        total_drift = sum(len(r["governance_summary"]["drift_points"]) for r in results)
        total_escalated = sum(r["governance_summary"]["escalated"] for r in results)
        total_rewritten = sum(r["governance_summary"]["rewritten"] for r in results)
        total_allowed = sum(r["governance_summary"]["allowed"] for r in results)
        
        return jsonify({
            "success": True,
            "timestamp": datetime.utcnow().isoformat(),
            "config": {
                "llm_provider": llm.__class__.__name__,
                "governance_enabled": with_governance and rosetta_client.connected,
                "rosetta_url": settings.rosetta_url,
                "environment": settings.environment
            },
            "summary": {
                "total_scenarios": len(results),
                "allowed": total_allowed,
                "rewritten": total_rewritten,
                "escalated": total_escalated,
                "drift_points": total_drift
            },
            "conversations": results
        })
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500


@app.route('/evaluate-single', methods=['POST'])
def evaluate_single():
    """Evaluate a single input through the full pipeline"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body provided"}), 400
        
        prompt = data.get('prompt')
        if not prompt:
            return jsonify({"error": "prompt field required"}), 400
        
        system_prompt = data.get('system_prompt', 'You are a helpful AI assistant.')
        industry = data.get('industry', 'general')
        use_mock = data.get('mock', False)
        with_governance = data.get('governance', True)
        model_override = data.get('model')

        rosetta_eval = None
        effective_prompt = prompt

        # WITH Rosetta: pre-guard on user input, then call LLM (or block).
        if with_governance:
            rosetta_client = get_rosetta()
            if not rosetta_client.connected:
                return jsonify({
                    "timestamp": datetime.utcnow().isoformat(),
                    "input": {"prompt": prompt, "system_prompt": system_prompt, "industry": industry},
                    "effective_prompt": prompt,
                    "llm_response": None,
                    "governance": {"error": "Rosetta not connected", "rosetta_url": settings.rosetta_url},
                }), 503

            rosetta_eval = rosetta_client.evaluate(prompt, industry)
            decision = rosetta_eval.get("decision", "unknown")
            rewrite = rosetta_eval.get("rewrite")

            if decision == "rewrite" and rewrite:
                effective_prompt = rewrite
            elif decision == "escalate":
                return jsonify({
                    "timestamp": datetime.utcnow().isoformat(),
                    "input": {"prompt": prompt, "system_prompt": system_prompt, "industry": industry},
                    "effective_prompt": None,
                    "llm_response": {
                        "content": "Blocked by Rosetta (escalated).",
                        "model": None,
                        "provider": "blocked"
                    },
                    "governance": rosetta_eval,
                })

        # WITHOUT Rosetta: directly call the model with user input.
        if use_mock:
            from llm_client import MockLLMClient
            llm = MockLLMClient()
        else:
            llm = get_llm_client_for_model(model_override)

        llm_response = llm.generate(
            prompt=effective_prompt,
            system_prompt=system_prompt,
            temperature=0.7,
            max_tokens=1024
        )

        result = {
            "timestamp": datetime.utcnow().isoformat(),
            "input": {
                "prompt": prompt,
                "system_prompt": system_prompt,
                "industry": industry
            },
            "effective_prompt": effective_prompt,
            "llm_response": {
                "content": llm_response.content,
                "model": llm_response.model,
                "provider": llm_response.provider
            },
            "governance": rosetta_eval
        }

        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500


@app.route('/chat', methods=['POST'])
def chat():
    """Multi-turn chat endpoint"""
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON body provided"}), 400
        
        messages = data.get('messages', [])
        if not messages:
            return jsonify({"error": "messages array required"}), 400
        
        system_prompt = data.get('system_prompt', 'You are a helpful AI assistant.')
        industry = data.get('industry', 'general')
        with_governance = data.get('governance', True)
        model_override = data.get('model')
        
        # Convert to LLMMessage objects
        llm_messages = [
            LLMMessage(role=m.get('role', 'user'), content=m.get('content', ''))
            for m in messages
        ]

        # Pre-guard: evaluate last user message before calling model.
        rosetta_eval = None
        if with_governance:
            rosetta_client = get_rosetta()
            if rosetta_client.connected:
                last_user_idx = None
                for idx in range(len(llm_messages) - 1, -1, -1):
                    if llm_messages[idx].role == "user":
                        last_user_idx = idx
                        break
                if last_user_idx is not None:
                    rosetta_eval = rosetta_client.evaluate(llm_messages[last_user_idx].content, industry)
                    decision = rosetta_eval.get("decision", "unknown")
                    rewrite = rosetta_eval.get("rewrite")
                    if decision == "rewrite" and rewrite:
                        llm_messages[last_user_idx] = LLMMessage(role="user", content=rewrite)
                    elif decision == "escalate":
                        return jsonify({
                            "timestamp": datetime.utcnow().isoformat(),
                            "response": {
                                "content": "Blocked by Rosetta (escalated).",
                                "model": None,
                                "provider": "blocked"
                            },
                            "governance": rosetta_eval
                        })

        llm = get_llm_client_for_model(model_override)
        llm_response = llm.chat(
            messages=llm_messages,
            system_prompt=system_prompt,
            temperature=0.7,
            max_tokens=1024
        )
        
        result = {
            "timestamp": datetime.utcnow().isoformat(),
            "response": {
                "content": llm_response.content,
                "model": llm_response.model,
                "provider": llm_response.provider
            },
            "governance": rosetta_eval
        }

        return jsonify(result)
        
    except Exception as e:
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500


# ============================================
# Log Files API
# ============================================

@app.route('/api/logs', methods=['GET'])
def list_log_files():
    """List available log files"""
    logs_dir = settings.logs_dir
    files = []
    
    if logs_dir.exists():
        for f in sorted(logs_dir.glob('*.json'), reverse=True):
            files.append(f.name)
    
    # Also check results dir
    results_dir = settings.results_dir
    if results_dir.exists():
        for f in sorted(results_dir.glob('*.json'), reverse=True):
            files.append(f"results/{f.name}")
    
    return jsonify({"files": files[:20]})  # Limit to 20 most recent


@app.route('/api/logs/<path:filename>', methods=['GET'])
def get_log_file(filename):
    """Get contents of a specific log file"""
    # Security: prevent path traversal
    if '..' in filename or filename.startswith('/'):
        return jsonify({"error": "Invalid filename"}), 400
    
    # Check logs directory
    if filename.startswith('results/'):
        filepath = settings.results_dir / filename.replace('results/', '')
    else:
        filepath = settings.logs_dir / filename
    
    if not filepath.exists():
        return jsonify({"error": "File not found"}), 404
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    debug = settings.environment == 'development'
    
    print(f"\n{'='*60}")
    print(f"  SYZYGY ROSETTA SANDBOX — HTTP Server")
    print(f"{'='*60}")
    print(f"\n  Environment: {settings.environment}")
    print(f"  LLM Provider: {settings.llm_provider}")
    print(f"  Gemini Model: {settings.gemini_model}")
    print(f"  Rosetta URL: {settings.rosetta_url}")
    print(f"\n  Web UI: http://localhost:{port}")
    print(f"\n  Starting server on port {port}...")
    print(f"{'='*60}\n")
    
    app.run(host='0.0.0.0', port=port, debug=debug)
