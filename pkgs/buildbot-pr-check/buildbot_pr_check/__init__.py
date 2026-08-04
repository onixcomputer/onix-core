"""Buildbot PR Check - Check Buildbot CI status for GitHub and Gitea pull requests."""

__version__ = "0.1.0"

from .build_status import BuildStatus, get_build_status
from .cli import check_pr, main
from .colors import Colors, colorize, use_color
from .exceptions import (
    APIError,
    BuildbotAPIError,
    BuildbotCheckError,
    GiteaAPIError,
    GitHubAPIError,
    InvalidPRURLError,
)

__all__ = [
    "APIError",
    "BuildStatus",
    "BuildbotAPIError",
    "BuildbotCheckError",
    "Colors",
    "GitHubAPIError",
    "GiteaAPIError",
    "InvalidPRURLError",
    "check_pr",
    "colorize",
    "get_build_status",
    "main",
    "use_color",
]
