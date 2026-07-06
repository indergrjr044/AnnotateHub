# CollabMark - Collaborative Document Annotation System

CollabMark is a full-stack, real-time Collaborative Document Annotation System built using the MERN stack (MongoDB, Express, React, Node.js) and Socket.io. Users can upload text or PDF documents, highlight text ranges, attach comments, and view annotations and presence of other users in real-time.

---

## Schema Design Rationale

### 1. `User` Schema
Holds name, email, and password hash.
- **Index**: Unique index on `email` to ensure fast login lookups and prevent duplicate accounts.

### 2. `Document` Schema
Contains core file metadata (`title`, `mimeType`, `storagePath`, `originalFilename`, `size`), plus:
- `extractedText`: Stores the flat plain text string representation of the document.
- `pages`: An array of `{ pageNumber, text }` elements. This page-by-page mapping is only used for PDF documents, allowing the character offsets of highlights to be calculated relative to each page.
- **Index**: Index on `uploadedBy` for filtering documents by owner.

### 3. `Annotation` Schema
Stores annotations with the following structure:
- `documentId`: References the document.
- `userId`: References the user.
- `userName`: **Denormalized** string copy of the user's name. This avoids costly population database queries during high-frequency Socket.io broadcasts.
- `pageNumber`: Page index (null for plain text docs).
- `startOffset` / `endOffset`: Character range of the highlight.
- `selectedText`: A snapshot of the text highlighted, ensuring resilience if text representations shift.
- `comment`: User notes.

#### Critical Indexes:
- **Compound Unique Index**: `{ documentId: 1, userId: 1, startOffset: 1, endOffset: 1 }`. This enforces at the database layer that a user cannot create duplicate annotations on the exact same selection.
- **Query Index**: `{ documentId: 1, startOffset: 1 }`. Extremely important for fetching sorted highlights when opening documents, achieving \(O(\log N)\) performance.

---

## Overlapping Ranges & Duplicate Prevention

### 1. Overlapping Ranges Algorithm (Segment Splitting)
If users highlight overlapping or nested ranges (e.g. User A selects `[0, 10]`, User B selects `[5, 15]`), nested HTML elements would result in invalid layouts or DOM breakage.
To handle this correctly, we split the document text into non-overlapping **intervals** at load time:
1. Extract all annotation `startOffset` and `endOffset` values, along with `0` and the document length.
2. Sort these values in ascending order and remove duplicates to create a clean set of boundary markers.
3. Iterate through consecutive pairs of markers to form segments (e.g., `[0, 5]`, `[5, 10]`, `[10, 15]`).
4. Map each segment to the set of annotations covering it.
5. Render each segment inside a single `<span>`. If multiple annotations cover the segment, we render a linear gradient of the users' colors, showing a visually merged segment. Clicking it presents all overlapping annotations in the sidebar.

### 2. Duplicate Prevention
In addition to frontend warnings, MongoDB enforces duplicate prevention with its compound unique index. If a duplicate request hits the API, MongoDB rejects the insert with error code `11000`. The Express centralized `errorHandler` captures this, converts the response to a `409 Conflict` (along with a user-facing explanation), and the frontend shows an inline warning toast instead of crashing or leaking a `500 Server Error`.

---

## Performance Optimizations

1. **Query Optimization**: Covered by the compound and query indexes, converting scans to index seeks.
2. **Denormalization**: `userName` is denormalized directly on the annotation, eliminating DB join overhead.
3. **Sidebar Virtualization**: Utilizing `react-window` to virtualize the comments feed. In documents with 1000+ annotations, only cards currently visible in the scroll viewport are rendered in the DOM, eliminating layout calculations lag.
4. **Optimistic UI Updates**: Annotations, edits, and deletions are rendered locally immediately. A header `X-Socket-ID` is passed with API requests to exclude the sender from Socket broadcasts, avoiding double-processing.
5. **PDF Text Extraction**: We extract page text sequentially and cache page text lengths. The frontend uses `react-pdf`'s `customTextRenderer` to dynamically inject selection highlights page by page.

---

## Getting Started

### Prerequisites
- Node.js (v18+)
- MongoDB running locally on `mongodb://127.0.0.1:27017`

### Installation
From the root directory, run:
```bash
# Install dependencies in server, client, and root
npm run install-all
```

### Running the App
Start both frontend and backend concurrently in development mode:
```bash
npm run dev
```
- **Backend Server**: Runs on `http://localhost:5000`
- **Frontend Client**: Runs on `http://localhost:5173`

### Seeding Performance Test Data (1000+ Annotations)
To verify database index and virtualization performance, run the seed script:
```bash
cd server
node src/scripts/seed.js
```
This will insert a document and generate 1000 annotations on it, verifying that query scans utilize the `IXSCAN` index and resolve in under ~50ms.

---

## Known Limitations & Future Improvements

1. **PDF Coordinates**: Native PDF formats are complex. If a PDF text layer splits characters into separate absolute elements, selection boundaries might shift slightly compared to plain text.
2. **S3 File Storage**: Currently stores files under `server/uploads/` using Multer. The file upload/deletion functions are encapsulated in `src/services/storage.js`, meaning swapping to S3 will only require changing this single service layer.
3. **Presence cursors**: Real-time presence currently tracks users viewing the document in the header. We could improve it by rendering cursors directly over text lines (collaborator cursor tracking).
