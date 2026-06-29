// @ts-check
'use strict';

/**
 * SabuFlix — Main Application Module
 * 
 * A streaming catalog UI powered by the TMDB API and Stremio addons.
 * All state, DOM references, and event listeners are scoped within an
 * IIFE to prevent global leaks.
 */
(() => {
    // ─── Constants ────────────────────────────────────────────────────
    const IMG_BASE = 'https://image.tmdb.org/t/p/w500';
    const IMG_BG   = 'https://image.tmdb.org/t/p/original';

    // ─── Cached DOM References ────────────────────────────────────────
    /** @type {Object<string, HTMLElement|null>} */
    const DOM = {};
    
    // Global tracker for active downloads progress


    /**
     * Populate the DOM cache once on init.
     * Every element we reference more than once is stored here.
     */
    function cacheDOMRefs() {
        DOM.catalog          = document.getElementById('catalogContainer');
        DOM.heroBanner       = document.getElementById('heroBanner');
        DOM.heroTitle        = document.getElementById('heroTitle');
        DOM.heroMeta         = document.getElementById('heroMeta');
        DOM.heroOverview     = document.getElementById('heroOverview');
        DOM.heroPlay         = document.getElementById('heroPlay');
        DOM.heroBtnMyList    = document.getElementById('heroBtnMyList');
        DOM.detailsModal     = document.getElementById('detailsModal');
        DOM.detailsBackdrop  = document.getElementById('detailsBackdrop');
        DOM.detailsTitle     = document.getElementById('detailsTitle');
        DOM.detailsBadge     = document.getElementById('detailsBadge');
        DOM.detailsMeta      = document.getElementById('detailsMeta');
        DOM.detailsOverview  = document.getElementById('detailsOverview');
        DOM.detailsBtnMyList = document.getElementById('detailsBtnMyList');
        DOM.detailsRightPanel = document.getElementById('detailsRightPanel');
        DOM.closeDetails     = document.getElementById('closeDetails');
        DOM.streamsList      = document.getElementById('streamsList');
        DOM.seriesSelector   = document.getElementById('seriesSelector');
        DOM.seasonMenu       = document.getElementById('seasonDropdownMenu');
        DOM.seasonLabel      = document.getElementById('seasonDropdownLabel');
        DOM.seasonTrigger    = document.getElementById('seasonDropdownTrigger');
        DOM.seasonWrapper    = document.getElementById('seasonDropdownWrapper');
        DOM.episodeMenu      = document.getElementById('episodeDropdownMenu');
        DOM.episodeLabel     = document.getElementById('episodeDropdownLabel');
        DOM.episodeTrigger   = document.getElementById('episodeDropdownTrigger');
        DOM.episodeWrapper   = document.getElementById('episodeDropdownWrapper');
        DOM.btnPillPlayer1   = document.getElementById('btnPillPlayer1');
        DOM.btnPillPlayer2   = document.getElementById('btnPillPlayer2');
        DOM.btnOpenSearch    = document.getElementById('btnOpenSearch');
        DOM.searchOverlay    = document.getElementById('searchOverlay');
        DOM.closeSearch      = document.getElementById('closeSearch');
        DOM.searchInput      = document.getElementById('searchInput');
        DOM.searchResults    = document.getElementById('searchResults');
        DOM.toastContainer   = null; // created lazily
    }

    // ─── Application State ────────────────────────────────────────────
    /** @type {Object|null} Current movie/series details object */
    let currentMovie = null;
    /** @type {string|null} Current IMDB ID for stream lookups */
    let currentImdbId = null;
    /** @type {number|string|null} Current TMDB ID */
    let currentTmdbId = null;
    /** @type {Array} Current stream results for the open detail */
    let currentStreams = [];
    /** @type {number|null} Search debounce timer handle */
    let searchTimeout = null;
    /** @type {AbortController|null} In-flight search request controller */
    let searchAbort = null;
    /** @type {AbortController|null} In-flight page-load request controller */
    let pageAbort = null;
    /** @type {string} Currently active tab name */
    let activeTab = 'home';
    /** @type {IntersectionObserver|null} Lazy image observer */
    let lazyObserver = null;

    // (Cache layer removida. Agora o cache é exclusividade do api.js para evitar redundância e memory leaks)

    // ─── Lazy-Load Observer ───────────────────────────────────────────

    /**
     * Create the IntersectionObserver that swaps data-src → background-image.
     * Called once during init.
     */
    function createLazyObserver() {
        if (lazyObserver) return;
        lazyObserver = new IntersectionObserver((entries) => {
            entries.forEach((entry) => {
                if (entry.isIntersecting) {
                    const card = entry.target;
                    const src = card.dataset.src;
                    if (src) {
                        card.style.backgroundImage = `url('${src}')`;
                        card.removeAttribute('data-src');
                    }
                    lazyObserver.unobserve(card);
                }
            });
        }, { rootMargin: '200px' });
    }

    // ─── Toast Notifications ──────────────────────────────────────────

    /**
     * Show a brief toast message at the bottom of the screen.
     * @param {string} message - Text to display
     * @param {'success'|'info'|'error'} [type='info'] - Visual style
     */
    function showToast(message, type = 'info') {
        if (!DOM.toastContainer) {
            DOM.toastContainer = document.createElement('div');
            DOM.toastContainer.id = 'toastContainer';
            Object.assign(DOM.toastContainer.style, {
                position: 'fixed',
                bottom: '24px',
                left: '50%',
                transform: 'translateX(-50%)',
                zIndex: '100000',
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                gap: '8px',
                pointerEvents: 'none'
            });
            document.body.appendChild(DOM.toastContainer);
        }

        const colors = {
            success: { bg: 'rgba(16,185,129,0.95)', icon: '✓' },
            info:    { bg: 'rgba(59,130,246,0.95)', icon: 'ℹ' },
            error:   { bg: 'rgba(239,68,68,0.95)',  icon: '✕' }
        };
        const c = colors[type] || colors.info;

        const toast = document.createElement('div');
        Object.assign(toast.style, {
            background: c.bg,
            color: '#fff',
            padding: '12px 24px',
            borderRadius: '12px',
            fontSize: '14px',
            fontWeight: '600',
            backdropFilter: 'blur(12px)',
            boxShadow: '0 8px 32px rgba(0,0,0,0.3)',
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            opacity: '0',
            transform: 'translateY(16px)',
            transition: 'all 0.3s cubic-bezier(0.4,0,0.2,1)',
            pointerEvents: 'auto'
        });
        toast.textContent = `${c.icon}  ${message}`;
        DOM.toastContainer.appendChild(toast);

        // Trigger entrance animation
        requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateY(0)';
        });

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(16px)';
            toast.addEventListener('transitionend', () => toast.remove(), { once: true });
        }, 3000);
    }

    // ─── Skeleton Loaders ─────────────────────────────────────────────

    /**
     * Return HTML for a skeleton loading placeholder.
     * @param {string} [msg=''] - Optional text to show alongside the skeleton
     * @returns {string} HTML string
     */
    function skeletonHTML(msg = '') {
        return `
            <div class="skeleton-container" style="padding: 30px 50px;">
                ${msg ? `<div style="color: var(--text-muted); margin-bottom: 20px; font-size: 14px;">${msg}</div>` : ''}
                <div class="skeleton-row" style="display:flex; gap:12px; overflow:hidden;">
                    ${Array.from({ length: 7 }, () => `
                        <div style="
                            min-width: 160px; height: 240px;
                            border-radius: 12px;
                            background: linear-gradient(110deg, rgba(255,255,255,0.04) 8%, rgba(255,255,255,0.08) 18%, rgba(255,255,255,0.04) 33%);
                            background-size: 200% 100%;
                            animation: skeletonShimmer 1.5s linear infinite;
                        "></div>
                    `).join('')}
                </div>
                <style>
                    @keyframes skeletonShimmer {
                        0% { background-position: 200% 0; }
                        100% { background-position: -200% 0; }
                    }
                </style>
            </div>`;
    }

    // ─── History (Watch History) ──────────────────────────────────────

    /**
     * Save a TMDB item to watch history (localStorage).
     * @param {number|string} id   - TMDB ID
     * @param {string}        type - 'movie' | 'series' | 'tv'
     */
    function saveToHistory(id, type) {
        let history = JSON.parse(localStorage.getItem('sabuflix_history') || '[]');
        history = history.filter((item) => item.id !== Number(id) && item.id !== String(id));
        history.unshift({ id, type });
        if (history.length > 10) history = history.slice(0, 10);
        localStorage.setItem('sabuflix_history', JSON.stringify(history));
    }

    /**
     * Retrieve watch history from localStorage.
     * @returns {Array<{id: number|string, type: string}>}
     */
    function getHistory() {
        return JSON.parse(localStorage.getItem('sabuflix_history') || '[]');
    }

    // ─── Tab Persistence ──────────────────────────────────────────────

    /**
     * Persist the active tab name to localStorage.
     * @param {string} tab
     */
    function saveActiveTab(tab) {
        localStorage.setItem('sabuflix_active_tab', tab);
    }

    /**
     * Retrieve the last active tab from localStorage.
     * @returns {string}
     */
    function getActiveTab() {
        return localStorage.getItem('sabuflix_active_tab') || 'home';
    }

    // ─── Abort Helpers ────────────────────────────────────────────────

    /**
     * Cancel any in-flight page load fetches and return a fresh signal.
     * @returns {AbortSignal}
     */
    function freshPageSignal() {
        if (pageAbort) pageAbort.abort();
        pageAbort = new AbortController();
        return pageAbort.signal;
    }

    // ─── Hero Banner (with crossfade) ─────────────────────────────────

    /**
     * Set up the hero banner with crossfade transition.
     * Does NOT mutate the source array.
     * @param {Object} item         - TMDB result object
     * @param {string} [defaultType='movie'] - Fallback media type
     * @param {AbortSignal} [signal] - Optional signal to abort crossfade if tab changes
     */
    async function setupHeroBanner(item, defaultType = 'movie', signal) {
        const banner   = DOM.heroBanner;
        const title    = DOM.heroTitle;
        const meta     = DOM.heroMeta;
        const overview = DOM.heroOverview;
        const playBtn  = DOM.heroPlay;
        const heroBtnMyList = DOM.heroBtnMyList;

        if (!banner) return;
        banner.style.display = 'flex';
        DOM.catalog.classList.remove('no-hero');

        const type = item.media_type || defaultType;

        // ── Crossfade logic ──
        banner.style.transition = 'opacity 0.6s ease';
        banner.style.opacity = '0';

        await new Promise((r) => setTimeout(r, 300));
        if (signal && signal.aborted) return;

        if (item.backdrop_path) {
            banner.style.backgroundImage = `url('${IMG_BG}${item.backdrop_path}')`;
        }

        const titleStr = item.title || item.name;
        title.innerHTML = titleStr;

        const year   = (item.release_date || item.first_air_date || '').split('-')[0];
        const rating = item.vote_average ? `<span class="rating">★ ${item.vote_average.toFixed(1)}</span>` : '';
        meta.innerHTML = `<span>${year}</span> <span>${type === 'tv' || type === 'series' ? 'TV SERIES' : 'FILM'}</span> ${rating}`;
        overview.textContent = item.overview;

        playBtn.onclick = () => openDetails(item.id, type);

        // ── My List button ──
        const checkHeroList = () => {
            if (typeof userMyList !== 'undefined' && userMyList.includes(item.id.toString())) {
                if (heroBtnMyList) {
                    heroBtnMyList.innerHTML = 'Salvo';
                    heroBtnMyList.style.color = '#eab308';
                }
            } else {
                if (heroBtnMyList) {
                    heroBtnMyList.innerHTML = '+ Minha Lista';
                    heroBtnMyList.style.color = 'white';
                }
            }
        };
        // Small delay so userMyList has time to populate
        setTimeout(checkHeroList, 500);

        if (heroBtnMyList) {
            heroBtnMyList.onclick = async () => {
                if (typeof toggleMyList === 'function') {
                    const isSaved = await toggleMyList(item, type);
                    if (isSaved !== null) {
                        checkHeroList();
                        showToast(
                            isSaved ? 'Adicionado à Minha Lista' : 'Removido da Minha Lista',
                            isSaved ? 'success' : 'info'
                        );
                    }
                }
            };
        }

        // Fade banner back in
        requestAnimationFrame(() => {
            banner.style.opacity = '1';
        });

        // ── Try to load a logo image ──
        try {
            const images = await API.getImages(item.id, type);
            if (signal && signal.aborted) return;
            if (images.logos && images.logos.length > 0) {
                let logo = images.logos.find((l) => l.iso_639_1 === 'pt')
                        || images.logos.find((l) => l.iso_639_1 === 'en')
                        || images.logos[0];
                if (logo && logo.file_path) {
                    title.innerHTML = `<img src="${IMG_BASE}${logo.file_path}" alt="${titleStr}" style="max-height: 120px; max-width: 400px; object-fit: contain; margin-bottom: -10px;">`;
                }
            }
        } catch (e) {
            console.error('Error loading logo:', e);
        }

        // Final icon render for hero
        
    }

    // ─── Row Rendering ────────────────────────────────────────────────

    /**
     * Render a horizontal scrolling row of poster cards.
     * Uses DocumentFragment for batch DOM insertion and IntersectionObserver
     * for lazy-loading poster images.
     *
     * @param {HTMLElement} container   - Parent element to append to
     * @param {string}      title       - Row heading text
     * @param {Array}       items       - TMDB result objects
     * @param {string}      defaultType - Fallback media type
     * @param {boolean}     [isNumbered=false] - Show rank numbers
     */
    function renderRow(container, title, items, defaultType, isNumbered = false) {
        if (!items || items.length === 0) return;

        const row = document.createElement('div');
        row.className = 'catalog-row';

        // Header
        const header = document.createElement('div');
        header.className = 'row-header';
        header.innerHTML = `<h2 class="row-title">${title}</h2><a href="#" class="row-see-all">See all ></a>`;
        row.appendChild(header);

        // Items container — use fragment for batch insert
        const itemsContainer = document.createElement('div');
        itemsContainer.className = `items-container ${isNumbered ? 'numbered' : ''}`;

        const fragment = document.createDocumentFragment();

        items.forEach((item, index) => {
            if (!item.poster_path && !item.backdrop_path) return;

            const titleStr = item.title || item.name;
            const type     = item.media_type || defaultType || 'movie';
            const year     = (item.release_date || item.first_air_date || '').split('-')[0];
            const imgPath  = isNumbered ? (item.poster_path || item.backdrop_path) : (item.backdrop_path || item.poster_path);

            const wrapper = document.createElement('div');
            wrapper.className = 'poster-card-wrapper';
            // Fade-in animation class
            wrapper.style.opacity = '0';
            wrapper.style.transform = 'translateY(12px)';
            wrapper.style.transition = `opacity 0.4s ease ${index * 0.04}s, transform 0.4s ease ${index * 0.04}s`;

            if (isNumbered) {
                const rank = document.createElement('span');
                rank.className = 'rank-number';
                rank.textContent = index + 1;
                wrapper.appendChild(rank);
            }

            const card = document.createElement('div');
            card.className = `poster-card ${isNumbered ? 'portrait' : ''}`;
            card.dataset.id = item.id;
            card.dataset.type = type;
            card.dataset.src = `${IMG_BASE}${imgPath}`; // lazy-load
            card.title = titleStr;
            wrapper.appendChild(card);

            // Observe for lazy loading
            if (lazyObserver) {
                lazyObserver.observe(card);
            } else {
                // Fallback: load immediately
                card.style.backgroundImage = `url('${IMG_BASE}${imgPath}')`;
            }

            if (!isNumbered) {
                const info = document.createElement('div');
                info.className = 'card-info';
                info.innerHTML = `<div class="card-title">${titleStr}</div><div class="card-meta"><span>${type === 'tv' || type === 'series' ? 'TV' : 'MOVIE'}</span> <span>${year}</span></div>`;
                wrapper.appendChild(info);
            }

            fragment.appendChild(wrapper);
        });

        itemsContainer.appendChild(fragment);
        row.appendChild(itemsContainer);
        container.appendChild(row);

        // Trigger fade-in after a paint
        requestAnimationFrame(() => {
            const wrappers = row.querySelectorAll('.poster-card-wrapper');
            wrappers.forEach((w) => {
                w.style.opacity = '1';
                w.style.transform = 'translateY(0)';
            });
        });
    }

    // ─── Continue Watching Row Rendering ────────────────────────────

    function renderContinueWatchingRow(container, items) {
        if (!items || items.length === 0) return;

        const row = document.createElement('div');
        row.className = 'catalog-row continue-watching-row';

        const header = document.createElement('div');
        header.className = 'row-header';
        header.innerHTML = `<h2 class="row-title">Continuar Assistindo</h2>`;
        row.appendChild(header);

        const itemsContainer = document.createElement('div');
        itemsContainer.className = 'items-container';
        const fragment = document.createDocumentFragment();

        items.forEach((item, index) => {
            const titleStr = item.title;
            const type     = item.media_type || 'movie';
            const imgPath  = item.poster_path;

            const wrapper = document.createElement('div');
            wrapper.className = 'poster-card-wrapper';
            wrapper.style.opacity = '0';
            wrapper.style.transform = 'translateY(12px)';
            wrapper.style.transition = `opacity 0.4s ease ${index * 0.04}s, transform 0.4s ease ${index * 0.04}s`;

            const card = document.createElement('div');
            card.className = 'poster-card';
            // We use standard id to hook into existing click delegation
            card.dataset.id = item.tmdb_id;
            card.dataset.type = type;
            // Also store season and episode so openDetails could ideally auto-select them
            if (item.season && item.episode) {
                card.dataset.season = item.season;
                card.dataset.episode = item.episode;
            }
            card.dataset.src = `${IMG_BASE}${imgPath}`; 
            card.title = titleStr;
            wrapper.appendChild(card);

            if (lazyObserver) {
                lazyObserver.observe(card);
            } else {
                card.style.backgroundImage = `url('${IMG_BASE}${imgPath}')`;
            }

            const info = document.createElement('div');
            info.className = 'card-info';
            let subtitle = type === 'tv' || type === 'series' ? 'TV' : 'FILME';
            if (item.season && item.episode) {
                subtitle = `T${item.season} : E${item.episode}`;
            }
            info.innerHTML = `<div class="card-title">${titleStr}</div><div class="card-meta"><span style="color:#eab308; font-weight:bold;">${subtitle}</span></div>`;
            wrapper.appendChild(info);

            fragment.appendChild(wrapper);
        });

        itemsContainer.appendChild(fragment);
        row.appendChild(itemsContainer);
        container.appendChild(row);

        requestAnimationFrame(() => {
            const wrappers = row.querySelectorAll('.poster-card-wrapper');
            wrappers.forEach((w) => {
                w.style.opacity = '1';
                w.style.transform = 'translateY(0)';
            });
        });
    }

    // ─── Event Delegation for Poster Cards ────────────────────────────

    /**
     * A single delegated click listener on catalogContainer handles
     * all poster card clicks, avoiding per-element listeners.
     */
    function setupCardDelegation() {
        if (!DOM.catalog) return;
        DOM.catalog.addEventListener('click', (e) => {
            const card = e.target.closest('.poster-card');
            if (card && card.dataset.id) {
                if (card.dataset.localPath && typeof openOfflinePlayer === 'function') {
                    openOfflinePlayer(card.dataset.localPath, card.title);
                } else {
                    openDetails(card.dataset.id, card.dataset.type, card.dataset.season, card.dataset.episode);
                }
            }
        });
    }

    // ─── Page Loaders ─────────────────────────────────────────────────

    /**
     * Load the Home tab content.
     */
    async function loadHome() {
        const catalog = DOM.catalog;
        catalog.innerHTML = skeletonHTML('');
        const signal = freshPageSignal();

        try {
            const [popularMovies, popularSeries, trending] = await Promise.all([
                API.getPopularMovies(),
                API.getPopularSeries(),
                API.getTrending()
            ]);

            if (signal.aborted) return;

            catalog.innerHTML = '';

            // Pick a hero without mutating the source array
            const trendingResults = [...trending.results];
            if (trendingResults.length > 0) {
                const randomIndex = Math.floor(Math.random() * Math.min(20, trendingResults.length));
                const heroItem = trendingResults[randomIndex];
                trendingResults.splice(randomIndex, 1);
                setupHeroBanner(heroItem, 'movie', signal);
            }

            // Render Continue Watching
            if (typeof window.getContinueWatching === 'function') {
                const cwItems = window.getContinueWatching();
                if (cwItems && cwItems.length > 0) {
                    renderContinueWatchingRow(catalog, cwItems);
                }
            }

            // Recommendations based on watch history
            const history = getHistory();
            if (history.length > 0) {
                const lastWatched = history[0];
                try {
                    const recs = await API.getRecommendations(lastWatched.id, lastWatched.type);
                    if (signal.aborted) return;
                    if (recs.results && recs.results.length > 0) {
                        renderRow(catalog, 'Recomendados para Você', recs.results.slice(0, 10), lastWatched.type);
                    }
                } catch (e) {
                    console.error('Erro ao carregar recomendações:', e);
                }
            }

            renderRow(catalog, 'Trending Now', trendingResults, 'movie');
            renderRow(catalog, 'Top 10 Movies', popularMovies.results.slice(0, 10), 'movie', true);
            renderRow(catalog, 'Top 10 Shows', popularSeries.results.slice(0, 10), 'series', true);

            // Single lucide call after all DOM updates
            
        } catch (e) {
            if (signal.aborted) return;
            console.error(e);
            catalog.innerHTML = '<div style="color: red; padding: 50px;">Erro ao carregar o catálogo.</div>';
        }
    }

    /**
     * Load the My List tab content.
     */
    async function loadMyList() {
        const catalog = DOM.catalog;
        catalog.innerHTML = skeletonHTML('Carregando Minha Lista...');
        const signal = freshPageSignal();

        try {
            if (DOM.heroBanner) DOM.heroBanner.style.display = 'none';
            if (DOM.recommendedSection) DOM.recommendedSection.style.display = 'none';
            catalog.classList.add('no-hero');

            if (typeof getFullMyList !== 'function') return;
            const myList = await getFullMyList();
            if (signal.aborted) return;

            catalog.innerHTML = '';

            if (myList.length === 0) {
                catalog.innerHTML = '<div style="color: var(--text-muted); padding: 50px; text-align: center;">Sua lista está vazia. Comece a adicionar filmes e séries!</div>';
                return;
            }

            const formattedList = myList.map((item) => ({
                id: item.tmdb_id,
                title: item.title,
                media_type: item.media_type,
                poster_path: item.poster_path
            }));

            renderRow(catalog, 'Salvos por Você', formattedList, 'movie');
            
        } catch (e) {
            if (signal.aborted) return;
            catalog.innerHTML = '<div style="color: red; padding: 50px;">Erro ao carregar a lista.</div>';
        }
    }



    /**
     * Load the Discover tab content.
     */
    async function loadDiscover() {
        const catalog = DOM.catalog;
        catalog.innerHTML = skeletonHTML('');
        const signal = freshPageSignal();

        try {
            const topMovies = await API.getTopRatedMovies();
            if (signal.aborted) return;

            catalog.innerHTML = '';

            const results = [...topMovies.results];
            if (results.length > 0) {
                const randomIndex = Math.floor(Math.random() * Math.min(20, results.length));
                const heroItem = results[randomIndex];
                results.splice(randomIndex, 1);
                setupHeroBanner(heroItem, 'movie', signal);
            }

            renderRow(catalog, 'Filmes Mais Bem Avaliados', results, 'movie');
            
        } catch (e) {
            if (signal.aborted) return;
            catalog.innerHTML = '<div style="color: red; padding: 50px;">Erro ao carregar.</div>';
        }
    }

    /**
     * Load the Series tab content.
     */
    async function loadSeries() {
        const catalog = DOM.catalog;
        catalog.innerHTML = skeletonHTML('');
        const signal = freshPageSignal();

        try {
            const [popularSeries, topSeries] = await Promise.all([
                API.getPopularSeries(),
                API.getTopRatedSeries()
            ]);

            if (signal.aborted) return;

            catalog.innerHTML = '';

            const results = [...popularSeries.results];
            if (results.length > 0) {
                const randomIndex = Math.floor(Math.random() * Math.min(20, results.length));
                const heroItem = results[randomIndex];
                results.splice(randomIndex, 1);
                setupHeroBanner(heroItem, 'series', signal);
            }

            renderRow(catalog, 'Séries Populares', results, 'series');
            renderRow(catalog, 'Top 10 Séries Bem Avaliadas', topSeries.results.slice(0, 10), 'series', true);
            
        } catch (e) {
            if (signal.aborted) return;
            catalog.innerHTML = '<div style="color: red; padding: 50px;">Erro ao carregar.</div>';
        }
    }

    // ─── Sidebar Navigation ──────────────────────────────────────────

    /**
     * Attach navigation click handlers to sidebar links.
     * Restores the last active tab on load.
     */
    function setupSidebar() {
        const navItems = document.querySelectorAll('.nav-links .nav-item');
        const tabLoaders = {
            home:      loadHome,
            discover:  loadDiscover,
            series:    loadSeries,
            mylist:    loadMyList
        };

        // Restore persisted tab
        const savedTab = getActiveTab();
        activeTab = savedTab;

        navItems.forEach((item) => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const tab = item.dataset.tab;
                if (!tab) return; // Skip non-tab items like search
                navItems.forEach((n) => n.classList.remove('active'));
                item.classList.add('active');
                activeTab = tab;
                saveActiveTab(tab);
                const loader = tabLoaders[tab];
                if (loader) loader();
            });

            // Mark the persisted tab as active
            if (item.dataset.tab) {
                if (item.dataset.tab === savedTab) {
                    item.classList.add('active');
                } else {
                    item.classList.remove('active');
                }
            }
        });

        // Load the persisted tab
        const loader = tabLoaders[savedTab];
        if (loader) loader();
    }

    // ─── Search ───────────────────────────────────────────────────────

    /**
     * Wire up the search overlay, input, and debounced API calls.
     * Uses AbortController to cancel in-flight search requests.
     */
    function setupSearch() {
        const overlay = DOM.searchOverlay;
        const input   = DOM.searchInput;
        const results = DOM.searchResults;

        if (DOM.btnOpenSearch) {
            DOM.btnOpenSearch.addEventListener('click', (e) => {
                e.preventDefault();
                overlay.classList.add('active');
                input.focus();
            });
        }

        const btnOpenSearchMobile = document.getElementById('btnOpenSearchMobile');
        if (btnOpenSearchMobile) {
            btnOpenSearchMobile.addEventListener('click', (e) => {
                e.preventDefault();
                overlay.classList.add('active');
                input.focus();
            });
        }

        if (DOM.closeSearch) {
            DOM.closeSearch.addEventListener('click', () => {
                overlay.classList.remove('active');
            });
        }

        if (!input) return;

        input.addEventListener('input', (e) => {
            clearTimeout(searchTimeout);
            const query = e.target.value.trim();

            searchTimeout = setTimeout(async () => {
                if (query.length <= 2) {
                    results.innerHTML = '';
                    return;
                }

                // Cancel previous in-flight search
                if (searchAbort) searchAbort.abort();
                searchAbort = new AbortController();

                results.innerHTML = '<div style="color:var(--text-muted); padding: 10px;">Buscando...</div>';

                try {
                    const res = await API.search(query);
                    // If aborted in the meantime, discard
                    if (searchAbort.signal.aborted) return;

                    results.innerHTML = '';

                    if (res.results.length === 0) {
                        results.innerHTML = '<div style="color:var(--text-muted); padding: 10px;">Nenhum resultado.</div>';
                        return;
                    }

                    const fragment = document.createDocumentFragment();
                    res.results.forEach((item) => {
                        if (!item.poster_path) return;

                        const titleStr = item.title || item.name;
                        const year = (item.release_date || item.first_air_date || '').split('-')[0];
                        const type = item.media_type === 'tv' ? 'TV' : 'MOVIE';

                        const div = document.createElement('div');
                        div.className = 'search-item';
                        div.innerHTML = `<img src="${IMG_BASE}${item.poster_path}" alt=""><div class="search-item-info"><h4>${titleStr}</h4><span>${year} • ${type}</span></div>`;
                        div.addEventListener('click', () => {
                            overlay.classList.remove('active');
                            openDetails(item.id, item.media_type || 'movie');
                        });
                        fragment.appendChild(div);
                    });
                    results.appendChild(fragment);
                } catch (err) {
                    if (err.name === 'AbortError') return;
                    results.innerHTML = '<div style="color:red; padding: 10px;">Erro na busca.</div>';
                }
            }, 400);
        });
    }

    // ─── Details Modal ────────────────────────────────────────────────

    /**
     * Open the details modal for a movie or series.
     * @param {number|string} id   - TMDB ID
     * @param {string}        type - 'movie' | 'series' | 'tv'
     * @param {number|null}   targetSeason
     * @param {number|null}   targetEpisode
     */
    async function openDetails(id, type, targetSeason = null, targetEpisode = null) {
        currentTmdbId = id;
        saveToHistory(id, type);

        const modal      = DOM.detailsModal;
        const rightPanel = DOM.detailsRightPanel;
        const btnPlay1   = DOM.btnPillPlayer1;
        const btnPlay2   = DOM.btnPillPlayer2;

        if (rightPanel) rightPanel.style.display = 'block';

        /** Build handler for play buttons */
        const handlePlayClick = (server) => {
            if (type === 'series' || type === 'tv') {
                const sSelect  = document.getElementById('seasonSelect');
                const epActive = document.querySelector('.ep-item.active');
                const season   = sSelect ? sSelect.value : 1;
                const episode  = epActive ? epActive.dataset.ep : 1;
                if (currentMovie && typeof window.saveToContinueWatching === 'function') {
                    window.saveToContinueWatching(currentMovie, type, season, episode);
                }
                window.player.playEmbed(currentTmdbId, type, season, episode, server);
            } else {
                if (currentMovie && typeof window.saveToContinueWatching === 'function') {
                    window.saveToContinueWatching(currentMovie, type, null, null);
                }
                window.player.playEmbed(currentTmdbId, type, null, null, server);
            }
        };

        if (btnPlay1) btnPlay1.onclick = () => handlePlayClick(1);
        if (btnPlay2) btnPlay2.onclick = () => handlePlayClick(2);

        const backdropEl = DOM.detailsBackdrop;
        const titleEl    = DOM.detailsTitle;
        const badgeEl    = DOM.detailsBadge;
        const streamsList = DOM.streamsList;
        const seriesSelector = DOM.seriesSelector;

        if (streamsList) streamsList.innerHTML = '<div style="color:var(--text-muted); text-align: right;">Fetching sources...</div>';
        if (seriesSelector) seriesSelector.style.display = 'none';

        currentStreams = [];
        currentMovie  = null;
        currentImdbId = null;

        // My List button for detail modal
        const btnMyList = DOM.detailsBtnMyList;
        const checkDetailsList = () => {
            if (!btnMyList) return;
            if (typeof userMyList !== 'undefined' && userMyList.includes(id.toString())) {
                btnMyList.innerHTML = 'Salvo Salvo na Lista';
                btnMyList.style.background   = 'rgba(234, 179, 8, 0.2)';
                btnMyList.style.borderColor   = '#eab308';
                btnMyList.style.color         = '#eab308';
            } else {
                btnMyList.innerHTML = '+ Adicionar à Minha Lista';
                btnMyList.style.background   = 'rgba(255,255,255,0.1)';
                btnMyList.style.borderColor   = 'rgba(255,255,255,0.2)';
                btnMyList.style.color         = 'white';
            }
        };
        checkDetailsList();

        if (btnMyList) {
            btnMyList.onclick = async () => {
                if (!currentMovie) return;
                if (typeof toggleMyList === 'function') {
                    const isSaved = await toggleMyList(currentMovie, type);
                    if (isSaved !== null) {
                        checkDetailsList();
                        showToast(
                            isSaved ? 'Adicionado à Minha Lista' : 'Removido da Minha Lista',
                            isSaved ? 'success' : 'info'
                        );
                    }
                }
            };
        }

        modal.classList.add('active');

        try {
            const [details, external] = await Promise.all([
                API.getDetails(id, type),
                API.getExternalIds(id, type)
            ]);

            currentMovie  = details;
            currentImdbId = external.imdb_id;

            if (backdropEl) backdropEl.style.backgroundImage = `url('${IMG_BG}${details.backdrop_path}')`;
            if (titleEl)    titleEl.textContent = details.title || details.name;
            if (badgeEl)    badgeEl.textContent = (type === 'tv' || type === 'series') ? 'SERIES' : 'FILM';

            const metaEl     = DOM.detailsMeta;
            const overviewEl = DOM.detailsOverview;
            
            if (overviewEl) overviewEl.textContent = details.overview || 'Sinopse indisponível.';
            
            if (metaEl) {
                const year = (details.release_date || details.first_air_date || '').split('-')[0];
                const rating = (details.vote_average || 0).toFixed(1);
                
                let ageRating = '';
                if (type === 'tv' || type === 'series') {
                    const brRating = details.content_ratings?.results?.find(r => r.iso_3166_1 === 'BR');
                    if (brRating && brRating.rating) ageRating = brRating.rating;
                    else {
                        const usRating = details.content_ratings?.results?.find(r => r.iso_3166_1 === 'US');
                        if (usRating && usRating.rating) ageRating = usRating.rating;
                    }
                } else {
                    const brRelease = details.release_dates?.results?.find(r => r.iso_3166_1 === 'BR');
                    if (brRelease && brRelease.release_dates && brRelease.release_dates[0].certification) {
                        ageRating = brRelease.release_dates[0].certification;
                    } else {
                        const usRelease = details.release_dates?.results?.find(r => r.iso_3166_1 === 'US');
                        if (usRelease && usRelease.release_dates && usRelease.release_dates[0].certification) {
                            ageRating = usRelease.release_dates[0].certification;
                        }
                    }
                }
                if (!ageRating) ageRating = 'L';
                if (ageRating === 'L' || ageRating === 'G' || ageRating === 'PG') ageRating = 'Livre';
                
                metaEl.innerHTML = `<span style="color: #eab308; font-weight: bold;">⭐ ${rating}</span> <span>${year}</span> <span style="border: 1px solid rgba(255,255,255,0.3); padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold;">${ageRating}</span>`;
            }

            if (!currentImdbId) {
                if (streamsList) streamsList.innerHTML = '<div style="color:#ef4444; text-align: right;">IMDB ID missing.</div>';
                
                return;
            }

            if (type === 'tv' || type === 'series') {
                setupSeriesSelector(details, targetSeason, targetEpisode);
            } else {
                const streams = await API.getStreams(currentImdbId, 'movie');
                renderStreams(streams);
            }

            
        } catch (e) {
            console.error('Error opening details:', e);
            if (streamsList) streamsList.innerHTML = '<div style="color:#ef4444; text-align: right;">Error loading details.</div>';
        }
    }

    // ─── Series Selector ──────────────────────────────────────────────

    /** @type {Function|null} Stored reference for the dropdown-close listener */
    let _dropdownCloseHandler = null;

    /**
     * Set up the season/episode selector for a TV series.
     * Uses a SINGLE global click listener (replaced, never stacked).
     * @param {Object} details - Full TMDB series details with seasons array
     * @param {number|string|null} targetSeason
     * @param {number|string|null} targetEpisode
     */
    async function setupSeriesSelector(details, targetSeason = null, targetEpisode = null) {
        const seriesSelector = DOM.seriesSelector;
        const seasonMenu     = DOM.seasonMenu;
        const seasonLabel    = DOM.seasonLabel;
        const seasonTrigger  = DOM.seasonTrigger;
        const seasonWrapper  = DOM.seasonWrapper;
        const episodeMenu    = DOM.episodeMenu;
        const episodeLabel   = DOM.episodeLabel;
        const episodeTrigger = DOM.episodeTrigger;
        const episodeWrapper = DOM.episodeWrapper;
        const streamsList    = DOM.streamsList;

        seriesSelector.style.display = 'flex';
        streamsList.innerHTML = '';

        let currentSeason  = null;
        let currentEpisode = null;

        const closeAllDropdowns = () => {
            seasonWrapper.classList.remove('open');
            episodeWrapper.classList.remove('open');
        };

        // Remove old global listener if any, then add new one (prevents stacking)
        if (_dropdownCloseHandler) {
            document.removeEventListener('click', _dropdownCloseHandler);
        }
        _dropdownCloseHandler = (e) => {
            if (!e.target.closest('.custom-dropdown')) {
                closeAllDropdowns();
            }
        };
        document.addEventListener('click', _dropdownCloseHandler);

        seasonTrigger.onclick = () => {
            const isOpen = seasonWrapper.classList.contains('open');
            closeAllDropdowns();
            if (!isOpen) seasonWrapper.classList.add('open');
        };

        episodeTrigger.onclick = () => {
            const isOpen = episodeWrapper.classList.contains('open');
            closeAllDropdowns();
            if (!isOpen) episodeWrapper.classList.add('open');
        };

        /**
         * Fetch and render streams for the currently selected episode.
         */
        const fetchStreamsForEpisode = async () => {
            if (!currentSeason || !currentEpisode) return;
            streamsList.innerHTML = '<div style="color:var(--text-muted); text-align:right;">Buscando fontes...</div>';
            const streams = await API.getStreams(`${currentImdbId}:${currentSeason}:${currentEpisode}`, 'series');
            renderStreams(streams);
        };

        /**
         * Load episodes for a given season.
         * @param {number|string} sNum  - Season number
         * @param {string}        sName - Display name for the season
         */
        const loadEpisodes = async (sNum, sName) => {
            currentSeason = sNum;
            seasonLabel.textContent = sName;
            seasonWrapper.classList.remove('open');
            episodeLabel.textContent = 'Carregando...';
            episodeMenu.innerHTML = '';
            streamsList.innerHTML = '';

            try {
                const seasonData = await API.getEpisodes(details.id, sNum);

                if (seasonData.episodes.length === 0) {
                    episodeLabel.textContent = 'Nenhum episódio';
                    return;
                }

                episodeMenu.innerHTML = seasonData.episodes.map((ep) =>
                    `<div class="custom-dropdown-item" data-ep="${ep.episode_number}">${ep.episode_number}. ${ep.name}</div>`
                ).join('');

                const epItems = episodeMenu.querySelectorAll('.custom-dropdown-item');
                epItems.forEach((item) => {
                    item.onclick = () => {
                        epItems.forEach((i) => i.classList.remove('active'));
                        item.classList.add('active');
                        currentEpisode = item.dataset.ep;
                        episodeLabel.textContent = item.textContent;
                        episodeWrapper.classList.remove('open');
                        fetchStreamsForEpisode();
                    };
                });

                if (epItems.length > 0) {
                    let clicked = false;
                    if (targetEpisode) {
                        const targetItem = Array.from(epItems).find(i => i.dataset.ep == targetEpisode);
                        if (targetItem) {
                            targetItem.click();
                            clicked = true;
                        }
                    }
                    if (!clicked) epItems[0].click();
                }
            } catch (e) {
                episodeLabel.textContent = 'Erro ao carregar';
            }
        };

        const seasons = details.seasons.filter((s) => s.season_number > 0);

        if (seasons.length > 0) {
            seasonMenu.innerHTML = seasons.map((s) =>
                `<div class="custom-dropdown-item" data-season="${s.season_number}">${s.name}</div>`
            ).join('');

            const seasonItems = seasonMenu.querySelectorAll('.custom-dropdown-item');
            seasonItems.forEach((item) => {
                item.onclick = () => {
                    seasonItems.forEach((i) => i.classList.remove('active'));
                    item.classList.add('active');
                    loadEpisodes(item.dataset.season, item.textContent);
                };
            });

            let clickedSeason = false;
            if (targetSeason) {
                const targetItem = Array.from(seasonItems).find(i => i.dataset.season == targetSeason);
                if (targetItem) {
                    targetItem.click();
                    clickedSeason = true;
                }
            }
            if (!clickedSeason) seasonItems[0].click();
        } else {
            seasonLabel.textContent = 'Sem temporadas';
            episodeLabel.textContent = 'Sem episódios';
        }
    }

    // ─── Stream Rendering ─────────────────────────────────────────────

    /**
     * Render the list of streaming sources.
     * @param {Array} streams - Array of Stremio-format stream objects
     */
    function renderStreams(streams) {
        const container = DOM.streamsList;
        currentStreams = streams;

        if (!streams || streams.length === 0) {
            container.innerHTML = '<div style="color:#ef4444; text-align: right;">NO SOURCES FOUND</div>';
            return;
        }

        const fragment = document.createDocumentFragment();

        streams.forEach((s, idx) => {
            const provider     = s.name || 'Unknown';
            let qualityTitle   = s.title || s.description || `Option ${idx + 1}`;
            qualityTitle       = qualityTitle.replace(/\\n|\n/g, ' • ');

            let sizeTag = '';
            if (s.behaviorHints && s.behaviorHints.videoSize) {
                const bytes = s.behaviorHints.videoSize;
                if (bytes > 1073741824) {
                    sizeTag = `<span style="background: #3b82f6; color: #fff; font-size: 10px; padding: 2px 6px; border-radius: 4px; margin-left: 8px; font-weight: 800;">📦 ${(bytes / 1073741824).toFixed(2)} GB</span>`;
                } else {
                    sizeTag = `<span style="background: #3b82f6; color: #fff; font-size: 10px; padding: 2px 6px; border-radius: 4px; margin-left: 8px; font-weight: 800;">📦 ${(bytes / 1048576).toFixed(2)} MB</span>`;
                }
            } else {
                const sizeMatch = qualityTitle.match(/(\d+(?:\.\d+)?)\s*(GB|MB)/i);
                if (sizeMatch) {
                    sizeTag = `<span style="background: #3b82f6; color: #fff; font-size: 10px; padding: 2px 6px; border-radius: 4px; margin-left: 8px; font-weight: 800;">📦 ${sizeMatch[0].toUpperCase()}</span>`;
                }
            }

            const entry = document.createElement('div');
            entry.className = 'stream-entry';
            entry.innerHTML = `
                <div class="stream-entry-info" style="flex:1; cursor: pointer;">
                    <span class="stream-entry-name">${provider} ${sizeTag}</span>
                    <span class="stream-entry-desc">${qualityTitle}</span>
                </div>
                <div class="stream-entry-actions" style="display: flex; gap: 8px;">
                    <button onclick="watchNative(${idx})" title="Assistir Nativo (AirPlay)" style="background: none; border: none; cursor: pointer; color: white; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; transition: background 0.2s;">
                        <i data-lucide="monitor-play"></i>
                    </button>
                    <button onclick="castStream(${idx})" title="Transmitir (Chromecast)" style="background: none; border: none; cursor: pointer; color: white; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; transition: background 0.2s;">
                        <i data-lucide="cast"></i>
                    </button>
                    <button onclick="downloadStream(${idx})" title="Baixar" style="background: none; border: none; cursor: pointer; color: white; display: flex; align-items: center; justify-content: center; width: 40px; height: 40px; border-radius: 50%; transition: background 0.2s;">
                        <i data-lucide="download"></i>
                    </button>
                </div>`;

            // Parse lucide icons for the newly added buttons
            setTimeout(() => { if(window.lucide) window.lucide.createIcons(); }, 10);

            fragment.appendChild(entry);
        });

        container.innerHTML = '';
        container.appendChild(fragment);
        
    }

    // ─── Download Helper ──────────────────────────────────────────────

    /**
     * Open a stream URL in a new tab (with CORS proxy fallback for HTTP).
     * @param {number} index - Index into currentStreams
     */
    async function downloadStream(index) {
        const stream = currentStreams[index];
        if (stream && stream.url) {
            let finalUrl = stream.url;
            if (finalUrl.startsWith('http://')) {
                finalUrl = 'https://sabuflix.ru1731998.workers.dev/?url=' + encodeURIComponent(finalUrl);
            }
            window.open(finalUrl, '_blank');
        }
    }

    /**
     * Launch native HTML5 player (supports AirPlay on iOS)
     */
    function watchNative(index) {
        const stream = currentStreams[index];
        if (stream && stream.url) {
            let finalUrl = stream.url;
            if (finalUrl.startsWith('http://')) {
                finalUrl = 'https://sabuflix.ru1731998.workers.dev/?url=' + encodeURIComponent(finalUrl);
            }
            openOfflinePlayer(finalUrl, currentMovie.title || currentMovie.name);
        }
    }

    /**
     * Chromecast Integration via Google Cast API
     */
    function castStream(index) {
        const stream = currentStreams[index];
        if (!stream || !stream.url) return;

        let finalUrl = stream.url;
        if (finalUrl.startsWith('http://')) {
            finalUrl = 'https://sabuflix.ru1731998.workers.dev/?url=' + encodeURIComponent(finalUrl);
        }

        if (typeof cast === 'undefined' || !cast.framework) {
            alert('Chromecast não está disponível ou a API do Google Cast não carregou.');
            return;
        }

        const castContext = cast.framework.CastContext.getInstance();
        
        // If not connected, prompt to connect
        if (castContext.getCastState() !== cast.framework.CastState.CONNECTED) {
            castContext.requestSession().then(() => {
                sendMediaToChromecast(finalUrl);
            }).catch(e => {
                console.error('Cast session failed:', e);
            });
        } else {
            sendMediaToChromecast(finalUrl);
        }
    }

    function sendMediaToChromecast(url) {
        const castSession = cast.framework.CastContext.getInstance().getCurrentSession();
        if (!castSession) return;

        const mediaInfo = new chrome.cast.media.MediaInfo(url, 'video/mp4');
        mediaInfo.metadata = new chrome.cast.media.GenericMediaMetadata();
        mediaInfo.metadata.metadataType = chrome.cast.media.MetadataType.GENERIC;
        mediaInfo.metadata.title = currentMovie.title || currentMovie.name;
        
        const request = new chrome.cast.media.LoadRequest(mediaInfo);
        
        castSession.loadMedia(request).then(
            () => alert('Reproduzindo no Chromecast!'),
            (errorCode) => alert('Erro ao transmitir: ' + errorCode)
        );
    }

    // ─── Offline Player ───────────────────────────────────────────────

    /**
     * Opens a local video file in a native HTML5 video player.
     * @param {string} localPath - Native path or URI of the video file
     * @param {string} title - Title of the video
     */
    function openOfflinePlayer(localPath, title) {
        if (!localPath) return;

        const overlay = document.getElementById('playerOverlay');
        const plyrWrapper = document.getElementById('plyrWrapper');
        const fallback = document.getElementById('videoFallbackContainer');

        if (!overlay || !plyrWrapper || !fallback) return;

        // Hide iframe, show native video container
        plyrWrapper.style.display = 'none';
        fallback.style.display = 'block';
        fallback.className = 'video-fallback'; // remove hidden class

        // Convert the native file path to a URL the WebView can load
        let webViewUrl = localPath;
        if (window.Capacitor && window.Capacitor.convertFileSrc) {
            webViewUrl = window.Capacitor.convertFileSrc(localPath);
        }

        fallback.innerHTML = `
            <video controls autoplay webkit-playsinline playsinline x-webkit-airplay="allow" style="width: 100%; height: 100%; object-fit: contain; background: black;">
                <source src="${webViewUrl}" type="video/mp4">
                Seu navegador não suporta a tag de vídeo.
            </video>
        `;

        overlay.classList.add('active');

        // Override close button just for the offline player
        const closeBtn = document.getElementById('closePlayer');
        if (closeBtn) {
            // Remove previous listeners by replacing the node (easiest way)
            const newCloseBtn = closeBtn.cloneNode(true);
            closeBtn.parentNode.replaceChild(newCloseBtn, closeBtn);

            newCloseBtn.addEventListener('click', () => {
                fallback.innerHTML = '';
                fallback.style.display = 'none';
                plyrWrapper.style.display = 'block';
                overlay.classList.remove('active');
                
                // Re-setup standard modal events to restore iframe logic
                if (typeof setupModalEvents === 'function') setupModalEvents();
            });
        }
    }

    // Expose globally
    window.openOfflinePlayer = openOfflinePlayer;
    window.downloadStream = downloadStream;
    window.watchNative = watchNative;
    window.castStream = castStream;

    // Inicializa as opções padrão de cast se o Cast SDK carregar
    window.__onGCastApiAvailable = function(isAvailable) {
        if (isAvailable) {
            cast.framework.CastContext.getInstance().setOptions({
                receiverApplicationId: chrome.cast.media.DEFAULT_MEDIA_RECEIVER_APP_ID,
                autoJoinPolicy: chrome.cast.AutoJoinPolicy.ORIGIN_SCOPED
            });
        }
    };

    // ─── Modal Events ─────────────────────────────────────────────────

    /**
     * Wire up modal close button and keyboard shortcuts.
     */
    function setupModalEvents() {
        const modal    = DOM.detailsModal;
        const closeBtn = DOM.closeDetails;

        if (closeBtn) {
            closeBtn.addEventListener('click', () => {
                modal.classList.remove('active');
                if (window.player) window.player.closePlayer();
                // Clean up dropdown listener
                if (_dropdownCloseHandler) {
                    document.removeEventListener('click', _dropdownCloseHandler);
                    _dropdownCloseHandler = null;
                }
            });
        }
    }

    // ─── Keyboard Support ─────────────────────────────────────────────

    /**
     * Global keyboard handler: Escape closes modals/overlays.
     */
    function setupKeyboard() {
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                // Close search overlay
                if (DOM.searchOverlay && DOM.searchOverlay.classList.contains('active')) {
                    DOM.searchOverlay.classList.remove('active');
                    return;
                }
                // Close details modal
                if (DOM.detailsModal && DOM.detailsModal.classList.contains('active')) {
                    DOM.detailsModal.classList.remove('active');
                    if (window.player) window.player.closePlayer();
                    if (_dropdownCloseHandler) {
                        document.removeEventListener('click', _dropdownCloseHandler);
                        _dropdownCloseHandler = null;
                    }
                }
            }
        });
    }

    // ─── Init ─────────────────────────────────────────────────────────

    /**
     * Bootstrap the entire application.
     */
    function initApp() {
        cacheDOMRefs();
        createLazyObserver();
        setupModalEvents();
        setupKeyboard();
        setupSearch();
        setupCardDelegation();
        setupSidebar(); // this also loads the persisted tab
    }

    // 🛠️ Entry Point 🛠️
    document.addEventListener('DOMContentLoaded', () => {
        initApp();
    });

    // --- Haptic Feedback for Mobile ---
    document.addEventListener('click', (e) => {
        const interactiveElement = e.target.closest('button, a, .poster-card, .btn-icon, .btn-primary, .pill-btn, .custom-dropdown-trigger, .bottom-nav-item');
        if (interactiveElement && navigator.vibrate) {
            navigator.vibrate(15);
        }
    });
})();
