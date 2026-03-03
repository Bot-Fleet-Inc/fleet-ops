"""Hybrid LLM inference library for the AI bot fleet.

Provides the InferenceClient that routes between local LLM (Nvidia A10)
and Anthropic Claude API based on task complexity.

Quick start:
    from shared.inference import InferenceClient

    client = InferenceClient()
    result = client.infer("Summarize this issue", complexity="low")
"""

from shared.inference.client import InferenceClient

__all__ = ["InferenceClient"]
