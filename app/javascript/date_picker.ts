import { allowedDate, dateFromKey, dateKey, monthDays, moveDays, moveMonth } from "./calendar_dates.js";

export function enhanceDatePickers(form: HTMLFormElement): void {
  if (typeof HTMLDialogElement === "undefined" || !HTMLDialogElement.prototype.showModal) return;
  const inputs = Array.from(form.querySelectorAll<HTMLInputElement>(".date-control input[type=date]"));
  if (!inputs.length) return;
  // The start field's max may already be narrowed to the selected end date.
  const today = inputs.find(input => input.name === "to")?.max || inputs[0].max;
  const shortDate = new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric", timeZone: "UTC" });
  const fullDate = new Intl.DateTimeFormat("en-GB", { weekday: "long", day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  const months = Array.from({ length: 12 }, (_, index) => new Intl.DateTimeFormat("en-GB", { month: "long", timeZone: "UTC" }).format(new Date(Date.UTC(2000, index, 1))));
  const dialog = document.createElement("dialog");
  dialog.className = "calendar-dialog";
  dialog.id = "assessment-calendar";
  dialog.setAttribute("aria-labelledby", "calendar-title");
  dialog.setAttribute("aria-describedby", "calendar-help");
  dialog.innerHTML = `
    <header class="calendar-heading"><div><p class="calendar-eyebrow">Assessment date range</p><h2 id="calendar-title">Choose date</h2></div><button type="button" class="calendar-close" aria-label="Close calendar">×</button></header>
    <div class="calendar-navigation">
      <button type="button" class="calendar-nav calendar-prev" aria-label="Previous month">‹</button>
      <div class="calendar-selectors"><select class="calendar-month" aria-label="Month"></select><select class="calendar-year" aria-label="Year"></select></div>
      <button type="button" class="calendar-nav calendar-next" aria-label="Next month">›</button>
    </div>
    <p class="sr-only calendar-announcement" aria-live="polite"></p>
    <table class="calendar-grid" aria-label="Choose a day"><thead><tr>${["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map(day => `<th scope="col">${day}</th>`).join("")}</tr></thead><tbody></tbody></table>
    <p id="calendar-help" class="calendar-help">Future dates are unavailable. Use arrow keys to move between days.</p>
    <footer class="calendar-footer"><button type="button" class="calendar-clear">Clear date</button><button type="button" class="calendar-today">Today</button></footer>`;
  document.body.append(dialog);
  const monthSelect = dialog.querySelector<HTMLSelectElement>(".calendar-month")!;
  const yearSelect = dialog.querySelector<HTMLSelectElement>(".calendar-year")!;
  const previous = dialog.querySelector<HTMLButtonElement>(".calendar-prev")!;
  const next = dialog.querySelector<HTMLButtonElement>(".calendar-next")!;
  const todayButton = dialog.querySelector<HTMLButtonElement>(".calendar-today")!;
  const body = dialog.querySelector<HTMLTableSectionElement>("tbody")!;
  let active: HTMLInputElement = inputs[0];
  let focused = today;
  let visible = today;
  const triggers = new Map<HTMLInputElement, HTMLButtonElement>();
  const min = (): string => active.min || "1900-01-01";
  const max = (): string => active.max || today;
  const clamp = (key: string): string => key < min() ? min() : key > max() ? max() : key;

  const render = (focusDay = false): void => {
    const date = dateFromKey(visible);
    const year = date.getUTCFullYear();
    const month = date.getUTCMonth();
    const first = dateKey(new Date(Date.UTC(year, month, 1)));
    const last = dateKey(new Date(Date.UTC(year, month + 1, 0)));
    previous.disabled = first <= min();
    next.disabled = last >= max();
    todayButton.disabled = !allowedDate(today, min(), max());
    monthSelect.replaceChildren();
    months.forEach((name, index) => {
      const option = new Option(name, String(index), false, index === month);
      const monthFirst = dateKey(new Date(Date.UTC(year, index, 1)));
      const monthLast = dateKey(new Date(Date.UTC(year, index + 1, 0)));
      option.disabled = monthLast < min() || monthFirst > max();
      monthSelect.add(option);
    });
    yearSelect.replaceChildren();
    for (let value = Number(max().slice(0, 4)); value >= Number(min().slice(0, 4)); value--) {
      yearSelect.add(new Option(String(value), String(value), false, value === year));
    }
    dialog.querySelector(".calendar-announcement")!.textContent = `${months[month]} ${year}`;
    body.replaceChildren();
    const days = monthDays(visible);
    for (let week = 0; week < 6; week++) {
      const row = body.insertRow();
      days.slice(week * 7, week * 7 + 7).forEach(key => {
        const cell = row.insertCell();
        const button = document.createElement("button");
        button.type = "button";
        button.dataset.date = key;
        button.className = "calendar-day";
        button.textContent = String(dateFromKey(key).getUTCDate());
        button.setAttribute("aria-label", fullDate.format(dateFromKey(key)));
        button.disabled = !allowedDate(key, min(), max());
        button.tabIndex = key === focused && !button.disabled ? 0 : -1;
        if (key === active.value) { button.classList.add("is-selected"); button.setAttribute("aria-pressed", "true"); }
        if (key === today) { button.classList.add("is-today"); button.setAttribute("aria-current", "date"); }
        if (dateFromKey(key).getUTCMonth() !== month) button.classList.add("is-outside");
        const other = inputs.find(input => input !== active);
        const start = active.name === "from" ? active.value : other?.value;
        const end = active.name === "to" ? active.value : other?.value;
        if (start && end && key > start && key < end) button.classList.add("is-in-range");
        button.addEventListener("click", () => select(key));
        button.addEventListener("keydown", event => {
          const offsets: Record<string, number> = { ArrowLeft: -1, ArrowRight: 1, ArrowUp: -7, ArrowDown: 7 };
          let target: string | undefined;
          if (event.key in offsets) target = moveDays(key, offsets[event.key]);
          if (event.key === "PageUp") target = moveMonth(key, event.shiftKey ? -12 : -1);
          if (event.key === "PageDown") target = moveMonth(key, event.shiftKey ? 12 : 1);
          const weekday = (dateFromKey(key).getUTCDay() + 6) % 7;
          if (event.key === "Home") target = moveDays(key, -weekday);
          if (event.key === "End") target = moveDays(key, 6 - weekday);
          if (target) { event.preventDefault(); focused = clamp(target); visible = focused; render(true); }
        });
        cell.append(button);
      });
    }
    if (focusDay) body.querySelector<HTMLButtonElement>(`[data-date="${focused}"]`)?.focus();
  };
  const updateTrigger = (input: HTMLInputElement): void => {
    const trigger = triggers.get(input)!;
    trigger.querySelector(".date-trigger-text")!.textContent = input.value ? shortDate.format(dateFromKey(input.value)) : "Select date";
    trigger.classList.toggle("is-empty", !input.value);
    trigger.setAttribute("aria-label", `${input.name === "from" ? "From" : "To"} date${input.value ? `: ${shortDate.format(dateFromKey(input.value))}` : ": choose a date"}`);
  };
  const select = (key: string): void => {
    if (key && !allowedDate(key, min(), max())) return;
    active.value = key;
    active.dispatchEvent(new Event("input", { bubbles: true }));
    active.dispatchEvent(new Event("change", { bubbles: true }));
    updateTrigger(active);
    dialog.close();
  };
  for (const input of inputs) {
    const trigger = document.createElement("button");
    trigger.type = "button";
    trigger.className = "date-trigger";
    trigger.id = `${input.id}-picker`;
    trigger.setAttribute("aria-haspopup", "dialog");
    trigger.setAttribute("aria-controls", dialog.id);
    trigger.setAttribute("aria-expanded", "false");
    trigger.innerHTML = '<span class="date-trigger-text"></span><span class="calendar-symbol" aria-hidden="true"></span>';
    triggers.set(input, trigger);
    input.after(trigger);
    // Keep the original name/value for native GET submission; no extra filters.
    input.type = "hidden";
    input.parentElement?.querySelector("label")?.setAttribute("for", trigger.id);
    updateTrigger(input);
    trigger.addEventListener("click", () => {
      active = input;
      focused = clamp(input.value || max());
      visible = focused;
      dialog.querySelector("#calendar-title")!.textContent = input.name === "from" ? "Choose a start date" : "Choose an end date";
      trigger.setAttribute("aria-expanded", "true");
      render();
      dialog.showModal();
      render(true);
    });
  }
  previous.addEventListener("click", () => { focused = clamp(moveMonth(visible, -1)); visible = focused; render(); });
  next.addEventListener("click", () => { focused = clamp(moveMonth(visible, 1)); visible = focused; render(); });
  const changeMonth = (): void => {
    focused = clamp(dateKey(new Date(Date.UTC(Number(yearSelect.value), Number(monthSelect.value), 1))));
    visible = focused;
    render();
  };
  monthSelect.addEventListener("change", changeMonth);
  yearSelect.addEventListener("change", changeMonth);
  todayButton.addEventListener("click", () => select(today));
  dialog.querySelector(".calendar-clear")!.addEventListener("click", () => select(""));
  dialog.querySelector(".calendar-close")!.addEventListener("click", () => dialog.close());
  dialog.addEventListener("click", event => { if (event.target === dialog) dialog.close(); });
  dialog.addEventListener("close", () => { triggers.get(active)?.setAttribute("aria-expanded", "false"); triggers.get(active)?.focus(); });
}
