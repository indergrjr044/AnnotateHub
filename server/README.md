# CollabMark - Backend Service (Express + MongoDB)

This is the Node.js / Express backend service for CollabMark, a real-time collaborative document annotation system. It leverages MongoDB for persistence and Socket.io for active presence and instant document synchronization.

---

## Technical Stack
- **Runtime**: Node.js (v18+)
- **Server Framework**: Express.js
- **Database ORM**: Mongoose (MongoDB)
- **Real-Time Communication**: Socket.io
- **File Parsing**: pdf-parse, Multer

---

## Database Schemas

### 1. `User` Schema
Represents a user profile in the system.
```javascript
{
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true, index: true },
  passwordHash: { type: String, required: true },
  createdAt: { type: Date, default: Date.now }
}
```
- **Index**: Unique index on `email` to accelerate authentication and guarantee record uniqueness.

### 2. `Document` Schema
Stores uploaded text or PDF documents and cached parsed content.
```javascript
{
  title: { type: String, required: true },
  originalFilename: { type: String, required: true },
  mimeType: { type: String, required: true },
  storagePath: { type: String, required: true },
  size: { type: Number, required: true },
  extractedText: { type: String, required: true },
  pages: [{
    pageNumber: { type: Number, required: true },
    text: { type: String, required: true }
  }],
  uploadedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  createdAt: { type: Date, default: Date.now }
}
```
- **Index**: Index on `uploadedBy` for quick ownership queries.

### 3. `Annotation` Schema
Encompasses comment content and selection offsets on documents.
```javascript
{
  documentId: { type: mongoose.Schema.Types.ObjectId, ref: 'Document', required: true, index: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String, required: true },
  pageNumber: { type: Number, default: null }, // Null for plain text docs
  startOffset: { type: Number, required: true },
  endOffset: { type: Number, required: true },
  selectedText: { type: String, required: true },
  comment: { type: String, required: true },
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
}
```
- **Compound Unique Index**: `{ documentId: 1, userId: 1, startOffset: 1, endOffset: 1 }` (unique constraint). Enforces that a user cannot duplicate highlights over the exact same text region twice.
- **Sorted Seek Index**: `{ documentId: 1, startOffset: 1 }`. Optimizes range fetches, achieving $O(\log N)$ seeks when loading documents with 1000+ annotations.

---

## API Specifications

All endpoints are prefixed with `/api`.

### Authentication Endpoints (`/api/auth`)

#### 1. GET `/api/auth/users`
Lists all seeded users. Used on the frontend login page and comment popovers.
- **Request Headers**: None
- **Response** (200 OK):
  ```json
  [
    { "_id": "60d000000000000000000001", "name": "Alice", "email": "alice@example.com" },
    { "_id": "60d000000000000000000002", "name": "Bob", "email": "bob@example.com" }
  ]
  ```

#### 2. POST `/api/auth/login-mock`
Authenticates a user directly by their user ID without requiring credentials (mock mode).
- **Request Body**:
  ```json
  { "userId": "60d000000000000000000001" }
  ```
- **Response** (200 OK):
  ```json
  {
    "token": "eyJhbGciOiJIUzI1Ni...",
    "user": {
      "id": "60d000000000000000000001",
      "name": "Alice",
      "email": "alice@example.com"
    }
  }
  ```

#### 3. POST `/api/auth/login` / POST `/api/auth/register`
Normal JWT credential registration/login pathways.

---

### Document Endpoints (`/api/documents`)

*All document endpoints require a bearer JWT header: `Authorization: Bearer <token>`.*

#### 1. GET `/api/documents`
Lists all documents (excluding heavy plain-text contents for lightweight queries).
- **Response** (200 OK):
  ```json
  [
    {
      "_id": "60d100000000000000000010",
      "title": "Project Specification",
      "originalFilename": "specs.txt",
      "mimeType": "text/plain",
      "size": 4350,
      "uploadedBy": { "_id": "60d000000000000000000001", "name": "Alice", "email": "alice@example.com" },
      "createdAt": "2026-07-01T12:00:00.000Z"
    }
  ]
  ```

#### 2. GET `/api/documents/:id`
Returns full document content, including page breakdowns and extracted text.
- **Response** (200 OK):
  ```json
  {
    "_id": "60d100000000000000000010",
    "title": "Project Specification",
    "originalFilename": "specs.txt",
    "mimeType": "text/plain",
    "size": 4350,
    "extractedText": "...",
    "pages": [],
    "uploadedBy": { ... }
  }
  ```

#### 3. POST `/api/documents/upload`
Uploads a new file (TXT or PDF up to 10MB). Automatically parses content page-by-page.
- **Request Body**: Multipart FormData containing:
  - `file`: (Binary PDF/TXT file)
  - `title`: (Optional String title)
- **Response** (201 Created):
  ```json
  {
    "id": "60d100000000000000000010",
    "title": "Specs",
    "originalFilename": "specs.txt",
    "mimeType": "text/plain",
    "size": 4350,
    "createdAt": "...",
    "extractedText": "...",
    "pages": []
  }
  ```

---

### Annotation Endpoints (`/api`)

*All annotation endpoints require a bearer JWT header. They broadcast real-time events to other clients inside the document room. Requests passing the header `X-Socket-ID` will exclude the sender from receiving the redundant duplicate socket broadcast (optimistic UI update).*

#### 1. POST `/api/documents/:id/annotations`
Saves a new annotation. Supports passing a custom `userId`/`userName` to select which user is drawing the highlight.
- **Request Body**:
  ```json
  {
    "userId": "60d000000000000000000002", // Optional override
    "userName": "Bob",                     // Optional override
    "pageNumber": null,                    // Number or Null
    "startOffset": 12,
    "endOffset": 45,
    "selectedText": "collaborative annotation systems",
    "comment": "Let's emphasize this goal."
  }
  ```
- **Response** (201 Created):
  ```json
  {
    "_id": "60d200000000000000000100",
    "documentId": "60d100000000000000000010",
    "userId": "60d000000000000000000002",
    "userName": "Bob",
    "startOffset": 12,
    "endOffset": 45,
    "selectedText": "collaborative annotation systems",
    "comment": "Let's emphasize this goal.",
    "createdAt": "..."
  }
  ```
- **Error Response** (409 Conflict): Returned if duplicate user-range combo is saved:
  ```json
  {
    "error": "DuplicateEntry",
    "message": "You have already created an annotation on this exact range."
  }
  ```

#### 2. GET `/api/documents/:id/annotations`
Fetches sorted annotations for a document. Supporting optional cursor pagination query parameters (`?page=1&limit=50`).
- **Response** (200 OK):
  ```json
  {
    "annotations": [
      { "_id": "...", "startOffset": 12, "endOffset": 45, "comment": "..." }
    ]
  }
  ```

#### 3. PATCH `/api/annotations/:annotationId`
Edits an annotation's comment (selected ranges are immutable).
- **Request Body**:
  ```json
  { "comment": "Updated comment text here." }
  ```
- **Response** (200 OK) containing updated annotation record.

#### 4. DELETE `/api/annotations/:annotationId`
Removes an annotation highlight and broadcasts deletion.
- **Response** (200 OK):
  ```json
  { "message": "Annotation deleted successfully." }
  ```

---

## Real-Time Collaboration Rooms (Socket.io)

Clients connect to the Socket.io namespace and join document-specific rooms to receive updates.

### Server Event Receivers
- `join-document`: `{ documentId, user }` -> Adds socket to the Room corresponding to `documentId` and registers user presence.
- `leave-document`: `{ documentId }` -> Explicitly leaves the Room and updates collaborators presence.

### Server Event Broadcasts
- `presence:update`: Array of `{ userId, userName }` -> Dispatched to the room indicating who is currently looking at the file.
- `annotation:created`: (Annotation Object) -> Broadcaster sends new highlight to active collaborators in the room.
- `annotation:updated`: (Annotation Object) -> Broadcaster shares updated comments.
- `annotation:deleted`: `{ annotationId }` -> Notifies to remove specific highlights immediately.
