// @ts-check
'use strict';

let userDownloads = [];
let saveToDownloads;
let getDownloads;
let removeDownload;
let isNativeDownloadAvailable;

(function () {
    const STORAGE_KEY = 'sabuflix_downloads';

    function _getDownloads() {
        try {
            const data = localStorage.getItem(STORAGE_KEY);
            return data ? JSON.parse(data) : [];
        } catch (err) {
            console.error('Failed to read downloads list', err);
            return [];
        }
    }

    function _saveToDownloads(movieItem, localPath, fileName) {
        let list = _getDownloads();
        
        // Check if already exists
        const tmdbId = movieItem.id ? movieItem.id.toString() : movieItem.tmdb_id;
        list = list.filter(i => i.tmdb_id !== tmdbId);

        list.unshift({
            tmdb_id: tmdbId,
            media_type: movieItem.media_type || 'movie',
            title: movieItem.title || movieItem.name,
            poster_path: movieItem.poster_path,
            local_path: localPath,
            file_name: fileName,
            downloaded_at: new Date().toISOString()
        });

        localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
    }

    function _removeDownload(tmdbId) {
        let list = _getDownloads();
        list = list.filter(i => i.tmdb_id !== tmdbId.toString());
        localStorage.setItem(STORAGE_KEY, JSON.stringify(list));
    }

    function _isNativeDownloadAvailable() {
        return window.Capacitor && window.Capacitor.isNativePlatform();
    }

    // Expose APIs
    getDownloads = _getDownloads;
    saveToDownloads = _saveToDownloads;
    removeDownload = _removeDownload;
    isNativeDownloadAvailable = _isNativeDownloadAvailable;

})();
