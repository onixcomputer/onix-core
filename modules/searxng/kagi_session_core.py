"""Pure validation and HTML parsing for personal Kagi session searches.

Protocol and selector reference: czottmann/kagi-ken at
2d29014586a1f7fc012c4073890adc6987711d6f. No JavaScript source is copied.
"""

import re
from email.message import Message
from http import HTTPStatus
from urllib.parse import urlencode, urlsplit

from lxml import etree, html

SEARCH_ENDPOINT = "https://kagi.com/html/search"
HTTP_OK = HTTPStatus.OK
MAX_QUERY_CHARACTERS = 2048
MAX_HTML_BYTES = 2 * 1024 * 1024
MAX_RESULTS = 20
COOKIE_VALUE = re.compile(r"[A-Za-z0-9._~+/=-]+\Z")


class KagiSessionError(ValueError):
    """The session is missing, invalid, or rejected."""


class KagiPageError(ValueError):
    """The response does not match the admitted HTML search format."""


class KagiRateLimitError(KagiPageError):
    """Kagi requires a pause before another request."""


class KagiUpstreamError(KagiPageError):
    """Kagi returned a server error, not a session rejection."""


def admit_access_token(
    existing: frozenset[str], candidate: object, allowed: frozenset[str]
) -> frozenset[str] | None:
    """Add one issued token without removing other private-engine access."""
    if not isinstance(candidate, str):
        return None
    normalized = candidate.strip()
    if not normalized or normalized not in allowed:
        return None
    return existing | {normalized}


def validate_token(token: object) -> None:
    """Accept a cookie value, never a URL, header, or shell expression."""
    if not isinstance(token, str) or not COOKIE_VALUE.fullmatch(token):
        msg = "Kagi session token is missing or invalid"
        raise KagiSessionError(msg)


def search_url(query: object) -> str:
    """Construct only the fixed Kagi HTML endpoint."""
    if (
        not isinstance(query, str)
        or not query.strip()
        or len(query) > MAX_QUERY_CHARACTERS
    ):
        msg = "Kagi query is empty or exceeds the length limit"
        raise ValueError(msg)
    return SEARCH_ENDPOINT + "?" + urlencode({"q": query})


def _has_class(name: str) -> str:
    # Names are constants owned by this parser, never request input.
    return f"contains(concat(' ', normalize-space(@class), ' '), ' {name} ')"


def _text(node: html.HtmlElement) -> str:
    return " ".join(node.text_content().split())


def _result(node: html.HtmlElement, title_xpath: str) -> dict[str, str]:
    links = node.xpath(title_xpath)
    if not links:
        msg = "Kagi result title is missing"
        raise KagiPageError(msg)
    link = links[0]
    title = _text(link)
    url = link.get("href", "")
    try:
        target = urlsplit(url)
        valid_url = (
            target.scheme in ("http", "https")
            and bool(target.hostname)
            and target.username is None
            and target.password is None
            and not any(char.isspace() or ord(char) < ord(" ") for char in url)
        )
    except ValueError:
        valid_url = False
    if not title or not valid_url:
        msg = "Kagi result title or URL is invalid"
        raise KagiPageError(msg)
    descriptions = node.xpath(f".//*[{_has_class('__sri-desc')}]")
    return {
        "title": title,
        "url": url,
        "content": " ".join(_text(item) for item in descriptions),
    }


def parse_results(
    body: bytes, status: int, final_url: str, content_type: str
) -> list[dict[str, str]]:
    """Reject redirects, login pages, format drift, and unrecognized empty pages.

    An empty result set is deliberately not success: without a captured live
    empty-page fixture, it cannot be distinguished safely from an expired login.
    The byte limit bounds parsing, not the framework's HTTP receive buffer.
    """
    if status == HTTPStatus.TOO_MANY_REQUESTS:
        msg = "Kagi rate limit reached"
        raise KagiRateLimitError(msg)
    if status >= HTTPStatus.INTERNAL_SERVER_ERROR:
        msg = "Kagi returned a server error"
        raise KagiUpstreamError(msg)
    if (
        status in (HTTPStatus.UNAUTHORIZED, HTTPStatus.FORBIDDEN)
        or HTTPStatus.MULTIPLE_CHOICES <= status < HTTPStatus.BAD_REQUEST
    ):
        msg = "Kagi rejected the session search request"
        raise KagiSessionError(msg)
    if status != HTTP_OK:
        msg = "Kagi returned an unexpected HTTP status"
        raise KagiPageError(msg)
    try:
        location = urlsplit(final_url)
    except ValueError as error:
        msg = "Kagi returned an invalid endpoint"
        raise KagiSessionError(msg) from error
    if (
        location.scheme != "https"
        or location.netloc != "kagi.com"
        or location.path != "/html/search"
    ):
        msg = "Kagi returned a redirect or unexpected endpoint"
        raise KagiSessionError(msg)
    headers = Message()
    headers["content-type"] = content_type
    if headers.get_content_type() != "text/html":
        msg = "Kagi returned a non-HTML response"
        raise KagiPageError(msg)
    if not isinstance(body, bytes) or not body or len(body) > MAX_HTML_BYTES:
        msg = "Kagi HTML response is empty or exceeds the size limit"
        raise KagiPageError(msg)
    try:
        encoding = headers.get_content_charset() or "utf-8"
        document = html.fromstring(
            body, parser=html.HTMLParser(no_network=True, encoding=encoding)
        )
    except (etree.ParserError, ValueError, LookupError) as error:
        msg = "Kagi returned malformed HTML or an unsupported charset"
        raise KagiPageError(msg) from error
    if document.xpath("//input[translate(@type, 'PASSWORD', 'password')='password']"):
        msg = "Kagi returned a login page"
        raise KagiSessionError(msg)

    nodes_xpath = (
        f"//*[{_has_class('search-result')}] | "
        f"//*[{_has_class('sr-group')}]//*[{_has_class('__srgi')}]"
    )
    results = []
    seen = set()
    for node in document.xpath(nodes_xpath):
        if "search-result" in node.get("class", "").split():
            title_xpath = f".//a[{_has_class('__sri_title_link')}]"
        else:
            title_xpath = f".//*[{_has_class('__srgi-title')}]//a"
        result = _result(node, title_xpath)
        if result["url"] not in seen:
            seen.add(result["url"])
            results.append(result)
        if len(results) == MAX_RESULTS:
            return results
    if not results:
        msg = "Kagi returned no recognized results; review the session or page format"
        raise KagiPageError(msg)
    return results
