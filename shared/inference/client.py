"""Hybrid LLM inference client for the AI bot fleet.

Routes inference requests between local LLM (vLLM/Ollama on the Nvidia A10
GPU server) and Anthropic Claude API based on task complexity.

Routing strategy:
    - low complexity  -> Local LLM (fast, free, good for triage/classification)
    - medium complexity -> Claude Sonnet (balanced cost/quality for analysis)
    - high complexity  -> Claude Opus (complex multi-step reasoning)

Fallback: If the local LLM is unreachable, all requests route to Claude.

Requirements:
    - Local LLM: OpenAI-compatible API at LOCAL_LLM_URL (no dependencies)
    - Claude API: anthropic SDK (`pip install anthropic`)

Usage:
    from shared.inference.client import InferenceClient

    client = InferenceClient()
    result = client.infer("Classify this issue as bug or feature", complexity="low")
"""

import json
import logging
import os
import time
import urllib.error
import urllib.request

logger = logging.getLogger(__name__)

# Defaults
LOCAL_LLM_URL = os.environ.get("LOCAL_LLM_URL", "http://172.16.11.10:8000")
# Use ANTHROPIC_INFERENCE_KEY (preferred) to avoid conflicting with Claude Code CLI,
# which will use ANTHROPIC_API_KEY instead of the Max subscription if that var is set.
ANTHROPIC_API_KEY = os.environ.get(
    "ANTHROPIC_INFERENCE_KEY", os.environ.get("ANTHROPIC_API_KEY", "")
)

# Claude model identifiers
CLAUDE_SONNET = "claude-sonnet-4-20250514"
CLAUDE_OPUS = "claude-opus-4-20250514"

# Complexity -> model mapping
COMPLEXITY_MAP = {
    "low": "local",
    "medium": CLAUDE_SONNET,
    "high": CLAUDE_OPUS,
}

# Local LLM request timeout (seconds)
LOCAL_TIMEOUT = 60

# Claude API request timeout (seconds)
CLAUDE_TIMEOUT = 120


class InferenceClient:
    """Hybrid inference client routing between local LLM and Claude API.

    Attributes:
        local_url: Base URL for the local LLM (OpenAI-compatible API).
        api_key: Anthropic API key for Claude requests.
        _local_available: Cached local LLM availability (None = unchecked).
    """

    def __init__(
        self,
        local_url: str | None = None,
        api_key: str | None = None,
    ):
        """Initialize the inference client.

        Args:
            local_url: Base URL for local LLM. Defaults to LOCAL_LLM_URL env var
                       or http://172.16.11.10:8000.
            api_key: Anthropic API key. Defaults to ANTHROPIC_API_KEY env var.
        """
        self.local_url = (local_url or LOCAL_LLM_URL).rstrip("/")
        self.api_key = api_key or ANTHROPIC_API_KEY
        self._local_available: bool | None = None
        self._anthropic_client = None

    def infer(
        self,
        prompt: str,
        complexity: str = "low",
        system: str | None = None,
    ) -> str:
        """Route an inference request based on complexity.

        Args:
            prompt: The user/task prompt.
            complexity: One of "low", "medium", "high".
                - low: Local LLM (triage, classification, summarization).
                - medium: Claude Sonnet (code review, analysis).
                - high: Claude Opus (complex multi-step reasoning).
            system: Optional system prompt for context/instructions.

        Returns:
            The model's response text.

        Raises:
            ValueError: If complexity is not a valid level.
            RuntimeError: If no inference backend is available.
        """
        if complexity not in COMPLEXITY_MAP:
            raise ValueError(
                f"Invalid complexity '{complexity}'. Must be one of: {list(COMPLEXITY_MAP.keys())}"
            )

        target = COMPLEXITY_MAP[complexity]
        start_time = time.time()

        # Route to local LLM for low complexity
        if target == "local":
            try:
                result = self._local_infer(prompt, system=system)
                elapsed = time.time() - start_time
                logger.info(
                    "Local LLM inference completed in %.2fs (complexity=%s)",
                    elapsed,
                    complexity,
                )
                return result
            except Exception as exc:
                logger.warning(
                    "Local LLM unavailable (%s), falling back to Claude Sonnet",
                    exc,
                )
                self._local_available = False
                target = CLAUDE_SONNET

        # Route to Claude API
        try:
            result = self._claude_infer(prompt, model=target, system=system)
            elapsed = time.time() - start_time
            logger.info(
                "Claude inference completed in %.2fs (model=%s, complexity=%s)",
                elapsed,
                target,
                complexity,
            )
            return result
        except Exception as exc:
            logger.error("Claude API call failed: %s", exc)
            raise RuntimeError(f"Inference failed for complexity={complexity}: {exc}") from exc

    def _local_infer(self, prompt: str, system: str | None = None) -> str:
        """Call the local LLM via OpenAI-compatible /v1/chat/completions.

        Uses only stdlib urllib (no external dependencies required).

        Args:
            prompt: The user prompt.
            system: Optional system prompt.

        Returns:
            The assistant's response text.

        Raises:
            urllib.error.URLError: If the local LLM is unreachable.
            KeyError: If the response format is unexpected.
        """
        url = f"{self.local_url}/v1/chat/completions"

        messages = []
        if system:
            messages.append({"role": "system", "content": system})
        messages.append({"role": "user", "content": prompt})

        payload = {
            "messages": messages,
            "temperature": 0.2,
            "max_tokens": 4096,
        }

        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=data,
            headers={
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method="POST",
        )

        logger.debug("POST %s (payload: %d bytes)", url, len(data))

        try:
            with urllib.request.urlopen(req, timeout=LOCAL_TIMEOUT) as resp:
                body = json.loads(resp.read().decode("utf-8"))
        except urllib.error.URLError as exc:
            logger.error("Local LLM unreachable at %s: %s", url, exc)
            raise
        except json.JSONDecodeError as exc:
            logger.error("Invalid JSON from local LLM: %s", exc)
            raise

        # Parse OpenAI-compatible response
        try:
            content = body["choices"][0]["message"]["content"]
        except (KeyError, IndexError) as exc:
            logger.error("Unexpected response format from local LLM: %s", body)
            raise KeyError(f"Could not extract content from local LLM response: {body}") from exc

        # Log usage if available
        usage = body.get("usage", {})
        if usage:
            logger.info(
                "Local LLM usage: prompt_tokens=%s, completion_tokens=%s",
                usage.get("prompt_tokens", "?"),
                usage.get("completion_tokens", "?"),
            )

        self._local_available = True
        return content

    def _claude_infer(
        self,
        prompt: str,
        model: str,
        system: str | None = None,
    ) -> str:
        """Call Claude API via the Anthropic SDK.

        Requires the anthropic package to be installed.

        Args:
            prompt: The user prompt.
            model: Claude model identifier (e.g. claude-sonnet-4-20250514).
            system: Optional system prompt.

        Returns:
            The assistant's response text.

        Raises:
            ImportError: If the anthropic package is not installed.
            RuntimeError: If the API key is not configured.
            anthropic.APIError: On API errors.
        """
        if not self.api_key:
            raise RuntimeError(
                "ANTHROPIC_API_KEY not set. Cannot make Claude API calls. "
                "Set the environment variable or pass api_key to InferenceClient."
            )

        # Lazy import to avoid hard dependency on anthropic SDK
        if self._anthropic_client is None:
            try:
                import anthropic
            except ImportError as exc:
                raise ImportError(
                    "The anthropic package is required for Claude API calls. "
                    "Install it with: pip install anthropic"
                ) from exc
            self._anthropic_client = anthropic.Anthropic(
                api_key=self.api_key,
                timeout=CLAUDE_TIMEOUT,
            )

        logger.debug("Calling Claude API (model=%s)", model)

        kwargs = {
            "model": model,
            "max_tokens": 4096,
            "messages": [{"role": "user", "content": prompt}],
        }
        if system:
            kwargs["system"] = system

        response = self._anthropic_client.messages.create(**kwargs)

        # Extract text from response
        content = ""
        for block in response.content:
            if block.type == "text":
                content += block.text

        # Log usage for cost tracking
        if response.usage:
            logger.info(
                "Claude usage (model=%s): input_tokens=%d, output_tokens=%d",
                model,
                response.usage.input_tokens,
                response.usage.output_tokens,
            )

        return content

    def health_check(self) -> dict:
        """Check reachability of inference backends.

        Returns:
            Dict with status of each backend:
            {
                "local_llm": {"available": bool, "url": str, "error": str|None},
                "claude_api": {"available": bool, "key_configured": bool, "error": str|None},
            }
        """
        result = {
            "local_llm": {
                "available": False,
                "url": self.local_url,
                "error": None,
            },
            "claude_api": {
                "available": False,
                "key_configured": bool(self.api_key),
                "error": None,
            },
        }

        # Check local LLM — hit the /v1/models endpoint
        try:
            url = f"{self.local_url}/v1/models"
            req = urllib.request.Request(url, method="GET")
            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    result["local_llm"]["available"] = True
                    self._local_available = True
        except Exception as exc:
            result["local_llm"]["error"] = str(exc)
            self._local_available = False

        # Check Claude API — verify key with a minimal request
        if self.api_key:
            try:
                import anthropic

                client = anthropic.Anthropic(api_key=self.api_key, timeout=10)
                # Use a minimal message to verify connectivity
                client.messages.create(
                    model=CLAUDE_SONNET,
                    max_tokens=1,
                    messages=[{"role": "user", "content": "ping"}],
                )
                result["claude_api"]["available"] = True
            except ImportError:
                result["claude_api"]["error"] = "anthropic package not installed"
            except Exception as exc:
                result["claude_api"]["error"] = str(exc)
        else:
            result["claude_api"]["error"] = "ANTHROPIC_API_KEY not configured"

        return result
