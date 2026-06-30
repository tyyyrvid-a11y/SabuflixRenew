// @ts-check
/**
 * @fileoverview SabuFlix API module — TMDB + Stremio addon integration.
 *
 * Features:
 *  - Response status checking (throws on non-2xx from TMDB)
 *  - 8-second request timeout via AbortController
 *  - In-memory cache (Map) with 5-minute TTL for TMDB responses
 *  - 1-retry logic for failed addon requests
 *  - Type normalization ('series' → 'tv')
 */

// ─── Constants ───────────────────────────────────────────────────────────────

const TMDB_API_KEY = 'ee0794f59f93b7a056bb76ef52dc28d0';
const TMDB_BASE_URL = 'https://api.themoviedb.org/3';

/** Stremio-compatible addon base URLs. */
const ADDONS = [
    'https://fenixflix-ur9u.onrender.com',
    'https://froststream.cloutteam.com'
];

const REQUEST_TIMEOUT_MS = 8000;
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes

// ─── Custom Errors ───────────────────────────────────────────────────────────

/** Thrown when a TMDB API request returns a non-2xx status. */
class TMDBError extends Error {
    /**
     * @param {string} message
     * @param {number} status
     * @param {string} url
     */
    constructor(message, status, url) {
        super(message);
        this.name = 'TMDBError';
        this.status = status;
        this.url = url;
    }
}

/** Thrown when a request exceeds the timeout limit. */
class TimeoutError extends Error {
    /**
     * @param {string} url
     */
    constructor(url) {
        super(`Request timed out after ${REQUEST_TIMEOUT_MS}ms`);
        this.name = 'TimeoutError';
        this.url = url;
    }
}

/** Thrown when all addon streams fail to resolve. */
class AddonError extends Error {
    /**
     * @param {string} message
     * @param {Error[]} errors
     */
    constructor(message, errors = []) {
        super(message);
        this.name = 'AddonError';
        this.errors = errors;
    }
}

// ─── Cache ───────────────────────────────────────────────────────────────────

/** @type {Map<string, {data: any, expiresAt: number}>} */
const _cache = new Map();

/**
 * Return cached data if present and not expired, otherwise `undefined`.
 * @param {string} key
 * @returns {any|undefined}
 */
function _cacheGet(key) {
    const entry = _cache.get(key);
    if (!entry) return undefined;
    if (Date.now() > entry.expiresAt) {
        _cache.delete(key);
        return undefined;
    }
    return entry.data;
}

/**
 * Store a value in cache with the default TTL.
 * @param {string} key
 * @param {any}    data
 */
function _cacheSet(key, data) {
    _cache.set(key, { data, expiresAt: Date.now() + CACHE_TTL_MS });
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/**
 * Normalize media type so callers can pass 'series', 'tv', 'show', etc.
 * TMDB only accepts 'movie' or 'tv'.
 * @param {string} type
 * @returns {'movie'|'tv'}
 */
function _normalizeType(type) {
    if (!type) return 'movie';
    const t = type.toLowerCase().trim();
    if (t === 'movie' || t === 'film') return 'movie';
    return 'tv'; // 'tv', 'series', 'show', etc. → 'tv'
}

/**
 * Fetch with an 8-second timeout via AbortController.
 * @param {string} url
 * @param {RequestInit} [opts]
 * @returns {Promise<Response>}
 */
async function _fetchWithTimeout(url, opts = {}) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
    try {
        const res = await fetch(url, { ...opts, signal: controller.signal });
        return res;
    } catch (err) {
        if (err.name === 'AbortError') throw new TimeoutError(url);
        throw err;
    } finally {
        clearTimeout(timer);
    }
}

/**
 * Fetch a TMDB endpoint, validate the response, cache it, and return JSON.
 * @param {string} url  Full TMDB URL (including api_key).
 * @returns {Promise<any>}
 * @throws {TMDBError}   On non-2xx responses.
 * @throws {TimeoutError} If the request exceeds 8 s.
 */
async function _tmdbFetch(url) {
    const cached = _cacheGet(url);
    if (cached) return cached;

    const res = await _fetchWithTimeout(url);
    if (!res.ok) {
        throw new TMDBError(
            `TMDB responded with ${res.status} ${res.statusText}`,
            res.status,
            url
        );
    }

    const data = await res.json();
    _cacheSet(url, data);
    return data;
}

/**
 * Fetch a single addon URL with 1 automatic retry on failure.
 * @param {string} url
 * @returns {Promise<any[]>}  Array of stream objects (or empty on failure).
 */
async function _addonFetchWithRetry(url) {
    for (let attempt = 0; attempt < 2; attempt++) {
        try {
            const res = await _fetchWithTimeout(url);
            if (!res.ok) {
                console.warn(`Addon ${url} retornou ${res.status} (tentativa ${attempt + 1})`);
                if (attempt === 0) continue;
                return [];
            }
            const data = await res.json();
            return data.streams || [];
        } catch (err) {
            console.warn(`Addon ${url} falhou (tentativa ${attempt + 1}):`, err.message);
            if (attempt === 0) continue;
            return [];
        }
    }
    return [];
}

// ─── Public API ──────────────────────────────────────────────────────────────

const API = {
    /**
     * Fetch popular movies (page 1).
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async getPopularMovies() {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/movie/popular?api_key=${TMDB_API_KEY}&language=pt-BR&page=1`
        );
    },

    /**
     * Fetch popular TV series (page 1).
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async getPopularSeries() {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/tv/popular?api_key=${TMDB_API_KEY}&language=pt-BR&page=1`
        );
    },

    /**
     * Fetch top-rated movies (page 1).
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async getTopRatedMovies() {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/movie/top_rated?api_key=${TMDB_API_KEY}&language=pt-BR&page=1`
        );
    },

    /**
     * Fetch top-rated TV series (page 1).
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async getTopRatedSeries() {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/tv/top_rated?api_key=${TMDB_API_KEY}&language=pt-BR&page=1`
        );
    },

    /**
     * Fetch weekly trending content (movies + series).
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async getTrending() {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/trending/all/week?api_key=${TMDB_API_KEY}&language=pt-BR`
        );
    },

    /**
     * Fetch full details for a movie or TV show.
     * @param {number|string} id    TMDB ID.
     * @param {string}        [type='movie']  'movie', 'tv', 'series', etc.
     * @returns {Promise<any>}
     */
    async getDetails(id, type = 'movie') {
        const t = _normalizeType(type);
        return _tmdbFetch(
            `${TMDB_BASE_URL}/${t}/${id}?api_key=${TMDB_API_KEY}&language=pt-BR&append_to_response=release_dates,content_ratings`
        );
    },

    /**
     * Fetch external IDs (IMDb, TVDB, etc.) for a title.
     * @param {number|string} id
     * @param {string}        [type='movie']
     * @returns {Promise<any>}
     */
    async getExternalIds(id, type = 'movie') {
        const t = _normalizeType(type);
        return _tmdbFetch(
            `${TMDB_BASE_URL}/${t}/${id}/external_ids?api_key=${TMDB_API_KEY}`
        );
    },

    /**
     * Fetch episodes for a specific TV season.
     * @param {number|string} tvId
     * @param {number}        seasonNumber  1-based season number.
     * @returns {Promise<any>}
     */
    async getEpisodes(tvId, seasonNumber) {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/tv/${tvId}/season/${seasonNumber}?api_key=${TMDB_API_KEY}&language=pt-BR`
        );
    },

    /**
     * Multi-search (movies, TV, people) by query string.
     * @param {string} query
     * @returns {Promise<{results: any[], page: number, total_pages: number}>}
     */
    async search(query) {
        return _tmdbFetch(
            `${TMDB_BASE_URL}/search/multi?api_key=${TMDB_API_KEY}&language=pt-BR&query=${encodeURIComponent(query)}`
        );
    },

    /**
     * Fetch recommendations based on a title.
     * @param {number|string} id
     * @param {string}        [type='movie']
     * @returns {Promise<{results: any[]}>}
     */
    async getRecommendations(id, type = 'movie') {
        const t = _normalizeType(type);
        return _tmdbFetch(
            `${TMDB_BASE_URL}/${t}/${id}/recommendations?api_key=${TMDB_API_KEY}&language=pt-BR&page=1`
        );
    },

    /**
     * Fetch images (posters, backdrops, logos) for a title.
     * @param {number|string} id
     * @param {string}        [type='movie']
     * @returns {Promise<any>}
     */
    async getImages(id, type = 'movie') {
        const t = _normalizeType(type);
        return _tmdbFetch(
            `${TMDB_BASE_URL}/${t}/${id}/images?api_key=${TMDB_API_KEY}&include_image_language=pt,en,null`
        );
    },

    /**
     * Query all configured Stremio addons for streams.
     * Each addon is retried once on failure.
     *
     * @param {string} imdbId  IMDb ID (e.g. 'tt1234567').
     * @param {string} [type='movie']  'movie' or 'series'.
     * @returns {Promise<any[]>}  Flat array of stream objects from all addons.
     */
    async getStreams(imdbId, type = 'movie') {
        try {
            const promises = ADDONS.map((addonBaseUrl) => {
                const url = `${addonBaseUrl}/stream/${type}/${imdbId}.json`;
                return _addonFetchWithRetry(url);
            });

            const results = await Promise.all(promises);
            return results.flat();
        } catch (error) {
            console.error('Erro geral de addons:', error);
            return [];
        }
    },

    /**
     * Discover movies or TV shows by genre, rating, and sort order.
     * @param {object} opts
     * @param {'movie'|'tv'} [opts.type='movie']
     * @param {number[]}     [opts.genres=[]]       TMDB genre IDs (OR logic)
     * @param {number}       [opts.minRating=0]      Minimum vote_average
     * @param {string}       [opts.sort='popularity.desc']
     * @param {number}       [opts.page=1]
     * @returns {Promise<{results: any[]}>}
     */
    async discover({ type = 'movie', genres = [], minRating = 0, sort = 'popularity.desc', page = 1 } = {}) {
        const t = _normalizeType(type);
        let url = `${TMDB_BASE_URL}/discover/${t}?api_key=${TMDB_API_KEY}&language=pt-BR&sort_by=${sort}&page=${page}`;
        if (genres.length) url += `&with_genres=${genres.join(',')}`;
        if (minRating > 0) url += `&vote_average.gte=${minRating}&vote_count.gte=150`;
        return _tmdbFetch(url);
    }
};

window.API = API;
