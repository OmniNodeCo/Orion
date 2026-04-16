#!/usr/bin/env python3
"""
Ollama Installer for Orion GUI
Automatically detects OS and installs Ollama
"""

import platform
import subprocess
import sys
import os
import urllib.request
import shutil
import time

class OllamaInstaller:
    def __init__(self):
        self.system = platform.system().lower()
        self.arch = platform.machine().lower()
        
    def is_ollama_installed(self):
        """Check if Ollama is already installed"""
        try:
            result = subprocess.run(
                ["ollama", "--version"],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                version = result.stdout.strip()
                print(f"✅ Ollama is already installed: {version}")
                return True
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass
        
        print("❌ Ollama is not installed")
        return False
    
    def is_ollama_running(self):
        """Check if Ollama server is running"""
        try:
            import requests
            response = requests.get("http://localhost:11434/api/tags", timeout=5)
            if response.status_code == 200:
                print("✅ Ollama server is running")
                return True
        except:
            pass
        
        print("⚠️ Ollama server is not running")
        return False
    
    def install(self):
        """Install Ollama based on OS"""
        print(f"\n{'='*50}")
        print(f"  Ollama Installer for Orion GUI")
        print(f"  OS: {platform.system()} {platform.release()}")
        print(f"  Arch: {self.arch}")
        print(f"{'='*50}\n")
        
        if self.is_ollama_installed():
            if not self.is_ollama_running():
                self.start_ollama()
            return True
        
        print("\n📦 Installing Ollama...\n")
        
        if self.system == "linux":
            return self.install_linux()
        elif self.system == "darwin":
            return self.install_macos()
        elif self.system == "windows":
            return self.install_windows()
        else:
            print(f"❌ Unsupported OS: {self.system}")
            print("Please install Ollama manually: https://ollama.com/download")
            return False
    
    def install_linux(self):
        """Install on Linux"""
        print("🐧 Installing Ollama for Linux...\n")
        
        try:
            # Method 1: Official install script
            print("Running official install script...")
            result = subprocess.run(
                ["bash", "-c", "curl -fsSL https://ollama.com/install.sh | sh"],
                capture_output=False,
                text=True
            )
            
            if result.returncode == 0:
                print("\n✅ Ollama installed successfully!")
                self.start_ollama()
                return True
            
        except Exception as e:
            print(f"⚠️ Script install failed: {e}")
        
        # Method 2: Manual download
        try:
            print("\nTrying manual download...")
            url = "https://ollama.com/download/ollama-linux-amd64"
            if "arm" in self.arch or "aarch" in self.arch:
                url = "https://ollama.com/download/ollama-linux-arm64"
            
            print(f"Downloading from {url}...")
            urllib.request.urlretrieve(url, "/usr/local/bin/ollama")
            os.chmod("/usr/local/bin/ollama", 0o755)
            
            print("✅ Ollama installed successfully!")
            self.start_ollama()
            return True
            
        except PermissionError:
            print("\n⚠️ Permission denied. Try running with sudo:")
            print("  sudo python3 install_ollama.py")
            return False
            
        except Exception as e:
            print(f"\n❌ Installation failed: {e}")
            print("Please install manually: https://ollama.com/download")
            return False
    
    def install_macos(self):
        """Install on macOS"""
        print("🍎 Installing Ollama for macOS...\n")
        
        # Method 1: Homebrew
        try:
            brew_check = subprocess.run(
                ["brew", "--version"],
                capture_output=True,
                text=True
            )
            
            if brew_check.returncode == 0:
                print("Found Homebrew. Installing via brew...")
                result = subprocess.run(
                    ["brew", "install", "ollama"],
                    capture_output=False,
                    text=True
                )
                
                if result.returncode == 0:
                    print("\n✅ Ollama installed successfully!")
                    self.start_ollama()
                    return True
                    
        except FileNotFoundError:
            pass
        
        # Method 2: Direct download
        try:
            print("Downloading Ollama for macOS...")
            url = "https://ollama.com/download/Ollama-darwin.zip"
            zip_path = "/tmp/Ollama-darwin.zip"
            
            urllib.request.urlretrieve(url, zip_path)
            
            print("Extracting...")
            subprocess.run(
                ["unzip", "-o", zip_path, "-d", "/Applications/"],
                capture_output=True
            )
            
            os.remove(zip_path)
            print("\n✅ Ollama installed successfully!")
            print("📌 Ollama.app is in /Applications/")
            self.start_ollama()
            return True
            
        except Exception as e:
            print(f"\n❌ Installation failed: {e}")
            print("Please install manually: https://ollama.com/download")
            return False
    
    def install_windows(self):
        """Install on Windows"""
        print("🪟 Installing Ollama for Windows...\n")
        
        try:
            url = "https://ollama.com/download/OllamaSetup.exe"
            installer_path = os.path.join(os.environ.get("TEMP", "."), "OllamaSetup.exe")
            
            print(f"Downloading installer...")
            print(f"URL: {url}")
            
            urllib.request.urlretrieve(url, installer_path)
            
            print(f"\n✅ Installer downloaded: {installer_path}")
            print("\n🚀 Launching installer...")
            
            # Run installer
            subprocess.Popen([installer_path], shell=True)
            
            print("\n📌 Please follow the installer wizard.")
            print("After installation, restart this application.")
            
            return True
            
        except Exception as e:
            print(f"\n❌ Download failed: {e}")
            print("\nPlease install manually:")
            print("  1. Go to https://ollama.com/download")
            print("  2. Download for Windows")
            print("  3. Run the installer")
            return False
    
    def start_ollama(self):
        """Start Ollama server"""
        print("\n🚀 Starting Ollama server...")
        
        try:
            if self.system == "windows":
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
            
            # Wait for server to start
            print("Waiting for server to start...")
            for i in range(15):
                time.sleep(1)
                try:
                    import requests
                    response = requests.get("http://localhost:11434/api/tags", timeout=2)
                    if response.status_code == 200:
                        print("✅ Ollama server is running!")
                        return True
                except:
                    print(f"  Waiting... ({i+1}s)")
            
            print("⚠️ Server may still be starting. Please wait a moment.")
            return True
            
        except FileNotFoundError:
            print("⚠️ Could not start Ollama automatically.")
            print("Please start it manually: ollama serve")
            return False
        except Exception as e:
            print(f"⚠️ Error starting Ollama: {e}")
            return False
    
    def pull_model(self, model_name):
        """Pull a model"""
        print(f"\n📥 Pulling model: {model_name}")
        
        try:
            result = subprocess.run(
                ["ollama", "pull", model_name],
                capture_output=False,
                text=True
            )
            
            if result.returncode == 0:
                print(f"✅ Model '{model_name}' downloaded successfully!")
                return True
            else:
                print(f"❌ Failed to pull model '{model_name}'")
                return False
                
        except Exception as e:
            print(f"❌ Error: {e}")
            return False


def main():
    installer = OllamaInstaller()
    
    print("""
    ╔══════════════════════════════════════╗
    ║        ORION GUI - Setup             ║
    ║        by OmniNode                   ║
    ╚══════════════════════════════════════╝
    """)
    
    print("Choose an option:\n")
    print("  1. Install Ollama")
    print("  2. Check Ollama Status")
    print("  3. Start Ollama Server")
    print("  4. Pull Orion Model")
    print("  5. Pull Orion + Install Ollama (Full Setup)")
    print("  6. Exit\n")
    
    choice = input("Enter choice (1-6): ").strip()
    
    if choice == "1":
        installer.install()
        
    elif choice == "2":
        installer.is_ollama_installed()
        installer.is_ollama_running()
        
    elif choice == "3":
        installer.start_ollama()
        
    elif choice == "4":
        print("\nAvailable Orion versions:")
        print("  1. OmniNode/Orion:V1.1 (latest)")
        print("  2. OmniNode/Orion:V1.0")
        print("  3. Custom model name\n")
        
        model_choice = input("Enter choice (1-3): ").strip()
        
        if model_choice == "1":
            installer.pull_model("OmniNode/Orion:V1.1")
        elif model_choice == "2":
            installer.pull_model("OmniNode/Orion:V1.0")
        elif model_choice == "3":
            name = input("Enter model name: ").strip()
            if name:
                installer.pull_model(name)
        
    elif choice == "5":
        success = installer.install()
        if success:
            time.sleep(3)
            installer.pull_model("OmniNode/Orion:V1.1")
            print("\n✅ Full setup complete!")
            print("Run the Orion GUI to start chatting.")
        
    elif choice == "6":
        print("Goodbye! 👋")
        sys.exit(0)
    
    else:
        print("Invalid choice")


if __name__ == "__main__":
    main()