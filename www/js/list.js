// @ts-check
'use strict';

/**
 * @fileoverview SabuFlix Local List Module
 * Handles the "My List" feature entirely offline via localStorage.
 * Replaces the old Supabase auth module.
 */

let userMyList = [];
let toggleMyList;
let getFullMyList;
let fetchMyList;
let saveToContinueWatching;
let getContinueWatching;

(function () {
    const STORAGE_KEY = 'sabuflix_my_list';
    const CONTINUE_WATCHING_KEY = 'sabuflix_continue_watching';

    /**
     * Load the list from local storage.
     * Populates the global `userMyList` array with TMDB IDs.
     */
    async function _fetchMyList() {
        try {
            const data = localStorage.getItem(STORAGE_KEY);
            if (data) {
                const parsed = JSON.parse(data);
                userMyList = parsed.map(item => item.tmdb_id.toString());
            }
        } catch (err) {
            console.error('Failed to load local list', err);
            userMyList = [];
        }
    }

    /**
     * Return the full My List rows (with metadata).
     * @returns {Promise<Array>} Array of list item objects
     */
    async function _getFullMyList() {
        try {
            const data = localStorage.getItem(STORAGE_KEY);
            return data ? JSON.parse(data) : [];
        } catch (err) {
            console.error('Failed to read full local list', err);
            return [];
        }
    }

    /**
     * Add or remove an item from the user's list.
     * @param {Object} itemDetails - TMDB item object (must include `id`)
     * @param {string} mediaType   - 'movie' ou 'tv'
     * @returns {Promise<boolean>} true = added, false = removed
     */
    async function _toggleMyList(itemDetails, mediaType) {
        const tmdbId = itemDetails.id.toString();
        let list = [];
        try {
            const data = localStorage.getItem(STORAGE_KEY);
            if (data) list = JSON.parse(data);
        } catch (err) {}

        const isSaved = list.some(i => i.tmdb_id.toString() === tmdbId);

        if (isSaved) {
            list = list.filter(i => i.tmdb_id.toString() !== tmdbId);
            userMyList = userMyList.filter(id => id !== tmdbId);
        } else {
            list.unshift({
                tmdb_id: tmdbId,
                media_type: mediaType,
                title: itemDetails.title || itemDetails.name,
                poster_path: itemDetails.poster_path,
                created_at: new Date().toISOString()
            });
            userMyList.push(tmdbId);
        }

        localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
        return !isSaved;
    }

    /**
     * Save an item to the "Continue Watching" list.
     * Moves it to the front if it already exists.
     * @param {Object} itemDetails - TMDB item object
     * @param {string} mediaType   - 'movie' ou 'tv'
     * @param {number|null} season 
     * @param {number|null} episode 
     */
    function _saveToContinueWatching(itemDetails, mediaType, season = null, episode = null) {
        const tmdbId = itemDetails.id.toString();
        let list = [];
        try {
            const data = localStorage.getItem(CONTINUE_WATCHING_KEY);
            if (data) list = JSON.parse(data);
        } catch (err) {}

        // Remove if exists to move to top
        list = list.filter(i => i.tmdb_id.toString() !== tmdbId);

        list.unshift({
            tmdb_id: tmdbId,
            media_type: mediaType,
            title: itemDetails.title || itemDetails.name,
            poster_path: itemDetails.poster_path,
            season: season,
            episode: episode,
            updated_at: new Date().toISOString()
        });

        // Limit to 20 items
        if (list.length > 20) {
            list = list.slice(0, 20);
        }

        localStorage.setItem(CONTINUE_WATCHING_KEY, JSON.stringify(list));
    }

    /**
     * Get the "Continue Watching" list.
     * @returns {Array} Array of history items
     */
    function _getContinueWatching() {
        try {
            const data = localStorage.getItem(CONTINUE_WATCHING_KEY);
            return data ? JSON.parse(data) : [];
        } catch (err) {
            console.error('Failed to read continue watching list', err);
            return [];
        }
    }

    // Expose public API
    toggleMyList = _toggleMyList;
    getFullMyList = _getFullMyList;
    fetchMyList = _fetchMyList;
    saveToContinueWatching = _saveToContinueWatching;
    getContinueWatching = _getContinueWatching;

    // Bootstrap
    document.addEventListener('DOMContentLoaded', async () => {
        await _fetchMyList();
        // Garante que o menu lateral apareça para todos os usuários
        const navMyList = document.getElementById('navMyList');
        if (navMyList) navMyList.style.display = 'inline-flex';
    });
})();
