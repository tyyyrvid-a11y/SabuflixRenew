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

(function () {
    const STORAGE_KEY = 'sabuflix_my_list';

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

    // Expose public API
    toggleMyList = _toggleMyList;
    getFullMyList = _getFullMyList;
    fetchMyList = _fetchMyList;

    // Bootstrap
    document.addEventListener('DOMContentLoaded', async () => {
        await _fetchMyList();
        // Garante que o menu lateral apareça para todos os usuários
        const navMyList = document.getElementById('navMyList');
        if (navMyList) navMyList.style.display = 'inline-flex';
    });
})();
