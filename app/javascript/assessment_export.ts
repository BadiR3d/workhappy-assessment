import { enhanceDatePickers } from "./date_picker.js";

const form = document.querySelector<HTMLFormElement>("[data-export-form]");
const feedback = document.querySelector<HTMLElement>("#export-feedback");

if (form && feedback) {
  const from = form.querySelector<HTMLInputElement>("[name='from']");
  const to = form.querySelector<HTMLInputElement>("[name='to']");
  // The server supplies today in the company's timezone, not the browser's.
  const today = from?.max;
  const syncDateLimits = (): void => {
    if (!from || !to || !today) return;
    from.max = to.value && to.value < today ? to.value : today;
    to.max = today;
    to.min = from.value && from.value <= today ? from.value : "1900-01-01";
  };
  from?.addEventListener("input", syncDateLimits);
  to?.addEventListener("input", syncDateLimits);
  syncDateLimits();
  enhanceDatePickers(form);
  form.addEventListener("submit", (event: SubmitEvent) => {
    if (from?.value && to?.value && from.value > to.value) {
      event.preventDefault();
      feedback.textContent = "End date must be on or after start date.";
      (to.parentElement?.querySelector<HTMLButtonElement>(".date-trigger") || to).focus();
      return;
    }
    const button = event.submitter;
    if (button instanceof HTMLButtonElement && button.hasAttribute("data-export-button")) {
      feedback.textContent = "Download requested. Check your browser's downloads.";
      // aria-disabled preserves the submitter's formaction during native form submission.
      if (button.getAttribute("aria-disabled") === "true") {
        event.preventDefault();
        return;
      }
      button.setAttribute("aria-disabled", "true");
      window.setTimeout(() => button.removeAttribute("aria-disabled"), 1500);
    }
  });
}
