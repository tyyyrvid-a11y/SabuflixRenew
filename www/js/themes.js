/* ================================================
   SABUFLIX — Theme System (v1)
   ================================================ */
(function () {
    var STORAGE_KEY = 'sabuflix-theme';
    var THEMES = [
        { id: 'dark',          label: 'Dark',          desc: 'Escuro clássico'     },
        { id: 'liquid-glass',  label: 'Liquid Glass',  desc: 'Apple WWDC 2025'     },
        { id: 'windows95',     label: 'Windows 95',    desc: 'Clássico retrô'      },
        { id: 'frutiger-aero', label: 'Frutiger Aero', desc: 'Glossy dos anos 2000'},
    ];

    var THEME_COLORS = {
        'dark':          '#0a0a0a',
        'liquid-glass':  '#1c1c1e',
        'windows95':     '#008080',
        'frutiger-aero': '#87ceeb',
    };

    var panel = null;
    var isOpen = false;

    /* ── Apply theme ── */
    function applyTheme(id) {
        if (!id || id === 'dark') {
            document.documentElement.removeAttribute('data-theme');
        } else {
            document.documentElement.setAttribute('data-theme', id);
        }
        localStorage.setItem(STORAGE_KEY, id);

        var meta = document.querySelector('meta[name="theme-color"]');
        if (meta) meta.setAttribute('content', THEME_COLORS[id] || '#0a0a0a');

        document.querySelectorAll('.theme-option').forEach(function (el) {
            el.classList.toggle('active', el.dataset.themeId === id);
        });
    }

    /* ── Panel open/close ── */
    function openPanel() {
        if (!panel) return;
        panel.classList.add('open');
        panel.setAttribute('aria-hidden', 'false');
        isOpen = true;
    }

    function closePanel() {
        if (!panel) return;
        panel.classList.remove('open');
        panel.setAttribute('aria-hidden', 'true');
        isOpen = false;
    }

    function togglePanel() {
        if (isOpen) { closePanel(); } else { openPanel(); }
    }

    /* ── Sun/moon SVG icon for button ── */
    function sunIcon() {
        return '<svg xmlns="http://www.w3.org/2000/svg" class="nav-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M6.34 17.66l-1.41 1.41M19.07 4.93l-1.41 1.41"/></svg>';
    }

    function closeIcon() {
        return '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18M6 6l12 12"/></svg>';
    }

    function checkIcon() {
        return '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg>';
    }

    /* ── Build picker panel ── */
    function buildPanel() {
        panel = document.createElement('div');
        panel.id = 'themePicker';
        panel.className = 'theme-picker';
        panel.setAttribute('role', 'dialog');
        panel.setAttribute('aria-label', 'Seletor de tema');
        panel.setAttribute('aria-hidden', 'true');

        var optionsHTML = THEMES.map(function (t) {
            return (
                '<button class="theme-option" data-theme-id="' + t.id + '" aria-label="Tema ' + t.label + '">' +
                    '<div class="theme-preview theme-preview--' + t.id + '"></div>' +
                    '<div class="theme-option-info">' +
                        '<span class="theme-option-label">' + t.label + '</span>' +
                        '<span class="theme-option-desc">' + t.desc + '</span>' +
                    '</div>' +
                    '<div class="theme-option-check">' + checkIcon() + '</div>' +
                '</button>'
            );
        }).join('');

        panel.innerHTML =
            '<div class="theme-picker-header">' +
                '<span class="theme-picker-title">Temas</span>' +
                '<button class="theme-picker-close" id="themePickerClose" aria-label="Fechar">' + closeIcon() + '</button>' +
            '</div>' +
            '<div class="theme-options">' + optionsHTML + '</div>';

        document.body.appendChild(panel);

        document.getElementById('themePickerClose').addEventListener('click', closePanel);

        panel.querySelectorAll('.theme-option').forEach(function (el) {
            el.addEventListener('click', function () {
                applyTheme(el.dataset.themeId);
            });
        });
    }

    /* ── Build a trigger button ── */
    function makeBtn(extraClass) {
        var btn = document.createElement('button');
        btn.className = 'nav-item theme-toggle-btn' + (extraClass ? ' ' + extraClass : '');
        btn.setAttribute('aria-label', 'Trocar tema');
        btn.setAttribute('aria-controls', 'themePicker');
        btn.innerHTML = sunIcon() + '<span class="nav-text">Tema</span>';
        btn.addEventListener('click', function (e) {
            e.stopPropagation();
            togglePanel();
        });
        return btn;
    }

    /* ── Wire up buttons into the nav ── */
    function buildButtons() {
        /* Mobile: insert before the mobile search button */
        var navLinks = document.querySelector('.nav-links');
        var mobileSearch = document.getElementById('btnOpenSearchMobile');
        if (navLinks && mobileSearch) {
            navLinks.insertBefore(makeBtn('mobile-only'), mobileSearch);
        }

        /* Desktop: append to nav-actions (already desktop-only) */
        var navActions = document.querySelector('.nav-actions');
        if (navActions) {
            navActions.appendChild(makeBtn('desktop-only'));
        }
    }

    /* ── Close on outside click / Escape ── */
    function bindGlobalClose() {
        document.addEventListener('click', function (e) {
            if (!isOpen) return;
            if (panel && panel.contains(e.target)) return;
            if (e.target.closest && e.target.closest('.theme-toggle-btn')) return;
            closePanel();
        });

        document.addEventListener('keydown', function (e) {
            if (e.key === 'Escape' && isOpen) closePanel();
        });
    }

    /* ── Init ── */
    function init() {
        var saved = localStorage.getItem(STORAGE_KEY) || 'dark';
        applyTheme(saved);
        buildPanel();
        buildButtons();
        bindGlobalClose();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
