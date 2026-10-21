(() => {
  "use strict";
  const form = document.querySelector("#kagi-access-status form");
  if (!form || typeof fetch !== "function") return;
  const button = form.querySelector("button[type=submit]");
  const feedback = document.querySelector("#kagi-unlock-feedback");
  const UNLOCK_TIMEOUT_MS = 10000;
  let pending = false;

  async function unlock(event) {
    event.preventDefault();
    if (pending) return;
    pending = true;
    button.disabled = true;
    feedback.textContent = "Checking engine access…";
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), UNLOCK_TIMEOUT_MS);
    try {
      const body = new URLSearchParams({
        kagi_engine_token: form.querySelector("[name=kagi_engine_token]").value,
        kagi_form_nonce: form.querySelector("[name=kagi_form_nonce]").value,
      });
      const response = await fetch(form.getAttribute("action"), {
        method: "POST",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: body.toString(),
        signal: controller.signal,
      });
      if (!response.ok) throw new Error("Unlock request rejected");
      const result = await response.json();
      if (result.outcome !== "saved" && result.outcome !== "rejected") {
        throw new Error("Unexpected unlock response");
      }
      const target = new URL(
        form.getAttribute("data-preferences-url"),
        location.href,
      );
      target.searchParams.set("kagi_unlock", result.outcome);
      location.assign(target.href);
    } catch {
      feedback.textContent =
        "Unlock failed. Reload Preferences and try again. This form requires cookies.";
    } finally {
      clearTimeout(timer);
      pending = false;
      button.disabled = false;
    }
  }
  form.addEventListener("submit", unlock);
  button.addEventListener("click", unlock);
})();
