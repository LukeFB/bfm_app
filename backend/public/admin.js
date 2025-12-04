const apiBase = "/api";
const tokenKey = "bfm_admin_token";

const els = {
  loginSection: document.getElementById("loginSection"),
  adminSection: document.getElementById("adminSection"),
  loginForm: document.getElementById("loginForm"),
  authStatus: document.getElementById("authStatus"),
  logoutBtn: document.getElementById("logoutBtn"),
  statusLog: document.getElementById("statusLog"),
  tabs: document.querySelectorAll(".tabs button"),
  tabPanels: document.querySelectorAll(".tab"),
  referralForm: document.getElementById("referralForm"),
  referralList: document.getElementById("referralList"),
  refreshReferrals: document.getElementById("refreshReferrals"),
  clearReferralForm: document.getElementById("clearReferralForm"),
  deleteReferral: document.getElementById("deleteReferral"),
  referralCsvForm: document.getElementById("referralCsvForm"),
  tipForm: document.getElementById("tipForm"),
  tipList: document.getElementById("tipList"),
  refreshTips: document.getElementById("refreshTips"),
  clearTipForm: document.getElementById("clearTipForm"),
  deleteTip: document.getElementById("deleteTip"),
  eventForm: document.getElementById("eventForm"),
  eventList: document.getElementById("eventList"),
  refreshEvents: document.getElementById("refreshEvents"),
  clearEventForm: document.getElementById("clearEventForm"),
  deleteEvent: document.getElementById("deleteEvent"),
};

const state = {
  token: localStorage.getItem(tokenKey),
  referrals: [],
  tips: [],
  events: [],
};

const toast = (message, type = "info") => {
  const entry = document.createElement("div");
  entry.className = "status-entry";
  entry.textContent = `${new Date().toLocaleTimeString()} • ${message}`;
  if (type === "error") {
    entry.style.background = "#fee2e2";
    entry.style.color = "#b91c1c";
  } else if (type === "success") {
    entry.style.background = "#ecfdf5";
    entry.style.color = "#047857";
  }
  els.statusLog.prepend(entry);
  while (els.statusLog.children.length > 50) {
    els.statusLog.lastChild.remove();
  }
};

const setAuthState = (isAuthed) => {
  if (isAuthed) {
    els.loginSection.classList.add("hidden");
    els.adminSection.classList.remove("hidden");
    els.logoutBtn.classList.remove("hidden");
    els.authStatus.classList.remove("badge-danger");
    els.authStatus.classList.add("badge-success");
    els.authStatus.textContent = "Signed in";
  } else {
    els.loginSection.classList.remove("hidden");
    els.adminSection.classList.add("hidden");
    els.logoutBtn.classList.add("hidden");
    els.authStatus.classList.remove("badge-success");
    els.authStatus.classList.add("badge-danger");
    els.authStatus.textContent = "Signed out";
  }
};

const apiFetch = async (path, options = {}) => {
  const { method = "GET", body, headers = {}, raw } = options;
  const finalHeaders = new Headers(headers);
  const opts = { method, headers: finalHeaders };

  if (state.token) {
    finalHeaders.set("Authorization", `Bearer ${state.token}`);
  }

  if (body instanceof FormData) {
    opts.body = body;
  } else if (body) {
    finalHeaders.set("Content-Type", "application/json");
    opts.body = JSON.stringify(body);
  }

  const res = await fetch(`${apiBase}${path}`, opts);
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(detail || `Request failed (${res.status})`);
  }
  if (raw) return res;
  const text = await res.text();
  try {
    return text ? JSON.parse(text) : null;
  } catch {
    return text;
  }
};

const serializeForm = (form) => {
  const data = new FormData(form);
  const obj = {};
  for (const [key, value] of data.entries()) {
    if (value === "" || value === null) continue;
    obj[key] = value;
  }
  return obj;
};

// ----------------------
// Login / logout
// ----------------------

els.loginForm.addEventListener("submit", async (evt) => {
  evt.preventDefault();
  const formData = serializeForm(evt.currentTarget);
  try {
    const payload = await apiFetch("/auth/login", {
      method: "POST",
      body: formData,
    });
    state.token = payload.token;
    localStorage.setItem(tokenKey, payload.token);
    toast("Login successful", "success");
    setAuthState(true);
    await Promise.all([loadReferrals(), loadTips(), loadEvents()]);
  } catch (err) {
    toast(`Login failed: ${err.message}`, "error");
  }
});

els.logoutBtn.addEventListener("click", () => {
  state.token = null;
  localStorage.removeItem(tokenKey);
  setAuthState(false);
  toast("Signed out", "success");
});

// ----------------------
// Tabs
// ----------------------
els.tabs.forEach((btn) => {
  btn.addEventListener("click", () => {
    const tab = btn.dataset.tab;
    els.tabs.forEach((b) => b.classList.toggle("active", b === btn));
    els.tabPanels.forEach((panel) =>
      panel.classList.toggle("active", panel.id === tab),
    );
  });
});

// ----------------------
// Referrals
// ----------------------
const renderReferrals = () => {
  els.referralList.innerHTML = "";
  if (!state.referrals.length) {
    els.referralList.innerHTML =
      '<p class="hint">No referrals yet. Add one above or upload a CSV.</p>';
    return;
  }
  state.referrals.forEach((ref) => {
    const div = document.createElement("div");
    div.className = "list-item";
    div.innerHTML = `
      <h4>${ref.organisationName ?? "Unnamed"} <small>${ref.category ?? "General"}</small></h4>
      <small>${ref.region ?? "Region unknown"} • ${
        ref.isActive ? "Active" : "Hidden"
      }</small>
      <p>${ref.services ?? ""}</p>
      <button data-id="${ref.id}">Edit</button>
    `;
    div.querySelector("button").addEventListener("click", () =>
      populateReferralForm(ref),
    );
    els.referralList.appendChild(div);
  });
};

const populateReferralForm = (ref) => {
  const form = els.referralForm;
  Object.entries(ref).forEach(([key, value]) => {
    if (form.elements.namedItem(key)) {
      form.elements.namedItem(key).value =
        value === null || value === undefined ? "" : value;
    }
  });
  form.elements.namedItem("isActive").value = ref.isActive ? "true" : "false";
};

const clearReferralForm = () => {
  els.referralForm.reset();
  els.referralForm.elements.namedItem("id").value = "";
};

const loadReferrals = async () => {
  try {
    const data = await apiFetch("/referrals?limit=100");
    state.referrals = data;
    renderReferrals();
    toast("Referrals refreshed", "success");
  } catch (err) {
    toast(`Unable to load referrals: ${err.message}`, "error");
  }
};

els.referralForm.addEventListener("submit", async (evt) => {
  evt.preventDefault();
  const formData = serializeForm(els.referralForm);
  formData.isActive = formData.isActive !== "false";
  const id = formData.id;
  delete formData.id;
  try {
    if (id) {
      await apiFetch(`/referrals/${id}`, { method: "PUT", body: formData });
      toast("Referral updated", "success");
    } else {
      await apiFetch("/referrals", { method: "POST", body: formData });
      toast("Referral created", "success");
    }
    clearReferralForm();
    await loadReferrals();
  } catch (err) {
    toast(`Referral save failed: ${err.message}`, "error");
  }
});

els.deleteReferral.addEventListener("click", async () => {
  const id = els.referralForm.elements.namedItem("id").value;
  if (!id) {
    toast("Select a referral to delete", "error");
    return;
  }
  if (!confirm("Delete this referral?")) return;
  try {
    await apiFetch(`/referrals/${id}`, { method: "DELETE" });
    toast("Referral deleted", "success");
    clearReferralForm();
    await loadReferrals();
  } catch (err) {
    toast(`Delete failed: ${err.message}`, "error");
  }
});

els.referralCsvForm.addEventListener("submit", async (evt) => {
  evt.preventDefault();
  const fileInput = evt.currentTarget.querySelector('input[name="file"]');
  if (!fileInput.files.length) {
    toast("Select a CSV file first", "error");
    return;
  }
  const formData = new FormData();
  formData.append("file", fileInput.files[0]);
  try {
    await apiFetch("/referrals/import", { method: "POST", body: formData });
    toast("CSV import complete", "success");
    fileInput.value = "";
    await loadReferrals();
  } catch (err) {
    toast(`CSV upload failed: ${err.message}`, "error");
  }
});

els.refreshReferrals.addEventListener("click", loadReferrals);
els.clearReferralForm.addEventListener("click", clearReferralForm);

// ----------------------
// Tips
// ----------------------
const renderTips = () => {
  els.tipList.innerHTML = "";
  if (!state.tips.length) {
    els.tipList.innerHTML = '<p class="hint">No tips created yet.</p>';
    return;
  }
  state.tips.forEach((tip) => {
    const div = document.createElement("div");
    div.className = "list-item";
    const finish = tip.expiresAt
      ? new Date(tip.expiresAt).toLocaleDateString()
      : "No date";
    div.innerHTML = `
      <h4>${tip.title}</h4>
      <small>Finishes ${finish}</small>
      <button data-id="${tip.id}">Edit</button>
    `;
    div.querySelector("button").addEventListener("click", () =>
      populateTipForm(tip),
    );
    els.tipList.appendChild(div);
  });
};

const populateTipForm = (tip) => {
  const form = els.tipForm;
  Object.entries(tip).forEach(([key, value]) => {
    if (!form.elements.namedItem(key)) return;
    let next = value;
    if (key === "expiresAt" && value) {
      next = new Date(value).toISOString().slice(0, 16);
    }
    form.elements.namedItem(key).value =
      next === null || next === undefined ? "" : next;
  });
};

const clearTipForm = () => {
  els.tipForm.reset();
  els.tipForm.elements.namedItem("id").value = "";
};

const loadTips = async () => {
  try {
    const data = await apiFetch("/tips?limit=20");
    state.tips = data;
    renderTips();
    toast("Tips refreshed", "success");
  } catch (err) {
    toast(`Unable to load tips: ${err.message}`, "error");
  }
};

els.tipForm.addEventListener("submit", async (evt) => {
  evt.preventDefault();
  const formData = serializeForm(els.tipForm);
  if (formData.expiresAt) {
    formData.expiresAt = new Date(formData.expiresAt).toISOString();
  }
  const id = formData.id;
  delete formData.id;
  try {
    if (id) {
      await apiFetch(`/tips/${id}`, { method: "PUT", body: formData });
      toast("Tip updated", "success");
    } else {
      await apiFetch("/tips", { method: "POST", body: formData });
      toast("Tip created", "success");
    }
    clearTipForm();
    await loadTips();
  } catch (err) {
    toast(`Tip save failed: ${err.message}`, "error");
  }
});

els.deleteTip.addEventListener("click", async () => {
  const id = els.tipForm.elements.namedItem("id").value;
  if (!id) {
    toast("Select a tip to delete", "error");
    return;
  }
  if (!confirm("Delete this tip?")) return;
  try {
    await apiFetch(`/tips/${id}`, { method: "DELETE" });
    toast("Tip deleted", "success");
    clearTipForm();
    await loadTips();
  } catch (err) {
    toast(`Delete failed: ${err.message}`, "error");
  }
});

els.refreshTips.addEventListener("click", loadTips);
els.clearTipForm.addEventListener("click", clearTipForm);

// ----------------------
// Events
// ----------------------
const renderEvents = () => {
  els.eventList.innerHTML = "";
  if (!state.events.length) {
    els.eventList.innerHTML = '<p class="hint">No events scheduled.</p>';
    return;
  }
  state.events.forEach((event) => {
    const div = document.createElement("div");
    div.className = "list-item";
    const finish = event.endDate
      ? new Date(event.endDate).toLocaleString()
      : "No date";
    div.innerHTML = `
      <h4>${event.title}</h4>
      <small>Finishes ${finish}</small>
      <button data-id="${event.id}">Edit</button>
    `;
    div.querySelector("button").addEventListener("click", () =>
      populateEventForm(event),
    );
    els.eventList.appendChild(div);
  });
};

const populateEventForm = (event) => {
  const form = els.eventForm;
  Object.entries(event).forEach(([key, value]) => {
    const input = form.elements.namedItem(key);
    if (!input) return;
    let next = value;
    if (value === null || value === undefined) next = "";
    if (key === "endDate" && value) {
      next = new Date(value).toISOString().slice(0, 16);
    }
    input.value = next;
  });
};

const clearEventForm = () => {
  els.eventForm.reset();
  els.eventForm.elements.namedItem("id").value = "";
};

const loadEvents = async () => {
  try {
    const data = await apiFetch("/events?limit=20&upcomingOnly=false");
    state.events = data;
    renderEvents();
    toast("Events refreshed", "success");
  } catch (err) {
    toast(`Unable to load events: ${err.message}`, "error");
  }
};

els.eventForm.addEventListener("submit", async (evt) => {
  evt.preventDefault();
  const formData = serializeForm(els.eventForm);
  if (formData.endDate) {
    formData.endDate = new Date(formData.endDate).toISOString();
  }
  const id = formData.id;
  delete formData.id;
  try {
    if (id) {
      await apiFetch(`/events/${id}`, { method: "PUT", body: formData });
      toast("Event updated", "success");
    } else {
      await apiFetch("/events", { method: "POST", body: formData });
      toast("Event created", "success");
    }
    clearEventForm();
    await loadEvents();
  } catch (err) {
    toast(`Event save failed: ${err.message}`, "error");
  }
});

els.deleteEvent.addEventListener("click", async () => {
  const id = els.eventForm.elements.namedItem("id").value;
  if (!id) {
    toast("Select an event to delete", "error");
    return;
  }
  if (!confirm("Delete this event?")) return;
  try {
    await apiFetch(`/events/${id}`, { method: "DELETE" });
    toast("Event deleted", "success");
    clearEventForm();
    await loadEvents();
  } catch (err) {
    toast(`Delete failed: ${err.message}`, "error");
  }
});

els.refreshEvents.addEventListener("click", loadEvents);
els.clearEventForm.addEventListener("click", clearEventForm);

// ----------------------
// Initial load
// ----------------------
if (state.token) {
  setAuthState(true);
  Promise.all([loadReferrals(), loadTips(), loadEvents()]).catch((err) =>
    toast(`Initial load failed: ${err.message}`, "error"),
  );
} else {
  setAuthState(false);
}

