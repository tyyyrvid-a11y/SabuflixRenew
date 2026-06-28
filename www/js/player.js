/**
 * @fileoverview SabuFlix Player — manages the fullscreen video overlay.
 *
 * Features:
 *  - Escape key closes the player
 *  - Loading spinner while iframe loads
 *  - Embed URL validation
 *  - history.pushState so the browser back button closes the player
 *  - Parameter validation for tmdbId / season / episode
 *  - Proper event listener cleanup via AbortController
 */

class SabuflixPlayer {
    /**
     * Create the player instance and bind to DOM elements.
     * Expects the following elements to exist:
     *  - #playerOverlay
     *  - #closePlayer
     *  - #mainPlayer        (iframe)
     *  - #plyrWrapper
     *  - #videoFallbackContainer
     */
    constructor() {
        /** @type {HTMLElement} */
        this.overlay = document.getElementById('playerOverlay');
        /** @type {HTMLElement} */
        this.closeBtn = document.getElementById('closePlayer');
        /** @type {HTMLIFrameElement} */
        this.iframeEl = document.getElementById('mainPlayer');
        /** @type {HTMLElement} */
        this.plyrWrapper = document.getElementById('plyrWrapper');
        /** @type {HTMLElement} */
        this.fallbackContainer = document.getElementById('videoFallbackContainer');

        /** Whether the player overlay is currently visible. */
        this.isOpen = false;

        /**
         * AbortController used to cleanly remove all event listeners
         * when the player instance is destroyed.
         * @type {AbortController}
         */
        this._abortController = new AbortController();

        this._setupEventListeners();
    }

    // ─── Event Wiring ────────────────────────────────────────────────────

    /**
     * Attach all event listeners using the shared AbortController signal
     * so they can be cleaned up in one call via {@link destroy}.
     * @private
     */
    _setupEventListeners() {
        const opts = { signal: this._abortController.signal };

        // Close button
        this.closeBtn.addEventListener('click', () => this.closePlayer(), opts);

        // Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && this.isOpen) {
                this.closePlayer();
            }
        }, opts);

        // Browser back button (popstate)
        window.addEventListener('popstate', (e) => {
            if (this.isOpen) {
                // Prevent default navigation; just close the player.
                this.closePlayer(/* pushState */ false);
            }
        }, opts);

        // Iframe load event — hide loading spinner when content is ready
        this.iframeEl.addEventListener('load', () => {
            this._hideLoading();
        }, opts);

        // Iframe error fallback — also hide spinner on error
        this.iframeEl.addEventListener('error', () => {
            this._hideLoading();
            console.warn('Iframe falhou ao carregar o embed.');
        }, opts);
    }

    // ─── Loading State ───────────────────────────────────────────────────

    /**
     * Show a loading indicator on the player wrapper.
     * Adds a CSS class that the stylesheet can use to render a spinner.
     * @private
     */
    _showLoading() {
        this.plyrWrapper.classList.add('player-loading');
    }

    /**
     * Hide the loading indicator.
     * @private
     */
    _hideLoading() {
        this.plyrWrapper.classList.remove('player-loading');
    }

    // ─── Validation ──────────────────────────────────────────────────────

    /**
     * Validate that a TMDB ID looks reasonable.
     * @param {*} tmdbId
     * @returns {boolean}
     * @private
     */
    _isValidId(tmdbId) {
        if (tmdbId === null || tmdbId === undefined) return false;
        const n = Number(tmdbId);
        return Number.isFinite(n) && n > 0;
    }

    /**
     * Validate season / episode numbers (must be positive integers when provided).
     * @param {*} value
     * @returns {boolean}
     * @private
     */
    _isValidSeasonOrEpisode(value) {
        if (value === null || value === undefined) return true; // optional
        const n = Number(value);
        return Number.isInteger(n) && n > 0;
    }

    // ─── Embed URL Builders ──────────────────────────────────────────────

    /**
     * Build the embed URL for a given server.
     *
     * @param {number|string} tmdbId
     * @param {string}        type      'movie', 'FILM', 'tv', 'series', etc.
     * @param {number|null}   season
     * @param {number|null}   episode
     * @param {number}        server    1 or 2
     * @returns {string}
     * @throws {Error} If parameters are invalid.
     * @private
     */
    _buildEmbedUrl(tmdbId, type, season, episode, server) {
        const isMovie = (type === 'movie' || type === 'FILM');

        if (server === 1) {
            return isMovie
                ? `https://fembed.sx/e/${tmdbId}`
                : `https://fembed.sx/e/${tmdbId}/${season}-${episode}`;
        }

        // server 2
        return isMovie
            ? `https://mgeb.top/embed/${tmdbId}`
            : `https://mgeb.top/embed/${tmdbId}/${season}/${episode}`;
    }

    // ─── Public Methods ──────────────────────────────────────────────────

    /**
     * Open the player overlay and load an embed URL.
     *
     * @param {number|string} tmdbId   TMDB numeric ID.
     * @param {string}        type     'movie', 'FILM', 'tv', 'series', etc.
     * @param {number|null}   [season=null]   Season number (required for series).
     * @param {number|null}   [episode=null]  Episode number (required for series).
     * @param {number}        [server=1]      Embed server: 1 or 2.
     */
    playEmbed(tmdbId, type, season = null, episode = null, server = 1) {
        // ── Validate ─────────────────────────────────────────────────────
        if (!this._isValidId(tmdbId)) {
            console.error('playEmbed: tmdbId inválido:', tmdbId);
            return;
        }

        const isMovie = (type === 'movie' || type === 'FILM');

        if (!isMovie) {
            if (!this._isValidSeasonOrEpisode(season) || !this._isValidSeasonOrEpisode(episode)) {
                console.error('playEmbed: season/episode inválidos:', season, episode);
                return;
            }
            if (season === null || episode === null) {
                console.error('playEmbed: season e episode são obrigatórios para séries.');
                return;
            }
        }

        // ── Build URL ────────────────────────────────────────────────────
        let embedUrl;
        try {
            embedUrl = this._buildEmbedUrl(tmdbId, type, season, episode, server);
        } catch (err) {
            console.error('playEmbed: erro ao montar URL:', err.message);
            return;
        }

        console.log(`Iniciando Embed (Servidor ${server}):`, embedUrl);

        // ── Show loading & open overlay ──────────────────────────────────
        this._showLoading();
        this.iframeEl.src = embedUrl;

        if (this.fallbackContainer) {
            this.fallbackContainer.style.display = 'none';
        }
        this.plyrWrapper.style.display = 'block';
        this.overlay.classList.add('active');
        document.body.style.overflow = 'hidden';

        this.isOpen = true;

        // Push a state so the browser back button can close the player
        history.pushState({ sabuflixPlayer: true }, '');
    }

    /**
     * Close the player overlay and clean up.
     *
     * @param {boolean} [updateHistory=true]  If `true`, pops the history
     *   entry that was pushed when the player opened. Set to `false` when
     *   closing in response to a popstate event (the entry is already gone).
     */
    closePlayer(updateHistory = true) {
        if (!this.isOpen) return;

        this.overlay.classList.remove('active');
        document.body.style.overflow = 'auto';
        this.iframeEl.src = '';
        this._hideLoading();

        this.isOpen = false;

        // If we pushed a state on open, pop it now (unless popstate already did).
        if (updateHistory && history.state && history.state.sabuflixPlayer) {
            history.back();
        }
    }

    /**
     * Remove all event listeners and release resources.
     * Call this if you ever need to tear down the player instance.
     */
    destroy() {
        this.closePlayer(false);
        this._abortController.abort();
    }
}

// ─── Bootstrap ───────────────────────────────────────────────────────────────

window.player = new SabuflixPlayer();
