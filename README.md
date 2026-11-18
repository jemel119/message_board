# Message Board Vault Hunt

Graduate submission: Jeremy Henry-Atohengbe

Firebase project: message-board-da8a3  
Local emulator project: demo-message-board  
Repository: https://github.com/jemel119/message_board

## What the app does

The Flutter app provides a startup splash, Firebase Email/Password
authentication, a private user profile, and a shared message board.

Signed-in users can read the board and create messages. Authors can
edit and delete their own messages. Firestore snapshots supply live
updates. Security rules enforce access independently of the interface.

AuthService owns authentication operations. BoardService owns Firestore
operations. Widgets display state and call service methods.

## Requirements

- Flutter SDK and Android build tools
- Firebase CLI and FlutterFire CLI
- Node.js and npm for the rules tests
- JDK 21 for the Firebase Emulator Suite
- A configured Firebase project with Email/Password authentication
  and Cloud Firestore
- An Android device for the final release tests

## Firebase setup

From the project root:

    flutter pub get
    firebase login
    flutterfire configure --project=message-board-da8a3

Select the Android application belonging to this project.

Enable Email/Password in Firebase Authentication. Create the Firestore
database and publish the contents of firestore.rules to the same project.

The main Android manifest declares the INTERNET permission.

Do not publish test passwords, authentication tokens, service-account
files, or signing credentials.

## Run against the cloud project

    flutter run

Normal startup uses the generated firebase_options.dart configuration.

The local emulator option is restricted to debug mode. The release
build uses the configured cloud project.

## Run against local Firebase emulators

From the project root, start:

    firebase emulators:start --config firebase.emulators.json --only auth,firestore --project demo-message-board

The current emulator configuration listens on this computer's loopback
interface.

Emulator UI:

    http://127.0.0.1:4000

For a Flutter target running on the same computer, start with:

    flutter run --dart-define=USE_FIREBASE_EMULATORS=true --dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1

The selected Flutter platform must have its Firebase dependencies
configured. This command does not configure an additional platform.

The app displays a LOCAL TEST banner when emulator mode is enabled.
A physical phone cannot reach the computer through 127.0.0.1. Physical
phone emulator testing needs a reachable computer address and suitable
network configuration.

The demo project ID keeps emulator testing separate from the cloud
project. The app-based emulator workflow and evidence that production
data remained unchanged are still pending.

## Data model and field writers

### Private profile: users/{uid}

| Field | Writer | Purpose |
|---|---|---|
| uid | BoardService, from authenticated identity | Profile ownership |
| firstName | User input through BoardService | First name |
| lastName | User input through BoardService | Last name |
| role | BoardService, fixed to member | Descriptive role |
| registrationDateTime | Firestore server timestamp | Registration time |

Only the owner can read their profile. Rules permit a validated initial
create and deny client updates and deletes.

The role field does not grant administrative privileges.

### Shared board: messages/{messageId}

| Field | Writer | Purpose |
|---|---|---|
| schemaVersion | BoardService, fixed to 2 | Message format |
| text | Author input through BoardService | Message content |
| authorUid | BoardService, from authenticated identity | Ownership |
| authorName | BoardService, from the user's profile | Public attribution |
| createdAt | Firestore server timestamp | Creation and ordering |
| editedAt | Initially null; server timestamp on edit | Edit indication |

Signed-in users can read messages. Rules validate creation and permit
only the author to edit message text or delete the document.

authorName intentionally copies the profile name into shared board
content. Names used during testing must be fictional.

Migrated messages may retain legacy fields, including body, to preserve
the original data. New messages use the six-field version-2 schema.

## Duplicate submission and recovery

A MessageDraft receives one document ID before submission. The app
retains that draft while retrying an uncertain submission.

The transaction reads the exact document first. If absent, it creates
the message. If present with matching content, it reuses the existing
message. Conflicting content produces a collision error.

The transaction callback contains no UI updates or ID generation.

The current retry identity is held in memory. It does not provide
persistent draft recovery after process termination.

## Offline behavior and stream lifecycle

Transaction-based message creation requires a connection. An offline
failure must not be presented as a successful cloud save.

Ordinary edit and delete operations can remain pending while offline.
The current interface keeps those operations busy until they settle.

The board uses a stable stream stored in its State object.
StreamBuilder manages its subscription lifecycle. A displayed cached
message alone does not prove a new cloud operation succeeded.

## Automated checks

From the Flutter project root:

    flutter analyze
    flutter test

With the Firebase emulators running, open another terminal:

    cd rules-tests
    npm ci
    npm test
    node --test migration.test.js
    node --test idempotency.test.js

npm ci requires the committed package-lock.json.

The rules suite resets emulator Firestore data. Capture any needed
evidence before running it.

The migration test seeds legacy messages, preserves original fields,
checks repeatability, and rejects an incomplete legacy message.

The idempotency test sends concurrent same-ID requests and a retry,
then verifies one unchanged message. It also checks collision handling.

These JavaScript tests exercise the rules and transaction design.
They do not replace testing the Flutter implementation.

## Current evidence status

- Migration emulator test: 2 passed, 0 failed.
- Concurrent duplicate/retry test: 1 passed, 0 failed.
- Latest rules-suite result: awaiting recorded confirmation.
- Latest Flutter analysis and widget-test results: awaiting confirmation.
- App connected to local emulators: pending.
- Exact release APK and Samsung checks: pending.
- Deployed-cloud authorization and live-update evidence: pending.

## Build and release verification

    flutter build apk --release

Output:

    build/app/outputs/flutter-apk/app-release.apk

Install and test the exact APK that will be submitted.

The release checklist includes splash, authentication, the five-field
profile, message CRUD, live updates from another client, direct
signed-out and cross-user rule denials, and duplicate submission.

Record the APK build, commit, device, action, expected result, observed
result, and pass/fail. Pending checks must not be reported as passes.

## Selected graduate spices

1. Emulator Explorer
2. Rules Unit Tester
4. Idempotent Alchemist
5. Schema Shape-shifter

Completion requires the corresponding evidence, including the
app-based emulator workflow and final release checks.

## AI assistance

ChatGPT assisted with test planning, and design review.

The evidence document records my initial architectural
claim, risk, three proposed tests, the AI review, documentation checks,
and a challenged claim about draft lifetime.

## Submission

- Public repository with current source, rules, setup, and commits
- Install-tested release APK
- One Word or PDF document containing reflection, graduate AI critique,
  all three case-file answers, test records, and captioned evidence