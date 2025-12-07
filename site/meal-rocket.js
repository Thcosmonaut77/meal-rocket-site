/********************************************
 Meal Rocket — Modern Frontend JavaScript (deploy-ready)
 - Accessible modal
 - Mobile nav with aria + body lock
 - IntersectionObserver active nav
 - Reservation form submit to API (fetch)
 - Ingredients data included
 - Build-time placeholders: __API_ENDPOINT__, __WHATSAPP__ 
********************************************/

/* ========== Configuration (build-time placeholders) ========== */
// Build step should replace __API_ENDPOINT__ and __WHATSAPP__ with real values.
// Example replacement: sed -i "s|__API_ENDPOINT__|https://abcd1234.execute-api.../book|g" tooplate-bistro-scripts.js
const API_ENDPOINT = '__API_ENDPOINT__'; // e.g. https://abc.execute-api.region.amazonaws.com/book
const WHATSAPP_NUMBER = '__WHATSAPP__';  // e.g. +2348100001234

/* ========== Utilities ========== */
const $ = (sel, ctx = document) => ctx.querySelector(sel);
const $$ = (sel, ctx = document) => Array.from(ctx.querySelectorAll(sel));

function lockBodyScroll() {
  document.documentElement.style.overflow = 'hidden';
  document.body.style.overflow = 'hidden';
}
function unlockBodyScroll() {
  document.documentElement.style.overflow = '';
  document.body.style.overflow = '';
}

function showStatusMessage(container, type, message) {
  if (!container) { alert(message); return; }
  let el = container.querySelector('.status-message');
  if (!el) {
    el = document.createElement('div');
    el.className = 'status-message';
    container.prepend(el);
  }
  el.className = 'status-message ' + type;
  el.textContent = message;
  if (type === 'success') setTimeout(() => el && el.remove(), 6000);
}

function safeText(str) {
  const d = document.createElement('div');
  d.textContent = String(str ?? '');
  return d.innerHTML;
}

/* ========== Ingredients data (populate with site menu) ==========
   This ensures existing inline dish ids like "jollof-deluxe" work.
===========================================*/
window.ingredientsData = {
  'jollof-deluxe': {
    title: 'Party Jollof Deluxe',
    ingredients: [
      { name: 'Long grain rice', allergen: false },
      { name: 'Tomato base', allergen: false },
      { name: 'Grilled chicken', allergen: false },
      { name: 'Plantain', allergen: false },
      { name: 'Seasoning', allergen: false }
    ]
  },
  'grilled-chicken': {
    title: 'Grilled Chicken Platter',
    ingredients: [
      { name: 'Chicken (marinated)', allergen: false },
      { name: 'Pepper sauce', allergen: false },
      { name: 'Sides', allergen: false }
    ]
  },
  'finger-foods': {
    title: 'Premium Finger Foods',
    ingredients: [
      { name: 'Spring rolls', allergen: true },
      { name: 'Mini burgers', allergen: false },
      { name: 'Chicken skewers', allergen: false }
    ]
  }
};

/* ========== Mobile Navigation ========== */
(function initMobileNav() {
  const menuToggle = $('.menu-toggle');
  const navLinks = $('.nav-links') || $('.nav-menu');
  if (!menuToggle || !navLinks) return;

  menuToggle.setAttribute('aria-controls', navLinks.id || 'nav-links');
  menuToggle.setAttribute('aria-expanded', 'false');

  function openMenu() {
    navLinks.classList.add('active', 'open');
    menuToggle.setAttribute('aria-expanded', 'true');
    lockBodyScroll();
  }
  function closeMenu() {
    navLinks.classList.remove('active', 'open');
    menuToggle.setAttribute('aria-expanded', 'false');
    unlockBodyScroll();
  }

  menuToggle.addEventListener('click', () => {
    const expanded = menuToggle.getAttribute('aria-expanded') === 'true';
    if (expanded) closeMenu(); else openMenu();
  });

  navLinks.addEventListener('click', (e) => {
    const a = e.target.closest('a[href^="#"]');
    if (a) closeMenu();
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeMenu();
  });
})();

/* ========== Smooth scroll & active nav (IntersectionObserver) ========== */
(function initSmoothScrollAndActiveNav() {
  const navLinks = $$('.nav-links a[href^="#"]');
  const sections = navLinks.map(a => document.querySelector(a.getAttribute('href'))).filter(Boolean);
  navLinks.forEach(a => {
    a.addEventListener('click', function (e) {
      const href = this.getAttribute('href');
      const target = document.querySelector(href);
      if (!target) return;
      e.preventDefault();
      const nav = document.querySelector('nav');
      const navHeight = nav ? nav.offsetHeight : 0;
      const top = target.getBoundingClientRect().top + window.scrollY - navHeight - 8;
      window.scrollTo({ top, behavior: 'smooth' });
    });
  });

  if (sections.length === 0) return;
  const observerOptions = { root: null, rootMargin: `-18% 0px -60% 0px`, threshold: 0 };
  const io = new IntersectionObserver((entries) => {
    entries.forEach(entry => {
      const id = entry.target.id;
      const link = document.querySelector(`.nav-links a[href="#${id}"]`);
      if (!link) return;
      if (entry.isIntersecting) {
        $$('.nav-links a').forEach(a => a.classList.remove('active'));
        link.classList.add('active');
      }
    });
  }, observerOptions);
  sections.forEach(sec => io.observe(sec));
})();

/* ========== Accessible Modal (ingredients) ========== */
(function initModal() {
  const modal = $('#ingredientsModal');
  if (!modal) return;
  const dialog = modal.querySelector('.modal-content') || modal.querySelector('div');
  const titleEl = $('#modalTitle');
  const listEl = $('#ingredientsList');

  modal.setAttribute('role', 'dialog');
  modal.setAttribute('aria-modal', 'true');
  modal.setAttribute('aria-hidden', 'true');
  if (titleEl) dialog.setAttribute('aria-labelledby', 'modalTitle');

  let lastFocused = null;

  function openModal(data) {
    lastFocused = document.activeElement;
    if (titleEl) titleEl.textContent = safeText(data.title || 'Details');
    if (listEl) {
      listEl.innerHTML = '';
      (data.ingredients || []).forEach(it => {
        const li = document.createElement('li');
        li.className = 'ingredient-line';
        li.innerHTML = `<span class="ingredient-name">${safeText(it.name)}</span>
                        ${it.allergen ? '<span class="allergen">Allergen</span>' : ''}`;
        listEl.appendChild(li);
      });
    }
    modal.classList.add('open');
    modal.style.display = 'flex';
    modal.setAttribute('aria-hidden', 'false');
    const focusable = modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
    if (focusable.length) focusable[0].focus();
    lockBodyScroll();
    document.addEventListener('focus', trapFocus, true);
  }

  function closeModal() {
    modal.classList.remove('open');
    modal.style.display = 'none';
    modal.setAttribute('aria-hidden', 'true');
    unlockBodyScroll();
    document.removeEventListener('focus', trapFocus, true);
    if (lastFocused) lastFocused.focus();
  }

  function trapFocus(e) {
    if (!modal.classList.contains('open')) return;
    if (!modal.contains(e.target)) {
      e.stopPropagation();
      modal.focus();
    }
  }

  // expose for backward compatibility with inline onclicks
  window.closeModal = closeModal;

  modal.addEventListener('click', (ev) => {
    if (ev.target === modal) closeModal();
    const btn = ev.target.closest('.close');
    if (btn) closeModal();
  });

  document.addEventListener('keydown', (ev) => {
    if (ev.key === 'Escape' && modal.classList.contains('open')) closeModal();
  });

  // delegation for ingredient buttons
  document.addEventListener('click', (e) => {
    const btn = e.target.closest('.ingredients-btn, [data-dish]');
    if (!btn) return;
    const dish = btn.getAttribute('data-dish') || btn.dataset.dish;
    if (dish && window.ingredientsData && window.ingredientsData[dish]) {
      openModal(window.ingredientsData[dish]);
    } else if (dish && window.ingredientsData && !window.ingredientsData[dish]) {
      openModal({ title: 'Information', ingredients: [{ name: 'Details coming soon', allergen: false }] });
    }
  });

  // Provide a public `showIngredients` (backwards compatible)
  window.showIngredients = function (dishIdOrData) {
    if (typeof dishIdOrData === 'string' && window.ingredientsData && window.ingredientsData[dishIdOrData]) {
      openModal(window.ingredientsData[dishIdOrData]);
      return;
    }
    if (typeof dishIdOrData === 'object' && dishIdOrData !== null) {
      openModal(dishIdOrData);
      return;
    }
    openModal({ title: 'Information', ingredients: [{ name: 'No details available', allergen: false }] });
  };
})();

/* ========== Reservation form (submits to API_ENDPOINT) ========== */
(function initReservationForm() {
  const form = document.querySelector('.reservation-form');
  if (!form) return;
  const submitBtn = form.querySelector('button[type="submit"]') || form.querySelector('.submit-btn');
  const statusContainer = form;

  async function submitReservation(payload) {
    if (!API_ENDPOINT || API_ENDPOINT === '__API_ENDPOINT__') {
      // Demo fallback
      return { ok: true, json: async () => ({ message: 'Demo mode — no backend configured' }) };
    }
    try {
      const response = await fetch(API_ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
        mode: 'cors',
        credentials: 'omit'
      });
      return response;
    } catch (err) {
      throw new Error('Network error: ' + (err.message || 'Failed to reach server'));
    }
  }

  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    const payload = {
      name: fd.get('name') || '',
      email: fd.get('email') || '',
      phone: fd.get('phone') || '',
      date: fd.get('date') || '',
      time: fd.get('time') || '',
      guests: fd.get('guests') || '',
      special: fd.get('special') || ''
    };

    if (!payload.name || !payload.email || !payload.date || !payload.guests) {
      showStatusMessage(statusContainer, 'error', 'Please fill in required fields (name, email, date, guests).');
      return;
    }

    submitBtn.disabled = true;
    submitBtn.setAttribute('aria-disabled', 'true');
    submitBtn.textContent = 'Sending…';
    showStatusMessage(statusContainer, 'info', 'Submitting your booking…');

    try {
      const res = await submitReservation(payload);
      if (!res) throw new Error('Empty response');

      if (res.ok) {
        const body = await res.json().catch(() => ({}));
        showStatusMessage(statusContainer, 'success', body.message || 'Booking received. We will contact you shortly.');
        setTimeout(() => { form.reset(); }, 600);
      } else {
        let errText = `Server responded with ${res.status}`;
        try { const js = await res.json(); if (js && js.message) errText = js.message; } catch (ee) {}
        showStatusMessage(statusContainer, 'error', `Failed to submit booking: ${errText}`);
      }
    } catch (err) {
      showStatusMessage(statusContainer, 'error', err.message || 'Submission failed. Try again later.');
    } finally {
      submitBtn.disabled = false;
      submitBtn.removeAttribute('aria-disabled');
      submitBtn.textContent = 'Submit Booking Request';
    }
  });
})();

/* ========== WhatsApp floating link ========== */
(function initWhatsAppFloat() {
  const wa = document.querySelector('.wa-float') || document.querySelector('.whatsapp-float') || $('.wa-button');
  if (!wa) return;
  const phone = (typeof WHATSAPP_NUMBER === 'string' && WHATSAPP_NUMBER.trim() && WHATSAPP_NUMBER !== '__WHATSAPP__') ? WHATSAPP_NUMBER.replace(/\D/g, '') : '';
  const url = phone ? `https://wa.me/${phone}` : 'https://wa.me/';
  wa.setAttribute('href', url);
  wa.setAttribute('target', '_blank');
  wa.setAttribute('rel', 'noopener noreferrer');
  wa.addEventListener('touchstart', () => { wa.classList.add('touched'); setTimeout(() => wa.classList.remove('touched'), 800); });
})();

/* ========== Optional decorations (opt-in) ========== */
(function initOptionalDecorations() {
  if (document.body.getAttribute('data-decorations') !== 'true') return;
  try {
    if (typeof createDiagonalGrid === 'function') createDiagonalGrid();
    if (typeof createStaticDecoration === 'function') createStaticDecoration();
    if (typeof createBottomRightDecoration === 'function') createBottomRightDecoration();
  } catch (e) { console.warn('Decoration init failed:', e); }
})();

/* ========== Accessibility skip link ========== */
(function ensureSkipLink() {
  if (!$('#skip-to-content')) {
    const skip = document.createElement('a');
    skip.href = '#home';
    skip.id = 'skip-to-content';
    skip.className = 'skip-link';
    skip.textContent = 'Skip to content';
    skip.style.position = 'absolute';
    skip.style.left = '-999px';
    skip.style.top = 'auto';
    skip.style.height = '1px';
    skip.style.overflow = 'hidden';
    document.body.prepend(skip);
    skip.addEventListener('focus', () => { skip.style.left = '1rem'; skip.style.top = '1rem'; skip.style.height = 'auto'; });
    skip.addEventListener('blur', () => { skip.style.left = '-999px'; skip.style.top = 'auto'; skip.style.height = '1px'; });
  }
})();
