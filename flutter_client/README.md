# CollabMark - Flutter Client

This is the mobile/desktop/web client for the Collaborative Document Annotation System, built using Flutter and Dart. It connects to the Node.js/Express/Socket.io backend for real-time collaboration.

---

## 🎨 Design & Features

* **Real-time Live Sync**: Implemented via `socket_io_client` connecting to the backend server.
* **Seeded Identity Login**: Select profile identity directly from the backend database to log in mock-style.
* **Document Management**: Display documents metadata, file formats, and upload new `.txt` or `.pdf` files.
* **Segment-Splitting Highlights**: Implemented the exact boundary segmentation algorithm in Dart to render layered highlight overlays in `RichText` and support tap interaction on overlaps.
* **Responsive Split Screen**: Wide desktop/web screens display a side-by-side split layout (document reader + annotation notes feed), while mobile screens adapt to a swipeable Tab view.
* **Dark Theme Aesthetics**: Consistent with the CollabMark web client, utilizing dark space violet gradients and colorful user highlight indicators.

---

## 🛠️ Architecture

* **State Management**: Built with `provider` to propagate data flow and user sessions.
* **REST Services**: Encapsulated inside `ApiService` using the `http` package, handling API authorization headers.
* **Socket Connections**: Managed by `SocketService`, binding listeners for:
  - `presence:update` (Online users count)
  - `annotation:created` (Live highlights adding)
  - `annotation:updated` (Live notes editing)
  - `annotation:deleted` (Live highlights removing)

---

## 🚀 Getting Started

### Prerequisites
* Flutter SDK (v3.10.0+) installed and configured.
* Node.js backend server running locally on port `5000` (from the root folder).

### Step 1: Install Dependencies
Navigate into this folder and run:
```bash
flutter pub get
```

### Step 2: Configure Server Endpoint
The client defaults to `http://localhost:5000` for Web and Desktop.
* **Android Emulator**: Set base URL to `http://10.0.2.2:5000` inside `ApiService.defaultBaseUrl`.
* **iOS Simulator / Physical Devices**: Use your machine's local IP address (e.g., `http://192.168.x.x:5000`).

### Step 3: Run the Client
To spin up the app on your preferred target platform, run:
```bash
# Run on Web (Chrome)
flutter run -d chrome

# Run on Desktop (macOS/Windows/Linux)
flutter run -d windows

# Run on Mobile emulator
flutter run
```
