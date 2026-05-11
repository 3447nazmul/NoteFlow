# NoteFlow Developer Guide

Welcome to NoteFlow! This guide is designed to help future developers and AI agents understand the architecture of the app and how to safely navigate and modify the codebase.

## 🗺️ Codebase Map

### 1. UI & Screens (`lib/features/`)
The UI is modularized by feature. Key areas include:
*   **Authentication** (`lib/features/auth/`): Contains the `LoginScreen` and `AppLockScreen`. Uses `AuthController` for state.
*   **Notes Interface** (`lib/features/notes/`): Contains the `NoteEditorScreen`, `NoteDetailScreen`, and `NotesListScreen`. Reusable UI components like the `NoteCard`, `ChecklistWidget`, and `AiActionBar` are found in `widgets/`.
*   **Settings** (`lib/features/settings/`): Contains the `SettingsScreen` (managing API keys, app lock) and `AboutScreen`.

### 2. Controllers & State (`lib/features/.../controllers/`)
We use `Provider` for state management.
*   `NotesController` (`lib/features/notes/controllers/notes_controller.dart`): The central orchestrator for Note and Folder CRUD operations, filtering, and interactions with background sync and AI services.
*   `AuthController` (`lib/features/auth/controllers/auth_controller.dart`): Manages the Google Sign-In flow and reactive authentication state.

### 3. AI Logic & Services (`lib/services/` or `lib/features/services/`)
The app integrates intelligent features via multi-provider AI services (Gemini & Qwen).
*   `AiService`: The unified router handling tasks like "Summarise", "Auto-tag", "Ask AI", and "Calculate".
*   `ApiKeyService`: Securely stores and manages the user's AI API keys in secure storage.
*   Other core services include `SyncService` for cloud backup, `HiveService` for local storage, and `ExportService` for PDF generation.

### 4. Themes & Design System (`lib/shared/`)
*   **Design Tokens**: We use the *Lumina Focus* design system. Centralized themes, colors, and constants are managed here.
*   **Constants**: Look in `lib/shared/constants/` for `app_strings.dart` and theme data.

---

## 🤖 Instructions for Future AI Agents

If you are an AI assistant tasked with updating or modifying NoteFlow, please adhere to the following rules:

1.  **Read the `// AI NOTE:` Comments**: Almost all major classes (Controllers, Screens, Services) have a leading `// AI NOTE:` comment that briefly explains its purpose and context. Read these before making modifications to understand how the component fits into the broader architecture.
2.  **Preserve the Single Source of Truth**: When modifying note data or authentication flows, always go through `NotesController` or `AuthController`. Do not bypass controllers to write directly to services like `HiveService` unless you are actively redesigning the service layer.
3.  **Respect the UI Architecture**: The application is built using a feature-based folder structure. If you add a new screen related to notes, place it in `lib/features/notes/screens/`. Reusable components belong in `widgets/`.
4.  **No Silent Logic Changes**: If you are tasked with adding comments or documentation, do not alter working logic, state flows, or the `Lumina Focus` design tokens unless explicitly instructed by the user.
5.  **Multi-Provider AI**: Remember that the user can choose between Google Gemini and Alibaba Qwen. Any new AI feature must be implemented in a provider-agnostic way inside `AiService`.
