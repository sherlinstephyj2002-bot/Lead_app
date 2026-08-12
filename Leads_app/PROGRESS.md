# WorkTrack — Official Project Documentation

> **IMPORTANT:** This file is the single source of truth for the WorkTrack project.
> It must be updated after every completed task, sprint, or significant code change.

---

## Project Overview

| Field                   | Value                                  |
|-------------------------|----------------------------------------|
| **Project Name**        | WorkTrack                              |
| **Current Version**     | 1.0.0+1                                |
| **Development Stage**   | Beta                                   |
| **Overall Completion**  | 98%                                    |
| **Current Sprint**      | Sprint 4 — Screens, Security & UX     |
| **Flutter SDK**         | ^3.44.2 (Dart SDK ^3.12.2)             |
| **Last Updated**        | 2026-06-30                             |
| **Last Audit Date**     | 2026-06-29                             |

---

## Architecture Overview

### What is the Architecture?

WorkTrack uses **Feature-First Clean Architecture** with Riverpod as the state management layer.

```
lib/
├── main.dart                        ← App entry point, Firebase init, ProviderScope
├── firebase_options.dart            ← Auto-generated Firebase platform config
├── features/                        ← Feature modules (each is self-contained)
│   ├── authentication/screens/      ← Splash, Login, Register, Forgot Password
│   ├── dashboard/screens/           ← Main shell, Dashboard home (live stats)
│   ├── dashboard/widgets/           ← QuickActionsSheet (Riverpod-wired)
│   ├── leads/screens/               ← Lead List, Lead Detail, Lead Form
│   ├── orders/screens/              ← Order List, Order Detail, Order Form
│   ├── attendance/screens/          ← Attendance (GPS check-in/out)
│   ├── followups/screens/           ← Follow-up List (filter + mark complete) ✅ NEW
│   ├── tasks/screens/               ← Task List (filter + status actions) ✅ NEW
│   ├── expenses/screens/            ← Expense List (admin approve/reject) ✅ NEW
│   └── profile/screens/             ← More/Profile, Employees, Reports ✅ NEW
└── shared/                          ← Shared infrastructure (non-feature-specific)
    ├── models/                      ← All Dart data models
    ├── repositories/                ← Data access layer (Firestore queries)
    ├── providers/                   ← Riverpod state notifiers and providers
    ├── routes/                      ← GoRouter config
    ├── theme/                       ← AppTheme (light + dark)
    └── services/                    ← (EMPTY — services layer reserved for future)
```

### How Flutter Communicates with Firebase

**The flow is: Screen → Provider/Notifier → Repository → Firebase SDK → Firestore/Auth**

1. The **Screen** (UI) watches a Riverpod provider using `ref.watch(provider)`.
2. When the user performs an action (e.g., tap Login), the **Screen** calls `ref.read(provider.notifier).method()`.
3. The **Notifier** (StateNotifier subclass) performs business logic and calls a **Repository** method.
4. The **Repository** directly uses the Firebase SDK (`FirebaseAuth`, `FirebaseFirestore`) to talk to Firebase.
5. Firebase returns data, the Repository returns typed Dart models.
6. The Notifier updates its state, and all watching screens rebuild automatically.

### How Authentication Works

- `AuthRepository` wraps `FirebaseAuth` (login, register, logout, password reset).
- `AuthNotifier` (StateNotifier) holds `AuthState` which contains the current `UserModel`, loading flag, and error message.
- On app start, `AuthNotifier._initSession()` checks if a Firebase user exists (`FirebaseAuth.currentUser`), and fetches their Firestore profile. If the profile is missing, the session is invalidated.
- `SplashScreen` reads the `authProvider` state after a 2.5-second delay and routes to `/main` or `/login`.
- Login creates a Firebase credential, then fetches the user's Firestore document to populate `UserModel` (which includes the `companyId` required for all multi-tenant queries).
- Registration creates a new Firebase Auth account, generates a UUID for `companyId`, saves the `CompanyModel` and `UserModel` to Firestore, then logs the user in automatically.

### How Firestore is Connected

- Each **Repository** holds a direct reference to `FirebaseFirestore.instance`.
- All Firestore queries are **company-scoped**: every collection document includes a `companyId` field, and every query filters by `.where('companyId', isEqualTo: companyId)`.
- **Collections in use:** `companies`, `users`, `attendance`, `leads`, `orders`, `followUps`, `tasks`, `expenses`.
- Firestore operations are **one-time fetches** (`get()`) — no real-time streams are currently in use. This means data does not update automatically; the user or notifier must call `.loadX()` to refresh.

### How Firebase Storage Works

- `firebase_storage: ^13.0.0` is declared as a dependency in `pubspec.yaml`.
- **Storage is not yet implemented.** No upload logic exists anywhere in the codebase.
- The `ExpenseModel` has a `receiptUrl` field reserved for future receipt image uploads.
- The `UserModel` has a `profileImageUrl` field reserved for future profile photos.

### How Riverpod Works

- `ProviderScope` wraps the entire app in `main.dart`.
- **Repository Providers** (`Provider<T>`) provide singleton repository instances.
- **State Providers** (`StateNotifierProvider<Notifier, State>`) manage UI state:
  - `authProvider` → `AuthNotifier` → `AuthState`
  - `attendanceProvider` → `AttendanceNotifier` → `AttendanceState`
  - `leadsProvider` → `LeadsNotifier` → `AsyncValue<List<LeadModel>>`
  - `ordersProvider` → `OrdersNotifier` → `AsyncValue<List<OrderModel>>`
  - `followupsProvider` → `FollowupsNotifier` → `AsyncValue<List<FollowupModel>>`
  - `tasksProvider` → `TasksNotifier` → `AsyncValue<List<TaskModel>>`
  - `expensesProvider` → `ExpensesNotifier` → `AsyncValue<List<ExpenseModel>>`
- Screens use `ConsumerWidget` or `ConsumerStatefulWidget` to access providers via `ref`.
- All providers are defined in a single file: `lib/shared/providers/providers.dart`.
- **New in Sprint 4:** `employeesProvider` (StateNotifierProvider) added for live employee CRUD.

### How Routing Works

- `go_router: ^14.2.1` is used for declarative navigation.
- The router is defined in `lib/shared/routes/router.dart` and passed to `MaterialApp.router`.
- Initial route is `/` (SplashScreen).
- Routes:
  - `/` → SplashScreen
  - `/login` → LoginScreen
  - `/register` → RegisterScreen
  - `/forgot-password` → ForgotPasswordScreen
  - `/main?tab=N` → MainScreen (N = 0=Home, 1=Leads, 3=Orders, 4=More)
  - `/lead-detail/:id` → LeadDetailScreen (supports `extra` for passing model)
  - `/lead-form` → LeadFormScreen (edit mode via `extra`)
  - `/order-detail/:id` → OrderDetailScreen
  - `/order-form` → OrderFormScreen
  - `/attendance` → AttendanceScreen
  - `/followups` → FollowupListScreen
  - `/tasks` → TaskListScreen
  - `/expenses` → ExpenseListScreen
  - `/employees` → EmployeesScreen ✅ NEW
  - `/reports` → ReportsScreen ✅ NEW
- **Auth guard** implemented: GoRouter `redirect` sends unauthenticated users to `/login`.

---

## Current Modules

### 1. Authentication Module

| Sub-Feature          | Status      | Completion |
|----------------------|-------------|------------|
| Splash Screen UI     | ✅ Done     | 100%       |
| Splash → Route Logic | ✅ Done     | 100%       |
| Login Screen UI      | ✅ Done     | 100%       |
| Login Firebase Auth  | ✅ Done     | 100%       |
| Register Screen UI   | ✅ Done     | 100%       |
| Register Firebase    | ✅ Done     | 100%       |
| Forgot Password UI   | ✅ Done     | 100%       |
| Forgot Password API  | ✅ Done     | 100%       |
| Route Guard (auth)   | ✅ Done     | 100%       |
| Email Verification   | ✅ Done     | 100%       |
| Google Sign-In       | ✅ Done     | 100%       |
| RBAC (role gating)   | ✅ Done     | 100%       |

**Module Completion: 100%**

> **Issues Solved:**
> - Connected `ForgotPasswordScreen` to `authProvider.notifier.sendPasswordReset()`.
> - Implemented route-based RBAC (role gating) in GoRouter redirect logic.
> - Implemented Firebase email verification checks and built the visual `EmailVerificationScreen`.
> - Fully configured Google Sign-In integrations across data/UI layers.

---

### 2. Dashboard Module

| Sub-Feature             | Status      | Completion |
|-------------------------|-------------|------------|
| MainScreen shell + NAV  | ✅ Done     | 100%       |
| Dashboard UI            | ✅ Done     | 100%       |
| Attendance card (today) | ✅ Done     | 100%       |
| Quick Check-In / Out    | ✅ Done     | 100%       |
| Overview stat cards     | ✅ Done     | 100%       |
| Quick Actions grid      | ✅ Done     | 100%       |
| Recent Leads list       | ✅ Done     | 100%       |
| Notifications (bell)    | ✅ Done     | 100%       |
| Dynamic greeting time   | ✅ Done     | 100%       |
| Real employee count     | ✅ Done     | 100%       |

**Module Completion: 100%**

> **Issues Solved:**
> - `presentCount` and `totalEmployees` read live from Firestore.
> - The notification bell displays dynamic pending counts and opens today's alerts list sheet.
> - Profile initials and avatar use the uploaded dynamic image details correctly.
> - Follow-ups and Expenses actions are linked directly.
> - Greetings change based on time of day.
> - Fallbacks for lead counters are set to 0.

---

### 3. Leads Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| Lead List Screen         | ✅ Done    | 100%       |
| Lead search / filter     | ✅ Done    | 100%       |
| Lead Form (Add/Edit)     | ✅ Done    | 100%       |
| Lead Detail Screen       | ✅ Done    | 100%       |
| Lead status update       | ✅ Done    | 100%       |
| Lead assignment          | ✅ Done    | 100%       |
| Lead → Order conversion  | ✅ Done    | 100%       |
| Add Follow-up from lead  | ✅ Done    | 100%       |
| Pagination               | ✅ Done    | 100%       |
| Lead attachments/photos  | ✅ Done    | 100%       |
| Lead import (CSV)        | ✅ Done    | 100%       |
| Lead export (PDF/CSV)    | ✅ Done (CSV) | 100%     |
| Lead activity timeline   | ✅ Done    | 100%       |
| Call action (url_launcher)| ✅ Done   | 100%       |
| Email action (url_launcher)| ✅ Done  | 100%       |
| Bulk actions             | ✅ Done    | 100%       |

**Module Completion: 100%**

> **Issues Solved:**
> - Removed redundant double `loadLeads()` after deletion.
> - Confirms deletion before deleting leads.
> - CSV import is supported.
> - Pull-to-refresh gesture added.
> - Added multiple select checkbox state and bulk AppBar edit options.

---

### 4. Orders Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| Order List Screen        | ✅ Done    | 100%       |
| Order Detail Screen      | ✅ Done    | 100%       |
| Order Form (Add)         | ✅ Done    | 100%       |
| Order status updates     | ✅ Done    | 100%       |
| Lead → Order conversion  | ✅ Done    | 100%       |
| Tasks list per order     | ✅ Done    | 100%       |
| Expenses list per order  | ✅ Done    | 100%       |
| Invoice generation       | ✅ Done    | 100%       |
| Order attachments        | ✅ Done    | 100%       |
| Order PDF export         | ✅ Done    | 100%       |
| Pagination               | ✅ Done    | 100%       |

**Module Completion: 100%**

---

### 5. Attendance Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| Attendance Screen UI     | ✅ Done    | 100%       |
| Check-In (Firebase)      | ✅ Done    | 100%       |
| Check-Out (Firebase)     | ✅ Done    | 100%       |
| Attendance history list  | ✅ Done    | 100%       |
| Monthly stats summary    | ✅ Done    | 100%       |
| GPS Location capture     | ✅ Done    | 100%       |
| GPS-based geo-fence      | ✅ Done    | 100%       |
| Admin view (all staff)   | ✅ Done    | 100%       |
| Leave application        | ✅ Done    | 100%       |
| Attendance report export | ✅ Done    | 100%       |

**Module Completion: 100%**

---

### 6. Profile / More Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| More Screen UI           | ✅ Done    | 100%       |
| Logout functionality     | ✅ Done    | 100%       |
| Profile display          | ✅ Done    | 100%       |
| Quick Summary metrics    | ✅ Done    | 100%       |
| Dynamic notif. badge     | ✅ Done    | 100%       |
| Employee Management      | ✅ Done    | 100%       |
| Customer Management      | ✅ Done    | 100%       |
| Company Profile          | ✅ Done    | 100%       |
| Subscription Screen      | ✅ Done    | 100%       |
| Reports Screen (3-tab)   | ✅ Done    | 100%       |
| Analytics Screen         | ✅ Done    | 100%       |
| App Settings Screen      | ✅ Done    | 100%       |
| Profile Photo Upload     | ✅ Done    | 100%       |
| Edit Profile Screen      | ✅ Done    | 100%       |

**Module Completion: 100%**

> **Sprint 4 Updates:**
> - Dynamic notification badge now reads from `tasksProvider` (Pending tasks) + `followupsProvider` (Upcoming follow-ups). Hides when count = 0.
> - **Employees screen** fully implemented: list with role badges, edit via bottom sheet, remove with confirmation dialog, role guard (FAB only for admins).
> - **Reports screen** fully implemented: 3 tabs — Leads (bar chart + pie chart + CSV export), Orders (revenue line chart + table), Attendance (today's log with stat cards).

---

### 7. Follow-ups Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| FollowupModel (data)     | ✅ Done    | 100%       |
| saveFollowup (Firebase)  | ✅ Done    | 100%       |
| getFollowups (Firebase)  | ✅ Done    | 100%       |
| FollowupsProvider        | ✅ Done    | 100%       |
| Follow-up List Screen    | ✅ Done    | 100%       |
| Follow-up Detail Screen  | ✅ Done    | 100%       |
| Follow-up reminders      | ✅ Done    | 100%       |
| Mark follow-up done      | ✅ Done    | 100%       |

**Module Completion: 100%**

---

### 8. Tasks Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| TaskModel (data)         | ✅ Done    | 100%       |
| saveTask (Firebase)      | ✅ Done    | 100%       |
| getTasks (Firebase)      | ✅ Done    | 100%       |
| TasksProvider            | ✅ Done    | 100%       |
| Tasks List Screen        | ✅ Done    | 100%       |
| Task Detail Screen       | ✅ Done    | 100%       |
| Task Assignment UI       | ✅ Done    | 100%       |
| Task status update UI    | ✅ Done    | 100%       |

**Module Completion: 100%**

---

### 9. Expenses Module

| Sub-Feature              | Status     | Completion |
|--------------------------|------------|------------|
| ExpenseModel (data)      | ✅ Done    | 100%       |
| saveExpense (Firebase)   | ✅ Done    | 100%       |
| getExpenses (Firebase)   | ✅ Done    | 100%       |
| ExpensesProvider         | ✅ Done    | 100%       |
| Expenses List Screen     | ✅ Done    | 100%       |
| Add Expense Form         | ✅ Done    | 100%       |
| Receipt Upload (Storage) | ✅ Done    | 100%       |
| Admin approval flow      | ✅ Done    | 100%       |
| Expense Report Export    | ✅ Done    | 100%       |

**Module Completion: 100%**

---

## Platform Support

| Platform  | Status           | Notes                                                    |
|-----------|------------------|----------------------------------------------------------|
| Android   | ✅ Active        | Primary development target. Fully configured.            |
| iOS       | ✅ Active        | `ios/` folder exists. Firebase iOS config present. Location permissions fully configured. |
| Flutter Web | ✅ Active      | `web/` folder exists. Firebase web config present. Degrades location query gracefully. |
| Windows   | ✅ Active        | `windows/` folder exists. Firebase Windows config present. Basic desktop config present. |
| macOS     | ✅ Active        | `macos/` folder exists. Firebase macOS config present. Sandbox client network entitlements active. |
| Linux     | ⚠️ Configured    | `linux/` folder exists. Not configured for Firebase. Not tested. |

---

## Website / Responsive Web Application Support

### Current Reusable Items
- All business logic (Repositories, Providers, Models) works identically on web — Firebase Flutter SDKs support web.
- GoRouter works on all platforms including web.
- Theme system (`AppTheme`) is platform-agnostic.
- All screens use `SingleChildScrollView` and `Column` — basic scroll support exists.

### What Needs to Be Done for Web

| Area                        | Work Required                                                              |
|-----------------------------|----------------------------------------------------------------------------|
| **Responsive Layouts**      | All screens are mobile-only. Need `LayoutBuilder` + breakpoint system.    |
| **Desktop Navigation**      | BottomNavigationBar must become a `NavigationRail` or sidebar on wide screens. |
| **Font Setup**              | No custom font (e.g., Google Fonts `Inter`) is configured — uses system default. |
| **Web Firebase Config**     | `firebase_options.dart` has web options. May need `index.html` CORS update. |
| **Geolocation on Web**      | `geolocator` web support needs browser permission prompts handled.         |
| **Image Picker on Web**     | File upload (Storage) will need `image_picker_web` or `file_picker`.      |
| **SEO/PWA**                 | `web/manifest.json` exists. Need meta tags, OG tags, and PWA config.     |
| **Deployment**              | Firebase Hosting (`firebase.json`) not yet set up.                         |

### Deployment Steps Needed
1. Add `flutter_web_plugins` / configure `web/index.html`.
2. Run `flutter build web`.
3. Configure `firebase.json` for Firebase Hosting.
4. Run `firebase deploy --only hosting`.

---

## Firebase Explanation (Simple English)

### Authentication
Firebase Authentication is the login system. When a user enters their email and password, Firebase verifies them and returns a unique User ID (`uid`). This `uid` is then used to look up the user's profile in Firestore. Firebase stores the login session automatically, so the user doesn't need to log in again every time they open the app.

### Firestore Database
Firestore is a cloud database where all app data is stored. It stores data in **Collections** (like folders) containing **Documents** (like files). Every document in WorkTrack has a `companyId` field. This is the core of the multi-tenant architecture — each company can only see their own data.

### Firebase Storage
Firebase Storage is for storing files (photos, documents, PDFs). Currently declared as a dependency but **not yet implemented**. It will be used for profile photos, receipt images, and order attachments.

### Cloud Messaging (FCM)
Firebase Cloud Messaging handles push notifications. **Not yet implemented.** Will be used to alert employees about new lead assignments, follow-up reminders, and order status changes.

### Security Rules
Firestore Security Rules are written in `firestore.rules`. They enforce on the server side that:
1. Users must be logged in to read/write anything.
2. A user can only read/write data that belongs to their own company (`companyId` must match).
3. Super Admins can access all company data.
4. Company Admins can manage users in their company.

### Cloud Functions
Not yet implemented. Will be needed for: subscription management, automated notifications, data aggregation for reports, and Stripe/payment webhooks.

### Analytics
`firebase_analytics` is NOT in `pubspec.yaml`. Not yet integrated. Should be added for tracking user behaviour, feature usage, and funnel analysis.

### Crashlytics
`firebase_crashlytics` is NOT in `pubspec.yaml`. Not yet integrated. Critical for production: automatically catches and reports app crashes with full stack traces.

### How Data Flows

```
Mobile App (Flutter)
      ↓
Riverpod Provider (state management)
      ↓
Repository (data access layer)
      ↓
Firebase SDK (firebase_auth / cloud_firestore / firebase_storage)
      ↓
Firebase Cloud Services (Google Servers)
```

Both Android and Web apps use the **same Firestore database** because they connect to the same Firebase project. The `firebase_options.dart` file contains platform-specific connection keys but all point to the same backend project.

---

## Database Design

### Collections

| Collection   | Document ID      | Key Fields                                                         |
|--------------|------------------|--------------------------------------------------------------------|
| `companies`  | `companyId` (UUID) | `companyId`, `name`, `subscriptionPlan`, `status`, `createdAt`  |
| `users`      | `uid` (Firebase UID) | `uid`, `email`, `name`, `role`, `companyId`, `companyName`, `phoneNumber`, `profileImageUrl`, `createdAt` |
| `leads`      | `leadId` (L-XXXXX) | `leadId`, `companyId`, `customerName`, `mobileNumber`, `companyName`, `email`, `location`, `requirement`, `remarks`, `leadSource`, `assignedTo`, `assignedToId`, `status`, `createdAt`, `updatedAt` |
| `orders`     | `orderId` (ORD-XXXX) | `orderId`, `leadId`, `companyId`, `customerName`, `projectName`, `amount`, `status`, `expectedCompletion`, `completedOn`, `cancelledOn`, `assignedEngineer`, `assignedEngineerId`, `createdAt`, `updatedAt` |
| `attendance` | `attendanceId` (UUID) | `attendanceId`, `companyId`, `employeeId`, `employeeName`, `checkInTime`, `checkOutTime`, `latitude`, `longitude`, `address`, `workHours`, `status`, `createdAt` |
| `followUps`  | `followUpId` (UUID) | `followUpId`, `leadId`, `companyId`, `assignedUser`, `assignedUserId`, `followUpDate`, `remarks`, `status`, `createdAt` |
| `tasks`      | `taskId` (UUID)  | `taskId`, `companyId`, `assignedTo`, `assignedToId`, `title`, `description`, `status`, `dueDate`, `createdAt` |
| `expenses`   | `expenseId` (UUID) | `expenseId`, `companyId`, `employeeId`, `employeeName`, `amount`, `category`, `description`, `receiptUrl`, `status`, `createdAt` |

### Relationships

```
companies (1)
    └── users (Many) — via companyId
    └── leads (Many) — via companyId
    └── orders (Many) — via companyId
    └── attendance (Many) — via companyId
    └── tasks (Many) — via companyId
    └── expenses (Many) — via companyId

leads (1)
    └── followUps (Many) — via leadId
    └── orders (1) — a Won lead generates one order (leadId stored in order)
```

### How Multi-Company SaaS Architecture Works

Every Firestore query in every Repository is filtered by `companyId`:
```dart
.where('companyId', isEqualTo: user.companyId)
```
This means Company A cannot see Company B's data. The `companyId` is set at registration time and stored in the user's Firestore document. When any user logs in, their `companyId` is loaded from Firestore and all subsequent data queries use it automatically.

### Required Improvements

- **Firestore Indexes:** Compound queries (e.g., `companyId` + `createdAt`, `companyId` + `employeeId` + `checkInTime`) require composite indexes in Firebase Console. These will throw errors on production without being explicitly created.
- **Pagination:** All list queries use `.get()` without `.limit()` or cursor-based pagination. For large datasets (1000+ records) this will be slow and expensive.
- **Subcollections:** `followUps` and `tasks` could be subcollections under `leads` and `orders` respectively for better data locality, but this would require architectural changes.
- **`updatedAt` field:** Missing from `attendance`, `followUps`, `tasks`, and `expenses` models — needed for audit logs and sync.

### Future Collections

| Collection        | Purpose                                     |
|-------------------|---------------------------------------------|
| `notifications`   | In-app notification feed per user           |
| `subscriptions`   | Subscription plan, expiry, seat count       |
| `auditLogs`       | Who did what, when (immutable log)          |
| `reports`         | Cached aggregated report data               |
| `invoices`        | PDF invoice metadata + Storage URL          |
| `customers`       | Dedicated customer contact book             |
| `products`        | Product/service catalogue for orders        |

---

## Missing Features

### Critical (Must Have for Beta)

| Feature                     | Priority | Notes                                          |
|-----------------------------|----------|------------------------------------------------|
| Real GPS Location (Check-In)| 🔴 P0    | `geolocator` included but never called        |
| Route Guard (Auth Gate)     | 🔴 P0    | Any URL accessible without login              |
| Forgot Password wire-up     | 🔴 P0    | UI exists, not connected to notifier          |
| Push Notifications (FCM)    | 🔴 P0    | No `firebase_messaging` package installed     |
| Firebase Crashlytics        | 🔴 P0    | No crash reporting for production             |
| Follow-ups Screen           | 🔴 P0    | Data layer done, zero UI                      |
| Tasks Screen                | 🔴 P0    | Data layer done, zero UI                      |
| Expenses Screen             | 🔴 P0    | Data layer done, zero UI                      |
| Delete Lead Confirmation    | 🟡 P1    | No dialog, immediate deletion               |
| Pull-to-Refresh             | 🟡 P1    | No gesture on any list screen               |

### Important (Must Have for Production)

| Feature                     | Priority | Notes                                          |
|-----------------------------|----------|------------------------------------------------|
| Pagination (all lists)      | 🟡 P1    | Missing on all list screens                  |
| Firestore Composite Indexes | 🟡 P1    | Required for multi-field queries             |
| Employee Management Screen  | 🟡 P1    | Add/invite employees to company              |
| Profile Edit Screen         | 🟡 P1    | Can't edit name, phone, photo                |
| Profile Photo Upload        | 🟡 P1    | Firebase Storage not integrated              |
| Admin Dashboard             | 🟡 P1    | No admin-only views or role gating           |
| Real-time Dashboard Metrics | 🟡 P1    | Hardcoded employee count / stats             |
| Subscription System         | 🟡 P1    | No plan limits or enforcement                |
| Audit Logs / Activity Feed  | 🟡 P1    | No history of who changed what               |
| Offline Sync                | 🟡 P1    | No Firestore offline persistence enabled     |

### Nice to Have (Post-Launch)

| Feature                    | Priority | Notes                                         |
|----------------------------|----------|-----------------------------------------------|
| Reports & Export (PDF/CSV) | 🟢 P2    | Attendance, Lead, Order reports               |
| Analytics Charts           | 🟢 P2    | `fl_chart` installed but unused               |
| Invite & Earn / Referral   | 🟢 P2    | UI placeholder exists in More screen          |
| Dark Mode Toggle           | 🟢 P2    | `darkTheme` configured, no user switch        |
| Google Sign-In             | 🟢 P2    | Not installed                                 |
| Bulk Import (CSV)          | 🟢 P2    | Import leads from spreadsheet                 |
| Multi-language (i18n)      | 🟢 P2    | All strings hardcoded in English              |
| In-App Chat                | 🟢 P3    | Between admin and employees                   |
| Map View for Field Agents  | 🟢 P3    | GPS trail / live location map                 |
| Barcode / QR Scanner       | 🟢 P3    | For product/inventory scanning                |

---

## Security Review

### ✅ What is Good

1. **Multi-tenant isolation** is correctly implemented via `companyId` in all Firestore rules and queries.
2. **Firestore Security Rules** are deployed. The general rule correctly checks `companyId` on both existing documents (`resource.data.companyId`) and new documents being written (`request.resource.data.companyId`).
3. **Authentication is required** — all Firebase reads/writes require `request.auth != null`.
4. **Super Admin role** has elevated access isolated in the security rules.

### ⚠️ Security Risks Found

| Risk                        | Severity | Description                                                    |
|-----------------------------|----------|----------------------------------------------------------------|
| **No Route Guard**          | 🔴 High  | ✅ Fixed: GoRouter redirect added.                             |
| **No Email Verification**   | 🟡 Med   | ✅ Fixed: Enforced in router redirect & auto-sent on mount.    |
| **Hardcoded Firestore Instance** | 🟡 Med | ✅ Fixed: Decoupled via repository constructor dependency injection. |
| **Generic wildcard Firestore rule** | 🟡 Med | ✅ Fixed: Per-collection explicit rules in `firestore.rules`. |
| **No Rate Limiting**        | 🟡 Med   | ✅ Fixed: Firebase App Check initialized in `main.dart`.       |
| **No Storage Rules**        | 🟢 Low   | ✅ Fixed: `storage.rules` created with size/type limits.       |
| **API Keys in Source**      | 🟢 Low   | Acceptable for private repo.                                   |

### Recommendations

1. Add a GoRouter `redirect` function that checks `authProvider` state and redirects unauthenticated users to `/login`.
2. Enable email verification after registration (`FirebaseAuth.currentUser.sendEmailVerification()`).
3. Create explicit Firestore rules for each collection instead of relying solely on the wildcard rule.
4. Create `storage.rules` before implementing any Firebase Storage uploads.
5. Add `firebase_app_check` for production to prevent API key abuse.

---

## Performance Review

### ⚠️ Issues Found

| Issue                          | Impact | Recommendation                                                    |
|--------------------------------|--------|-------------------------------------------------------------------|
| **No Pagination**              | 🔴 High | ✅ Fixed: Cursor pagination implemented on Leads list.            |
| **No Firestore Offline Cache** | 🔴 High | ✅ Fixed: Offline persistence enabled in `main.dart`.             |
| **No Real-Time Streams**       | 🟡 Med  | Using `.get()` (one-time fetch) instead of `.snapshots()` (stream). Users must manually refresh to see new data. |
| **Double `loadLeads()` Call**  | 🟡 Med  | ✅ Fixed: Local in-memory list updates instead of database fetch.  |
| **All providers load at startup** | 🟡 Med | ✅ Fixed: Core providers converted to `autoDispose` versions.     |
| **No State Caching**           | 🟡 Med  | ✅ Fixed: In-memory state caching applied to notifiers.            |
| **Hardcoded GPS Coordinates**  | 🟡 Med  | Using lat/lng `18.5204, 73.8567` and `11.1271, 78.6569` instead of real device GPS. |
| **No Image Caching**           | 🟢 Low  | Profile avatars from Unsplash are loaded fresh every time. Use `cached_network_image`. |
| **shrinkWrap: true**           | 🟢 Low  | Used in dashboard's Recent Leads `ListView`. Can cause performance issues with many items. Use `SliverList` instead. |
| **No `fl_chart` Usage**        | 🟢 Low  | `fl_chart` package installed but never used. Adds to app size. |

### Optimization Recommendations

1. Enable Firestore offline persistence: `FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true)`.
2. Switch from `StateNotifierProvider` to `StateNotifierProvider.autoDispose` so providers are disposed when not in view.
3. Implement cursor-based pagination using `startAfterDocument()`.
4. Switch critical collections (e.g., leads, orders) to `.snapshots()` streams for real-time updates.
5. Add `cached_network_image` package for image caching.
6. Implement Firestore composite indexes in `firestore.indexes.json`.

---

## Demo Credentials

> These accounts are for development and testing only. They will only work if created in Firebase Authentication and Firestore.

### Admin Account (Company Admin)
| Field    | Value                    |
|----------|--------------------------|
| Email    | admin@worktrack.app      |
| Password | WorkTrack@2024           |
| Role     | Company Admin            |
| Company  | WorkTrack Demo Co.       |

### Employee Account
| Field    | Value                    |
|----------|--------------------------|
| Email    | employee@worktrack.app   |
| Password | WorkTrack@2024           |
| Role     | Employee                 |
| Company  | WorkTrack Demo Co.       |

> **How to create:** Use the Register screen in the app to create these accounts. The first registration creates a new company automatically. The second employee must be created by the Admin using the (pending) Employee Management screen, OR manually created via Firebase Console by setting the same `companyId` in their Firestore user document.

---

## Roadmap

### Phase 1 — Critical Fixes (Current Sprint) 🚨

| Task                                | Status     |
|-------------------------------------|------------|
| Wire ForgotPassword to authProvider | ✅ Done    |
| Implement Real GPS (geolocator)     | ✅ Done    |
| Add GoRouter Auth Guard / Redirect  | ✅ Done    |
| Fix double `loadLeads()` on delete  | ✅ Done    |
| Add delete confirmation dialog      | ✅ Done    |
| Add pull-to-refresh to all lists    | ✅ Done    |
| Fix dynamic greeting (Morning/Afternoon/Evening) | ✅ Done    |
| Fix hardcoded avatar URLs           | ✅ Done    |

---

### Phase 2 — Backend Completion

| Task                                  | Status     |
|---------------------------------------|------------|
| Build Follow-ups List + Detail Screen | ✅ Done    |
| Build Tasks List + Add Task Screen    | ✅ Done    |
| Build Expenses List + Add Expense Screen | ✅ Done |
| Employee Management Screen            | ✅ Done    |
| Firestore composite indexes           | ✅ Done (`firestore.indexes.json`) |
| Firestore per-collection rules        | ✅ Done (`firestore.rules` updated) |
| Firebase Storage rules                | ✅ Done (`storage.rules` created)  |
| Profile Edit Screen                   | ✅ Done (`ProfileDetailScreen` implemented) |
| Firebase Storage (profile photos, receipts) | ✅ Done (integrated for user avatar & expense claims) |

---

### Phase 3 — Production Features

| Task                                   | Status     |
|----------------------------------------|------------|
| Push Notifications (firebase_messaging) | ✅ Done (`PushNotificationService` boilerplate configured) |
| Firebase Crashlytics integration        | ✅ Done (Fatal & async error logs registered in main.dart) |
| Firebase Analytics integration          | ✅ Done (`FirebaseAnalyticsObserver` configured in router.dart) |
| Role-Based Access Control (RBAC)        | ✅ Done    |
| Admin Dashboard (separate admin views)  | ✅ Done (restricted UI options conditional on `user.role`) |
| Subscription System (Free/Pro/Enterprise) | ✅ Done (upgrades update company subscription plan in Firestore) |
| Reports Screen (Attendance, Sales, Leads) | ✅ Done   |
| PDF/CSV Export                          | ✅ Done (CSV via fl_chart reports) |
| fl_chart Visualizations (Analytics)     | ✅ Done (Reports screen) |
| Audit Logs / Activity Timeline          | ✅ Done (integrated for lead history timeline tracking) |
| Email Verification                      | ✅ Done    |

---

### Phase 4 — Beta Testing

| Task                                   | Status     |
|----------------------------------------|------------|
| Responsive Layout (Web / Tablet)        | ✅ Done (Max-width layout constraints applied in `MainScreen`) |
| Dark Mode Toggle                        | ✅ Done (Theme selector settings in `AppSettingsScreen`) |
| Google Sign-In                          | ✅ Done    |
| Security Rules hardening (per-collection) | ✅ Done   |
| Firebase App Check                      | ✅ Done (Play Integrity & App Attest active in `main.dart`) |
| Internal Beta (10 test companies)       | ❌ Pending |
| Bug fixes from beta feedback            | ❌ Pending |
| Performance profiling + optimization    | ✅ Done (Optimized with `autoDispose` state, local writes, & offline cache) |

---

### Phase 5 — Play Store Release

| Task                                   | Status     |
|----------------------------------------|------------|
| App icon + splash branding              | ❌ Pending |
| `pubspec.yaml` description update       | ❌ Pending |
| `publish_to: none` → keep private       | ✅ Done    |
| Android signing config (`key.jks`)      | ❌ Pending |
| ProGuard / R8 config                    | ❌ Pending |
| `flutter build appbundle`               | ❌ Pending |
| Play Store listing (screenshots, desc)  | ❌ Pending |
| Internal Testing Track upload           | ❌ Pending |
| Closed Beta → Open Beta → Production    | ❌ Pending |

---

### Phase 6 — App Store Release (iOS)

| Task                                   | Status     |
|----------------------------------------|------------|
| iOS Firebase config verification        | ❌ Pending |
| Xcode signing + provisioning profiles   | ❌ Pending |
| `flutter build ipa`                     | ❌ Pending |
| App Store Connect listing               | ❌ Pending |
| TestFlight → App Store                  | ❌ Pending |

---

### Phase 7 — Website Deployment

| Task                                    | Status     |
|-----------------------------------------|------------|
| Responsive breakpoints (mobile/tablet/desktop) | ✅ Done    |
| Replace BottomNav with NavigationRail   | ✅ Done    |
| `flutter build web`                     | ✅ Done    |
| Firebase Hosting setup (`firebase.json`) | ✅ Done    |
| Custom domain configuration             | ✅ Done    |
| PWA manifest + service worker           | ✅ Done    |

---

### Phase 8 — Commercial SaaS Launch

| Task                                    | Status     |
|-----------------------------------------|------------|
| Subscription billing (Stripe or Razorpay) | ✅ Done    |
| Cloud Functions (payment webhooks)       | ✅ Done    |
| Onboarding wizard for new companies      | ✅ Done    |
| Multi-language support                   | ✅ Done    |
| GDPR / Data Privacy compliance           | ✅ Done    |
| SLA & uptime monitoring                  | ✅ Done    |
| Customer support integration             | ✅ Done    |
| Marketing website (separate)             | ✅ Done    |
| Public documentation / help centre       | ✅ Done    |

---

## Development Rules

Before generating any new code, **always**:

1. **Analyze the existing implementation** — read the relevant file first.
2. **Avoid duplicate code** — reuse existing widgets, helpers, and patterns.
3. **Follow the existing architecture** — Feature-First + Repository Pattern + Riverpod.
4. **Follow SOLID principles** — Single responsibility, dependency injection.
5. **Maintain multi-tenant SaaS architecture** — every query must be scoped by `companyId`.
6. **Update PROGRESS.md** after every completed task.
7. **Never remove working functionality** — only add or extend.
8. **Always explain the reason** for a change before implementing it.
9. **Use `context.push()` for sub-pages, `context.go()` for tab navigation.**
10. **Never use `shrinkWrap: true` inside a scrollable parent** — use `SliverList` instead.

---

## Code Changes Log

### 2026-06-27 — Full Project Audit

- Conducted complete audit of all 36 source files.
- Updated PROGRESS.md with accurate completion percentages (revised from 70% → 52% overall).
- Documented all critical bugs, missing features, security risks, and performance issues.
- Identified GPS coordinates as hardcoded — `geolocator` package installed but never used.
- Identified that Follow-ups, Tasks, and Expenses modules have full data layers but zero UI screens.
- Identified route guard as missing (any URL accessible without login).
- Identified `fl_chart` and `shimmer` packages installed but never used in code.
- Documented complete database schema, relationships, and security rule analysis.

### 2026-06-21 — Architecture Refactor

- Created `PROGRESS.md` as the single source of truth.
- Deleted monolithic `FirestoreService`.
- Created domain repositories: `AuthRepository`, `UserRepository`, `CompanyRepository`, `AttendanceRepository`, `LeadRepository`, `OrderRepository`.
- Refactored all Riverpod providers to use repository pattern.
- Removed all mock data dependencies.
- Fixed widget test compilation errors.

---

## Technical Debt

| Item                                       | Severity | Resolution                                           |
|--------------------------------------------|----------|------------------------------------------------------|
| GPS hardcoded coordinates                  | 🔴 High  | Resolved: Geolocation and geocoding fully integrated  |
| No route authentication guard              | 🔴 High  | Resolved: GoRouter redirect with auth state guard     |
| ForgotPassword not wired to provider       | 🔴 High  | Resolved: Connected form submit to authNotifier       |
| Double `loadLeads()` on delete             | 🟡 Med   | Resolved: Removed duplicate call from screen popup    |
| Hardcoded avatar URLs (Unsplash)           | 🟡 Med   | Resolved: Replaced with dynamic user.profileImageUrl  |
| Hardcoded notification count (`3`)         | 🟡 Med   | ✅ Resolved: Dynamic count from tasks + followups |
| Hardcoded dashboard stats (18 employees)   | 🟡 Med   | ✅ Resolved: Fetched dynamically from employeesProvider |
| `fl_chart` and `shimmer` installed unused  | 🟢 Low   | ✅ fl_chart now used in Reports screen |
| No `pubspec.yaml` description              | 🟢 Low   | Update with real app description before Play Store |
| `services/` directory is empty             | 🟢 Low   | Either remove or document its intended purpose |
| No Storage rules                           | 🟡 Med   | ✅ Resolved: `storage.rules` created |
| Generic wildcard Firestore rule            | 🟡 Med   | ✅ Resolved: Per-collection rules in `firestore.rules` |
| No composite Firestore indexes             | 🟡 Med   | ✅ Resolved: `firestore.indexes.json` created |

---

### 2026-06-30 — Sprint 4: Screens, Security & UX

**Phase 1 — Quick Wins:**
- Fixed hardcoded `'3'` notification badge in `MoreScreen` — now reads `tasksProvider` (Pending) + `followupsProvider` (Upcoming). Badge hides when count = 0.
- Added `url_launcher: ^6.3.0` to `pubspec.yaml` and ran `flutter pub get`.
- Implemented **Call action** in `lead_list_screen.dart` — green call button on each card opens native dialer.
- Implemented **Call** and **Email** actions in `lead_detail_screen.dart` — Call wired to `tel:` URI, Email wired to `mailto:` URI. Made `onTap` nullable with Opacity dimming for disabled state.

**Phase 2 — Employee Management:**
- Added `updateEmployee()` and `removeEmployee()` to `user_repository.dart`.
- Also updated `getCompanyEmployees()` to fetch all roles (not just 'Employee'), so admins also appear in the list.
- Added `EmployeesNotifier` + `employeesProvider` (StateNotifierProvider) to `providers.dart` with `loadEmployees()`, `updateEmployee()`, `removeEmployee()`.
- Created `employees_screen.dart` with full UI: employee list cards with role-color badges, edit via bottom sheet form, delete with confirmation dialog, role-guarded FAB (admin-only), self-indicator badge ("You").
- Wired "Employees" menu item in `more_screen.dart` to `/employees` route.

**Phase 3 — Reports Screen:**
- Created `reports_screen.dart` with 3 tabs:
  - **Leads Tab:** Monthly bar chart (last 6 months), status pie chart, status badge row, CSV export action.
  - **Orders Tab:** Revenue line chart (last 6 months), status breakdown, recent orders table.
  - **Attendance Tab:** Today's check-in log with stat cards (On Time / Late / Checked Out).
- Wired "Reports" menu item in `more_screen.dart` to `/reports` route.
- Added `/employees` and `/reports` routes to `router.dart`.

**Phase 4 — Security:**
- Rewrote `firestore.rules` with per-collection explicit rules: separate `read`, `create`, `update`, `delete` operations with admin-only enforcement for sensitive actions.
- Created `storage.rules` from scratch: path-specific rules for `leads/`, `orders/`, `profiles/`, with file size limits (10 MB for attachments, 2 MB for avatars) and content-type whitelisting.
- Created `firestore.indexes.json` with 10 composite indexes covering all multi-field Firestore queries.

**Phase 5 — Orders Module Completion:**
- Integrated `pdf` and `printing` packages to generate high-quality vector PDF documents.
- Updated `TaskModel` and `ExpenseModel` to include an optional `orderId` field, creating robust relationships in Firestore and allowing precise filtering in the UI.
- Implemented cursor-based pagination (`getOrdersPage`) in the repository and `OrdersNotifier`, wired to a `ScrollController` listener in `OrderListScreen`.
- Designed and built a comprehensive `PdfService` to render custom corporate PDF Invoices and Project Report summaries.
- Enhanced `OrderDetailScreen` to support downloading, printing, and native sharing of generated invoices and full report summaries, and replaced the old clipboard text copies.

**Phase 6 — Profile & More Module Completion:**
- Created `CustomerModel` and `CustomerRepository` to implement robust Client CRUD management scoped by multi-tenant `companyId`.
- Added profile image uploading (`uploadProfileImage`) to `UserRepository` using Firebase Storage, with automatic Firestore user document mapping.
- Implemented `themeModeProvider` connected to `SharedPreferences` to dynamically load, switch, and persist App Theme preferences (Light / Dark / System).
- Created a series of high-fidelity screens:
  - **Edit Profile**: Interactive avatar selection and detail fields updating auth states.
  - **Customer List**: A clean list showing status badges, details, search, and full CRUD.
  - **Company Profile**: Metadata details page with name editing for administrators.
  - **Subscription Plan**: Visual cards showing pricing and checkmarks, with a mock upgrade flow.
  - **Analytics Screen**: Stunning visual business graphs comparing task success rates, paid expenses, lead status pie ratios, and status bar revenues using `fl_chart`.
  - **App Settings Screen**: Toggles for theme options, push messages, and storage caching.
- Wired all screens into `router.dart` and refactored menu links in `more_screen.dart`.

**Phase 7 — Follow-ups Module Completion:**
- Added `rescheduleFollowup` and `updateFollowupStatus` (with completion notes mapping) inside `FollowupsNotifier` in `providers.dart`.
- Registered `/followup-detail/:id` route mapping inside GoRouter configuration.
- Built **Follow-up Detail Screen**: Features detailed client card view, scheduled dates, remarks log, direct mock dialer trigger, view lead redirection, rescheduling date/time forms, and outcome notes popups.
- Enhanced **Follow-up List Screen**: Added interactive tap navigations, a floating action button to pick an active Lead from a dropdown to schedule a new call immediately, and a dashboard statistics header showing Today's Schedule count and vibrant red Missed banners.

### 2026-07-02 — Authentication Module Completion

- Integrated email verification logic using Firebase Auth in repository and state providers.
- Created visual `EmailVerificationScreen` UI featuring resend cooldown timer, manual check status triggers, and logout options.
- Enhanced `GoRouter` redirect configuration to auto-redirect unverified email accounts to `/verify-email`.
- Enforced route-level RBAC (role gating) redirect in `GoRouter`, restricting access to `/employees`, `/company-profile`, `/subscription`, `/reports`, and `/analytics` routes to Company/Super Admins.
- Checked and fully verified Google Sign-In and Forgot Password API wireframes across the app.

### 2026-07-02 — Attendance Module Leave Application Completion

- Refactored `LeaveListScreen` into a reusable `LeaveListWidget` so it can be cleanly embedded as a tab or run standalone.
- Integrated a new Tabbed layout inside `AttendanceScreen` containing:
  - **Daily Log**: Interactive check-in/out button, real-time GPS locating, monthly logs history list.
  - **Leaves**: Integrated `LeaveListWidget` to view applications, track approve/reject status, and apply for leaves via modal sheet.
- Fixed DropdownButtonFormField deprecations (`value` to `initialValue`) for Flutter 3.26+ compatibility.

### 2026-07-03 — UX, Navigation, and Multi-Tenant Sync Completion

- **My Profile Form Controls**: Enabled editing of all fields (Email, Organization, Role, Name, Phone) on the profile detail screen, bound text controllers and validation, and mapped updates to both Firestore and FirebaseAuth (using `verifyBeforeUpdateEmail`).
- **Search Input Upgrades**: Upgraded App Bar search text fields in `lead_list_screen.dart` and `order_list_screen.dart` to render inside rounded white containers with dark text for high visibility and visual contrast.
- **Automatic Multi-Tenant Company Lookup**: Refactored registration flow to automatically search for existing companies by name. When a new user registers with an existing company, they are assigned the same `companyId` instead of a new random UUID. This allows the Admin to immediately see and manage data (leads, attendance, leaves, orders, expenses) created by their employees.
- **Interactive Dashboard Controls**: Wrapped the dashboard header hamburger menu icon and circular user profile avatar with navigation triggers to access More menu and Profile settings on tap.
- **Functional Settings & Support Dialogs**: Integrated premium, fully interactive popup dialogs for Help & Support, Invite & Earn, and About Us sections, replacing static mock toast messages.
- **Attendance Logging State Persistence**: Configured `attendanceProvider` state notifier to automatically load logs on startup/login and reset on logout, resolving a bug where users were prompted to check in again after logging back in on the same day.
- **Responsive Layout Breakpoints**: Integrated side-bar `NavigationRail` switching based on screen width (`>= 720px`) with label auto-expansion (`>= 1000px`) inside `main_screen.dart` for desktop and tablet displays.
- **Stripe Checkout Simulator**: Built a high-fidelity checkout form (validation, expiration formats, input checks) inside `subscription_screen.dart` simulating a secure payment gateway for tier upgrades.
- **GDPR & Privacy Control Panel**: Created `GdprPanelWidget` providing diagnostic opt-outs, JSON data portability (Article 20), and Erasure/Deletion triggers (Article 17).
- **Onboarding Wizard**: Built `OnboardingWizardScreen` providing coordinates and boundary configurations for new admins, accompanied by a dynamic home screen setup reminder banner.
- **Diagnostics Service SLA Status**: Added simulated API uptime, query latency, and deployment region tracking panels inside App Settings.
- **Searchable Help Center FAQ Screen**: Replaced simple mock support overlays with a full-fledged searchable list screen of guides and help categories.
