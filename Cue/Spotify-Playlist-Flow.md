# Spotify: Show & Edit Playlists — What We’re Doing

## Goal
Let the user **see their playlists**, **open one** to see its tracks, and **edit it** (remove/reorder). All playlist reads use the **Web API token** that has playlist scopes (from “Allow creating playlists” / PKCE).

---

## 1. Load “My playlists”
- **Trigger:** User taps **Load** in the “My playlists” section.
- **Code:** `SpotifySearchViewModel.loadMyPlaylists()` → `SpotifySearchService.getMyPlaylists(limit: 50)`.
- **API:** `GET /v1/me/playlists`.
- **Auth:** Web API token (playlist-read).
- **Result:** List of playlists (id, name, …) stored in `viewModel.myPlaylists` and shown as tappable chips.

---

## 2. Open a playlist (show its tracks)
- **Trigger:** User taps a playlist name in “My playlists”.
- **Code:** `SpotifySearchViewModel.selectPlaylistForEditing(playlist)`.
  - Sets `selectedPlaylistForEditing = playlist`, clears `playlistTracks`, sets `isLoadingPlaylistTracks = true`.
  - Calls **`SpotifySearchService.getPlaylistWithTracks(playlistId: playlist.id)`**.
    - **API:** `GET /v1/playlists/{id}` (no `fields`; full response).
    - **Auth:** Same playlist-read token (`setAuthForPlaylistRead`).
    - **Response:** JSON with `snapshot_id` and `tracks: { items: [ { track: { … } }, … ] }`.
    - **Parsing:** `parsePlaylistTrackEntries(data)` finds the items array (from top-level `items`, or `tracks.items`, or `tracks` as array), then for each item decodes `track` into `SpotifyTrack` and builds `[PlaylistTrackItem]`.
  - Sets `playlistSnapshotId` and `playlistTracks`.
  - **If `playlistTracks` is still empty:** Tries fallback **`getPlaylistTracks(playlist.id)`** → `GET /v1/playlists/{id}/tracks` (then `/items` if 404), paginates, same parsing. If that returns tracks, uses those for `playlistTracks`.
  - Sets `isLoadingPlaylistTracks = false`.
- **On error:** Sets `playlistEditError`, clears `selectedPlaylistForEditing`.

---

## 3. What the UI shows when a playlist is “open”
- **Condition:** `viewModel.selectedPlaylistForEditing != nil`.
- **Main content** is `playlistEditContent`:
  - If `isLoadingPlaylistTracks` → “Loading playlist…”.
  - Else if `playlistTracks.isEmpty` → “Playlist tracks” / “No tracks in this playlist.” + hint.
  - Else → “X tracks in playlist” + `List(playlistTracks)` with remove (trash) and reorder (Edit).
- **Header:** “Editing: [playlist name]” and **Done** (calls `closePlaylistEditor()`).

So “empty” means: we’re in this branch but `playlistTracks` is empty after the API call(s) and parsing.

---

## 4. Edit: remove / reorder
- **Remove:** `removeTrackFromPlaylist(item)` → `DELETE /v1/playlists/{id}/items` with body `{ "items": [{ "uri": "..." }] }`, then remove that item from `playlistTracks` and update `playlistSnapshotId` from response.
- **Reorder:** `moveTrack(from:to:)` → `PUT /v1/playlists/{id}/items` with `range_start`, `insert_before`, `range_length`, then reorder `playlistTracks` locally.

---

## 5. Where “empty” can come from
1. **API returns 200 but no items** — playlist really has 0 tracks.
2. **API response shape** — we don’t find `items` (e.g. wrong key or nesting); `rawItems` is nil and fallback decoder returns [].
3. **Parsing fails per track** — we find `rawItems` but every `decodeTrack(from:item)` fails (e.g. missing required field, wrong type), so we get 0 `PlaylistTrackItem`s.
4. **Wrong token** — e.g. 403 or empty payload; we’d usually see an error message, but worth confirming we use the Web API token that has playlist-read.

The debug logging we add will show: request path, response keys, which branch found the items, raw count, parsed count, and any decode failures so we can see which of these is happening.
