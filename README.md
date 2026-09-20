# Super TG Attendance Dashboard

Flutter Web foundation for the Super TG Attendance Dashboard.

## Included

- Responsive desktop/tablet dashboard shell
- Sidebar navigation
- Top AppBar
- Dashboard overview cards
- TG Management placeholder
- Student Management placeholder
- Attendance placeholder
- Reports placeholder
- Excel Import placeholder
- Centralized theme
- Reusable UI components
- Navigation controller separated from UI
- Firebase Core + Cloud Firestore dependencies
- Firestore service layer prepared for later integration
- No authentication
- No real attendance logic

## Run

```bash
flutter pub get
flutter run -d chrome
```

## Firebase setup later

Install FlutterFire CLI and configure the project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This will generate `lib/firebase_options.dart`.

Then initialize Firebase in `main.dart`:

```dart
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

Do this in a later phase when the Firebase project is ready.

## Suggested next phases

1. Firebase project + Firestore collections
2. TG Management CRUD
3. Student Management CRUD
4. Attendance data model and attendance screens
5. Dashboard live statistics
6. Excel import
7. Reports/export
8. Authentication/roles when required

## Phase 2 — Firebase + Firestore architecture

### Firebase setup (manual)

No Firebase project ID or credentials are stored in this repository. From the project root:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

When prompted, select the existing Firebase project and enable the Web platform. The command generates `lib/firebase_options.dart` with your real project configuration.

Then wire initialization in `main.dart` using the generated `DefaultFirebaseOptions.currentPlatform`:

```dart
await FirebaseInitializer.initialize(
  DefaultFirebaseOptions.currentPlatform,
);
```

The repository intentionally leaves this final project-specific step manual so no credentials are invented or committed.

### Firestore structure

```text
/tgs/{tgId}
  tgId: string
  name: string
  pin: string?                // optional lightweight identifier only
  active: boolean
  createdAt: timestamp
  updatedAt: timestamp

/students/{studentId}
  studentId: string
  name: string
  rollNumber: string
  assignedTgId: string?
  active: boolean
  createdAt: timestamp
  updatedAt: timestamp

/attendance/{YYYY-MM-DD_studentId}
  studentId: string
  tgId: string
  date: timestamp              // normalized to calendar day
  status: "present" | "absent"
  markedAt: timestamp
  markedBy: string?
  updatedAt: timestamp
```

Attendance uses a deterministic document ID made from the calendar date and student ID. The application therefore targets the same document for a student's attendance on a given date instead of creating a new random document each time.

### Security

`firestore.rules` is intentionally deny-by-default because Authentication is not part of Phase 2. Public read/write rules would make the database unsafe in production. Before enabling real client-side writes, add Firebase Authentication (or another trusted server-side authorization mechanism) and replace the development rules with role-based rules.
