"""
Shared tool framework for claude_universe tools.

This module provides the only shared dependency between tools: a standardized
ToolResult container, logging configuration that preserves stdout for JSON output,
and a wrapped execution function that converts exceptions to ToolResult failures.
"""

import json
import logging
import os
import sys
from dataclasses import dataclass, field


@dataclass
class ToolResult:
    """Standardized result container for tool execution."""
    success: bool
    data: dict
    message: str
    alerts: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        """Return plain dict representation of the result."""
        return {
            "success": self.success,
            "data": self.data,
            "message": self.message,
            "alerts": self.alerts,
        }

    def to_json(self) -> str:
        """Return JSON string representation of the result."""
        return json.dumps(self.to_dict())


def setup_logging(name: str = "tool") -> logging.Logger:
    """
    Configure a logger that writes to stderr only.

    Stdout is reserved for ToolResult JSON output and must not be polluted.

    Args:
        name: Logger name (typically the tool module name).

    Returns:
        A configured Logger instance.
    """
    logger = logging.getLogger(name)

    # Get log level from environment; default to INFO.
    level_str = os.getenv("TOOL_LOG_LEVEL", "INFO").upper()
    logger.setLevel(getattr(logging, level_str, logging.INFO))

    # Remove any existing handlers to avoid duplicates.
    logger.handlers.clear()

    # Create stderr handler with timestamp and level.
    handler = logging.StreamHandler(sys.stderr)
    formatter = logging.Formatter(
        "[%(name)s] %(levelname)s: %(message)s"
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    # Prevent propagation to root logger.
    logger.propagate = False

    return logger


def run_tool(fn, *args, **kwargs) -> ToolResult:
    """
    Execute a tool function with exception-to-ToolResult conversion.

    If fn returns a ToolResult, it is returned as-is. If fn raises an exception,
    the traceback is logged to stderr and a ToolResult with success=False is returned.

    Args:
        fn: Callable to execute.
        *args: Positional arguments to pass to fn.
        **kwargs: Keyword arguments to pass to fn.

    Returns:
        A ToolResult instance.
    """
    try:
        result = fn(*args, **kwargs)
        if isinstance(result, ToolResult):
            return result
        # If fn returns something else, treat it as success with data.
        return ToolResult(success=True, data={"result": result}, message="OK")
    except Exception as e:
        logger = logging.getLogger("tool_base")
        logger.exception(f"Tool execution failed: {type(e).__name__}")
        return ToolResult(
            success=False,
            data={},
            message=f"{type(e).__name__}: {e}",
            alerts=[],
        )
