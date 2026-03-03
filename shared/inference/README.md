# Inference Client Library

Hybrid LLM routing client for the AI bot fleet. Routes inference requests between the local LLM (Nvidia A10 GPU on VLAN 1011) and the Anthropic Claude API based on task complexity.

## Architecture

```
Bot VM (VLAN 1010)                    LLM Inference VM (VLAN 1011)
+-----------------+                   +-------------------------+
| InferenceClient |---low complexity->| vLLM / Ollama           |
|                 |                   | http://172.16.11.10:8000|
|  complexity:    |                   | Nvidia A10 (24GB VRAM)  |
|  - low -> local |                   +-------------------------+
|  - medium -> API|
|  - high -> API  |---med/high------> Anthropic Claude API
+-----------------+                    (claude.ai)
```

## Model Routing Strategy

| Complexity | Target | Model | Use Cases | Cost |
|------------|--------|-------|-----------|------|
| `low` | Local LLM | ~13B params (Llama/Mistral) | Triage, classification, label extraction, summarization, simple Q&A | Free (on-prem GPU) |
| `medium` | Claude API | Claude Sonnet | Code review, analysis, structured reasoning, documentation generation | ~$3/M input, $15/M output |
| `high` | Claude API | Claude Opus | Complex multi-step reasoning, architecture decisions, cross-repo analysis | ~$15/M input, $75/M output |

### When to Use Each Level

**Low (Local LLM):**
- Classifying an issue as bug/feature/task
- Extracting labels from issue text
- Summarizing a PR diff
- Simple templated responses
- Health check / status generation

**Medium (Claude Sonnet):**
- Code review with contextual analysis
- Writing issue bodies with detailed analysis
- Reviewing architecture compliance
- Generating structured documentation
- Multi-file code analysis

**High (Claude Opus):**
- Complex reasoning about system architecture
- Multi-step decision chains (e.g., "should we split this microservice?")
- Cross-repository impact analysis
- Conflict resolution between competing approaches
- Enterprise architecture model updates

## Fallback Behavior

If the local LLM is unreachable (network issue, VM down, GPU error):

1. The client logs a warning
2. `low` complexity requests are automatically routed to Claude Sonnet
3. The `_local_available` flag is set to `False`
4. Subsequent `health_check()` calls will re-test local availability

This ensures bots never block on a local LLM outage.

## Requirements

- **Python 3.10+**
- **stdlib only** for local LLM calls (uses `urllib.request`)
- **anthropic SDK** for Claude API calls (`pip install anthropic`)

## Usage

### Basic inference

```python
from shared.inference import InferenceClient

client = InferenceClient()

# Low complexity — routes to local LLM
label = client.infer(
    "Classify this issue: 'Login page returns 500 error'",
    complexity="low",
    system="Respond with exactly one word: bug, feature, or task."
)

# Medium complexity — routes to Claude Sonnet
review = client.infer(
    f"Review this code change:\n{diff}",
    complexity="medium",
    system="You are a senior code reviewer. Focus on correctness and security."
)

# High complexity — routes to Claude Opus
decision = client.infer(
    f"Analyze the impact of splitting the auth service:\n{context}",
    complexity="high",
    system="You are an enterprise architect. Consider all downstream dependencies."
)
```

### Health check

```python
client = InferenceClient()
status = client.health_check()
print(status)
# {
#     "local_llm": {"available": True, "url": "http://172.16.11.10:8000", "error": None},
#     "claude_api": {"available": True, "key_configured": True, "error": None}
# }
```

### Custom configuration

```python
# Use a different local LLM endpoint
client = InferenceClient(local_url="http://192.168.1.100:11434")

# Override API key
client = InferenceClient(api_key="sk-ant-...")
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOCAL_LLM_URL` | `http://172.16.11.10:8000` | Base URL for the local LLM (OpenAI-compatible API) |
| `ANTHROPIC_API_KEY` | (none) | Anthropic API key for Claude requests |

## Cost Tracking

The client logs token usage for every inference call:

```
INFO: Local LLM usage: prompt_tokens=142, completion_tokens=3
INFO: Claude usage (model=claude-sonnet-4-20250514): input_tokens=2048, output_tokens=512
```

Use these logs to monitor API costs and optimize routing thresholds. A future enhancement could track cumulative costs per bot per day.

## Network Requirements

- Bot VMs (VLAN 1010) must be able to reach the LLM inference VM (VLAN 1011) on port 8000
- Bot VMs must be able to reach the Anthropic API via the Cloudflare Tunnel (VMID 400)
- Firewall rules for cross-VLAN traffic are defined in `infra/networking/vlan-design.md`
