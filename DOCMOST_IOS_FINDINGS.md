# Docmostly implementation findings

## Docmost repository structure

- Source repo inspected: `/Users/chefski/Documents/dev/Docsmost/docmost`.
- Web client: `apps/client`, a Vite/React app.
- Backend: `apps/server`, a Nest/Fastify API with a global `/api` prefix.
- Shared editor extensions: `packages/editor-ext`.

## Auth and session

- The web client uses Axios with `baseURL: "/api"` and `withCredentials: true`.
- Login posts to `POST /api/auth/login` with `{ email, password }`.
- Successful login sets an HTTP-only `authToken` cookie. The response body is empty unless MFA is required.
- Logout posts to `POST /api/auth/logout` and clears `authToken`.
- Current user/workspace data comes from `POST /api/users/me`.
- Connection validation for a configured server uses public `POST /api/workspace/public`.

## API endpoints used

- Workspace public info: `POST /api/workspace/public`
- Current user: `POST /api/users/me`
- Spaces list: `POST /api/spaces`
- Space info: `POST /api/spaces/info`
- Page tree/sidebar: `POST /api/pages/sidebar-pages`
- Page detail/content: `POST /api/pages/info`
- Recent pages: `POST /api/pages/recent`
- Search: `POST /api/search`
- Comments: `POST /api/comments`, `POST /api/comments/create`
- Attachment info/download: `POST /api/files/info`, `GET /api/files/:fileId/:fileName`

All standard API responses are wrapped by Docmost's `TransformHttpResponseInterceptor` as `{ data, success, status }`, so the native client unwraps that envelope.

## Editor and realtime stack

- Docmost stores page content as Tiptap/ProseMirror JSON.
- Realtime editing uses Yjs with Hocuspocus. The web editor creates `page.{pageId}` Yjs documents and connects to `/collab` using `POST /api/auth/collab-token`.
- The native v1 does not attempt full native editing. It opens the existing web page route (`/s/{spaceSlug}/p/{page-slug}`) inside `WKWebView` for edit compatibility.

## Design colours extracted

- Primary blue scale from `apps/client/src/theme.ts`: `#0b60d8`, `#1b72f2`, `#2b7af1`, light tint `#e7f3ff`.
- Error red scale includes `#bc2727` and `#d43535`.
- Accessibility overrides use stronger gray text such as `#4b5563` and placeholder `#686868`.

## Short implementation plan

1. Build typed URL validation, request construction, response decoding, cookie/session persistence, and SwiftData cache models first.
2. Implement the native shell with server setup, login, spaces, lazy page tree, HTML page reader, search, settings, and offline cached reads.
3. Use server-rendered HTML (`format: "html"`) for safe document display and open the existing web route for editing.
4. Add Swift Testing coverage for URL validation, request building, session persistence abstraction, page tree decoding, and search decoding.

## Implemented in this pass

- Native SwiftUI app shell with server setup, login, spaces, lazy page tree, page reader, search, comments, settings, and editor WebView fallback.
- Cookie-based auth handling for URLSession and WKWebView.
- SwiftData cache for spaces, page tree entries, recently opened pages, and discovered attachment links.
- Offline read mode for previously opened pages and cached tree/spaces.

## Deferred or constrained

- Full native Tiptap/Yjs editing is deferred to avoid content corruption.
- Offline editing is intentionally not implemented.
- Attachment upload is deferred.
- Attachment listing is derived from rendered page HTML links because Docmost does not expose a simple page attachment list endpoint in the inspected API.

## Risks and unknowns

- The configured self-hosted server URL is intentionally not hardcoded; set `AppConfig.defaultServerURLString` when the deployment URL is known.
- MFA response handling is detected but not fully implemented; the app reports that MFA must be completed in the web app for v1.
- Server-side HTML generation is trusted as the safest v1 rendering path. Unsupported rich blocks are shown by the server-rendered HTML rather than by a native renderer.
