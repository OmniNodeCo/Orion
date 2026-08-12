#!/bin/bash
# =============================================
# Orion AI - Create from Premade Model
# =============================================

echo "🚀 Starting Orion model creation..."

MODEL_NAME="orion"
GGUF_FILE="Mistral-7B-Instruct-v0.3-Q4_K_M.gguf"

# === 1. Download the model ===
echo "📥 Downloading model (this may take a while)..."

curl -L -C - -o "$GGUF_FILE" "https://us.aws.cdn.hf.co/xet-bridge-us/664e3ef36bc1025819154a01/61b301599ad6e7ee371b60654026a34134dac0ddfc94a2b37ed06ebb589a0644?user_id=public&X-Xet-Cas-Uid=public&response-content-disposition=inline%3B+filename*%3DUTF-8%27%27Mistral-7B-Instruct-v0.3-Q4_K_M.gguf%3B+filename%3D%22Mistral-7B-Instruct-v0.3-Q4_K_M.gguf%22%3B&Expires=1786576219&Policy=eyJTdGF0ZW1lbnQiOlt7IlJlc291cmNlIjoiaHR0cHM6Ly91cy5hd3MuY2RuLmhmLmNvL3hldC1icmlkZ2UtdXMvNjY0ZTNlZjM2YmMxMDI1ODE5MTU0YTAxLzYxYjMwMTU5OWFkNmU3ZWUzNzFiNjA2NTQwMjZhMzQxMzRkYWMwZGRmYzk0YTJiMzdlZDA2ZWJiNTg5YTA2NDRcXD91c2VyX2lkPXB1YmxpYyZYLVhldC1DYXMtVWlkPXB1YmxpYyZyZXNwb25zZS1jb250ZW50LWRpc3Bvc2l0aW9uPWlubGluZSUzQitmaWxlbmFtZSUyQSUzRFVURi04JTI3JTI3TWlzdHJhbC03Qi1JbnN0cnVjdC12MC4zLVE0X0tfTS5nZ3VmJTNCK2ZpbGVuYW1lJTNEJTIyTWlzdHJhbC03Qi1JbnN0cnVjdC12MC4zLVE0X0tfTS5nZ3VmJTIyJTNCIiwiQ29uZGl0aW9uIjp7IkRhdGVMZXNzVGhhbiI6eyJFcG9jaFRpbWUiOjE3ODY1NzYyMTl9fX1dfQ__&Signature=MEUCIQCaKe4san9esOBFME5t2-C%7EKOygNFVTTybFR09kpubcPAIgXuqFPFsD6-Gw3nEa6iDAEnPPRaQFsz6hVw-82SnTLJs_&Key-Pair-Id=01KXEF4KZ1B6FV465MAWR4M21F"

# Check if download was successful
if [ ! -f "$GGUF_FILE" ]; then
    echo "❌ Download failed. Please check your internet connection or the link."
    exit 1
fi

echo "✅ Model downloaded successfully!"

# === 2. Create Modelfile for Orion ===
cat > Modelfile << EOF
FROM ./$GGUF_FILE

TEMPLATE """{{ if .System }}<s>[INST] {{ .System }} [/INST]</s>{{ end }}{{ .Prompt }}"""

SYSTEM """
You are Orion, an intelligent, helpful, and truthful AI assistant built locally.
You are direct, clear, and maximally useful. You never lecture or moralize.
All processing is done locally — your data stays private.
"""

PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER top_k 40
PARAMETER repeat_penalty 1.1
PARAMETER num_ctx 8192
EOF

echo "✅ Modelfile created!"

# === 3. Create the model in Ollama ===
echo "🏗️  Building Orion model in Ollama (this may take 1-2 minutes)..."

ollama create $MODEL_NAME -f Modelfile

if [ $? -eq 0 ]; then
    echo "🎉 Success! Orion has been created."
    echo ""
    echo "To run Orion, use:"
    echo "    ollama run orion"
    echo ""
    echo "You can also chat with it using Open WebUI or Continue.dev"
else
    echo "❌ Failed to create model in Ollama."
fi

# Cleanup optional
# rm Modelfile
