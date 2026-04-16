#!/usr/bin/env python3
"""
Orion GUI Setup Script
Cross-platform setup and launcher
"""

import os
import sys
import subprocess
import platform
import yaml
import time


def load_config():
    """Load config.yml"""
    config_path = os.path.join(os.path.dirname(__file__), "config.yml")
    try:
        with open(config_path, "r") as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        return {
            "app": {"port": 5000, "version": "1.1.0"},
            "ollama": {"url": "http://localhost:11434", "default_model": "OmniNode/Orion:V1.1"}
        }


def check_python_deps():
    """Install Python dependencies"""
    print("📦 Checking Python dependencies...")
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-r", "requirements.txt", "-q"],
            check=True
        )
        print("✅ Dependencies installed")
    except subprocess.CalledProcessError:
        print("❌ Failed to install dependencies")
        sys.exit(1)


def check_ollama():
    """Check if Ollama is installed and running"""
    print("\n🔍 Checking Ollama...")
    
    try:
        result = subprocess.run(
            ["ollama", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            print(f"✅ Ollama found: {result.stdout.strip()}")
        
        # Check if running
        import requests
        try:
            response = requests.get("http://localhost:11434/api/tags", timeout=3)
            if response.status_code == 200:
                print("✅ Ollama server is running")
                return True
        except:
            print("⚠️ Ollama server is not running")
            print("Starting Ollama server...")
            
            if platform.system().lower() == "windows":
                subprocess.Popen(
                    ["ollama", "serve"],
                    creationflags=subprocess.CREATE_NO_WINDOW,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL
                )
            else:
                subprocess.Popen(
                    ["ollama", "serve"],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    start_new_session=True
                )
            
            time.sleep(5)
            return True
            
    except FileNotFoundError:
        print("❌ Ollama is not installed")
        print("\nWould you like to install Ollama? (y/n)")
        choice = input("> ").strip().lower()
        
        if choice == "y":
            from install_ollama import OllamaInstaller
            installer = OllamaInstaller()
            return installer.install()
        else:
            print("Please install Ollama: https://ollama.com/download")
            return False
    
    return True


def check_model(config):
    """Check if default model exists"""
    default_model = config.get("ollama", {}).get("default_model", "OmniNode/Orion:V1.1")
    
    print(f"\n🔍 Checking for model: {default_model}")
    
    try:
        import requests
        response = requests.get("http://localhost:11434/api/tags", timeout=5)
        data = response.json()
        models = [m["name"] for m in data.get("models", [])]
        
        if default_model in models:
            print(f"✅ Model found: {default_model}")
            return True
        else:
            print(f"⚠️ Model not found: {default_model}")
            print(f"\nWould you like to download it? (y/n)")
            choice = input("> ").strip().lower()
            
            if choice == "y":
                print(f"\n📥 Pulling {default_model}...")
                subprocess.run(["ollama", "pull", default_model])
                return True
            
            return False
            
    except Exception as e:
        print(f"⚠️ Could not check models: {e}")
        return False


def launch_app(config):
    """Launch the Orion GUI"""
    port = config.get("app", {}).get("port", 5000)
    debug = config.get("app", {}).get("debug", False)
    
    print(f"\n{'='*50}")
    print(f"  🚀 Launching Orion GUI")
    print(f"  📍 http://localhost:{port}")
    print(f"  📌 Press Ctrl+C to stop")
    print(f"{'='*50}\n")
    
    # Open browser
    import webbrowser
    import threading
    
    def open_browser():
        time.sleep(2)
        webbrowser.open(f"http://localhost:{port}")
    
    threading.Thread(target=open_browser, daemon=True).start()
    
    # Run Flask
    from app import app
    app.run(debug=debug, port=port, host="0.0.0.0")


def main():
    print("""
    ╔══════════════════════════════════════╗
    ║        ◉ ORION GUI v1.1             ║
    ║        by OmniNode                   ║
    ╚══════════════════════════════════════╝
    """)
    
    config = load_config()
    
    check_python_deps()
    
    ollama_ok = check_ollama()
    if not ollama_ok:
        print("\n⚠️ Cannot start without Ollama. Exiting.")
        sys.exit(1)
    
    check_model(config)
    
    launch_app(config)


if __name__ == "__main__":
    main()