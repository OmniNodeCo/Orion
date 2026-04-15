
# 🦅 Orion AI - OmniNode

> **Version:** V1.0 | **Size:** 4GB | **Source:** 🔒 Private

[![GGUF](https://img.shields.io/badge/Format-GGUF-blue)](https://github.com/ggerganov/llama.cpp)
[![Ollama](https://img.shields.io/badge/Ollama-Ready-green)](https://ollama.com/OmniNode/Orion)
[![License](https://img.shields.io/badge/License-Custom-red)](LICENSE)

---

## ⚠️ Important Notice

| Component | Status | Notes |
|-----------|--------|-------|
| **Source Code** | 🔒 Private | Training infrastructure & scripts proprietary |
| **Model Weights** | ✅ Public | `Orion-V1.0.gguf` (4GB) |
| **Architecture** | 🔒 Private | Model topology and training data confidential |
| **License** | Custom | See [LICENSE](LICENSE) |

---

## 📦 Quick Download

### Option 1: Ollama (Recommended)
```bash
ollama pull OmniNode/Orion:V1.0
ollama run OmniNode/Orion:V1.0
```

### Option 2: Direct Download
```bash
# Clone with Git LFS
git lfs install
git clone https://github.com/OmniNodeCo/Orion.git
```

**File:** `Orion-V1.0.gguf` (4.0 GB)  
**Format:** GGUF (llama.cpp compatible)  
**Context:** 4096 tokens  

---

## 🚀 Usage

### Ollama
```bash
ollama run OmniNode/Orion:V1.0
```

### llama.cpp / Python
```python
from llama_cpp import Llama

model = Llama(
    model_path="Orion-V1.0.gguf",
    n_ctx=4096,
    n_gpu_layers=-1
)

output = model(
    "Explain neural networks",
    max_tokens=512,
    temperature=0.7
)
print(output["choices"][0]["text"])
```

---

## 📊 Specifications

| Attribute | Value |
|-----------|-------|
| **Model** | Orion V1.0 |
| **File** | Orion-V1.0.gguf |
| **Size** | 4.0 GB |
| **Context** | 4096 tokens |
| **Parameters** | [Private] |

---

## 🔒 License Summary

- ✅ Personal use - Allowed
- ✅ Research - Allowed with attribution  
- ✅ Commercial inference - Allowed with attribution
- ❌ Fine-tuning - Requires permission
- ❌ Source code - Not available

**Full License:** See [LICENSE](LICENSE).

---

## 🤝 Contact

- **GitHub:** [OmniNodeCo/Orion](https://github.com/OmniNodeCo/Orion)
- **Ollama:** [OmniNode/Orion](https://ollama.com/OmniNode/Orion)
- **Issues:** [GitHub Issues](https://github.com/OmniNodeCo/Orion/issues)

---

> **Note:** Repository contains **only compiled model weights**. Training codebase remains private intellectual property of OmniNode.
```

```
OMNINODE ORION V1.0 MODEL WEIGHTS LICENSE
Version 1.0, 2024

Copyright (c) 2024 OmniNode
All rights reserved.

================================================================================
1. DEFINITIONS
================================================================================

"The Model" refers to the file "Orion-V1.0.gguf" distributed in the GitHub 
repository at https://github.com/OmniNodeCo/Orion.

"Source Code" refers to all training scripts, data pipelines, model architecture 
definitions, and infrastructure used to create The Model. Source Code is 
EXCLUDED from this license and remains confidential.

"Licensor" refers to OmniNode, copyright holder.

"You" refers to the individual or legal entity using The Model.

================================================================================
2. GRANTED RIGHTS
================================================================================

Subject to this license, You may:

a) Download and run The Model for inference
b) Integrate into applications with attribution (Section 6)
c) Distribute unmodified copies with this license file included
d) Fine-tune ONLY with prior written permission from Licensor

================================================================================
3. EXCLUSIONS
================================================================================

THIS LICENSE DOES NOT GRANT RIGHTS TO:
- Source Code (training scripts, architectures, datasets)
- Model checkpoints or intermediate states
- Trade secrets or training methodologies

Reverse engineering prohibited.

================================================================================
4. RESTRICTIONS
================================================================================

You MAY NOT:
- Use for illegal activities, malware, or non-consensual content
- Remove copyright notices or attribution
- Represent as Your own creation
- Use in safety-critical systems without permission
- Train competing foundation models without permission

================================================================================
5. COMMERCIAL USE
================================================================================

Commercial use (SaaS, API, paid products) permitted with attribution:
"Powered by OmniNode Orion V1.0" + link to https://github.com/OmniNodeCo/Orion

For >1000 daily users, contact for enterprise license.

================================================================================
6. ATTRIBUTION
================================================================================

Required notice:
"This uses Orion V1.0 by OmniNode (https://github.com/OmniNodeCo/Orion)"

Academic cite:
"OmniNode. (2024). Orion V1.0 [Model]. https://github.com/OmniNodeCo/Orion"

================================================================================
7. TERMINATION
================================================================================

Automatic upon breach. Cease use and destroy copies immediately.

================================================================================
8. DISCLAIMER
================================================================================

THE MODEL IS PROVIDED "AS IS" WITHOUT WARRANTY. LICENSOR NOT LIABLE FOR 
OUTPUTS, DAMAGES, OR MISUSE. MAY PRODUCE INACCURATE/BiASED CONTENT.

================================================================================
9. GOVERNING LAW
================================================================================

Governed by applicable local law.

================================================================================

BY DOWNLOADING ORION-V1.0.GGUF, YOU ACCEPT THESE TERMS.

Contact: https://github.com/OmniNodeCo/Orion/issues
```
