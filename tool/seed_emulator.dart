// Seeds the local Firebase Auth + Firestore emulators with a small set of
// demo users and board messages, so the app has something to show without
// manually registering/posting through the UI every time the emulators
// restart.
//
// Prerequisite: the Firebase emulators must already be running, e.g.:
//   firebase emulators:start --only auth,firestore
//
// Usage (from the hw02/ project root):
//   dart run tool/seed_emulator.dart
//
// This talks directly to the emulators' REST APIs (no Flutter engine
// required), so it can be run as a plain Dart script independent of the app.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

const _authHost = 'localhost';
const _authPort = 9099;
const _firestoreHost = 'localhost';
const _firestorePort = 8080;

/// A demo user to create in the Auth emulator and mirror into the
/// `users/{uid}` Firestore collection (matches the fields written by
/// saveUserRecord() in lib/profile_setup_screen.dart).
class _SeedUser {
  const _SeedUser({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String role;
}

const _seedUsers = [
  _SeedUser(
    email: 'alice@example.com',
    password: 'password123',
    firstName: 'Alice',
    lastName: 'Nguyen',
    role: 'Student',
  ),
  _SeedUser(
    email: 'bob@example.com',
    password: 'password123',
    firstName: 'Bob',
    lastName: 'Russo',
    role: 'Student',
  ),
  _SeedUser(
    email: 'carol@example.com',
    password: 'password123',
    firstName: 'Carol',
    lastName: 'Kim',
    role: 'Instructor',
  ),
];

/// Sample board messages to post, keyed by the seed user's email who should
/// be recorded as the author.
const _seedMessages = [
  ('alice@example.com', 'Hey everyone, excited for this project!'),
  ('bob@example.com', 'Does anyone know when the next assignment is due?'),
  ('alice@example.com', 'Just pushed the Firestore rules, take a look.'),
  ('carol@example.com', 'Reminder: office hours are at 3pm today.'),
];

Future<void> main() async {
  final projectId = await _readProjectId();
  stdout.writeln('Seeding project "$projectId" via local emulators...');

  final client = http.Client();
  try {
    final tokensByEmail = <String, _AuthResult>{};
    for (final user in _seedUsers) {
      final auth = await _ensureUser(client, user);
      tokensByEmail[user.email] = auth;
      await _writeUserProfile(client, projectId: projectId, auth: auth, user: user);
      stdout.writeln('  user ready: ${user.email} (uid: ${auth.uid})');
    }

    for (final (email, text) in _seedMessages) {
      final auth = tokensByEmail[email]!;
      final user = _seedUsers.firstWhere((u) => u.email == email);
      await _postMessage(
        client,
        projectId: projectId,
        auth: auth,
        authorName: '${user.firstName} ${user.lastName}',
        text: text,
      );
      stdout.writeln('  message posted as ${user.firstName}: "$text"');
    }

    stdout.writeln('Done. Seeded ${_seedUsers.length} users and ${_seedMessages.length} messages.');
  } finally {
    client.close();
  }
}

/// Reads the Firebase projectId out of firebase.json so this script stays in
/// sync with whatever project `flutterfire configure` set up.
Future<String> _readProjectId() async {
  final file = File('firebase.json');
  final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  final flutter = json['flutter'] as Map<String, dynamic>;
  final platforms = flutter['platforms'] as Map<String, dynamic>;
  final firstPlatform = platforms.values.first as Map<String, dynamic>;
  final firstConfig = firstPlatform.values.first as Map<String, dynamic>;
  return firstConfig['projectId'] as String;
}

class _AuthResult {
  _AuthResult({required this.uid, required this.idToken});
  final String uid;
  final String idToken;
}

/// Creates the user in the Auth emulator, or signs in if it already exists
/// from a previous seeding run (emulator data resets on restart unless you
/// use --export-on-exit / --import).
Future<_AuthResult> _ensureUser(http.Client client, _SeedUser user) async {
  final signUpResponse = await client.post(
    Uri.http('$_authHost:$_authPort', '/identitytoolkit.googleapis.com/v1/accounts:signUp', {
      'key': 'fake-api-key',
    }),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': user.email,
      'password': user.password,
      'returnSecureToken': true,
    }),
  );

  final signUpBody = jsonDecode(signUpResponse.body) as Map<String, dynamic>;
  if (signUpResponse.statusCode == 200) {
    return _AuthResult(uid: signUpBody['localId'] as String, idToken: signUpBody['idToken'] as String);
  }

  final errorMessage = (signUpBody['error'] as Map<String, dynamic>?)?['message'];
  if (errorMessage != 'EMAIL_EXISTS') {
    throw Exception('Failed to create ${user.email}: ${signUpResponse.body}');
  }

  final signInResponse = await client.post(
    Uri.http('$_authHost:$_authPort', '/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword', {
      'key': 'fake-api-key',
    }),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'email': user.email,
      'password': user.password,
      'returnSecureToken': true,
    }),
  );
  if (signInResponse.statusCode != 200) {
    throw Exception('Failed to sign in existing user ${user.email}: ${signInResponse.body}');
  }
  final signInBody = jsonDecode(signInResponse.body) as Map<String, dynamic>;
  return _AuthResult(uid: signInBody['localId'] as String, idToken: signInBody['idToken'] as String);
}

/// Writes users/{uid} with the same 5 fields saveUserRecord() writes in the
/// real app, so the profile gate treats this account as fully onboarded.
Future<void> _writeUserProfile(
  http.Client client, {
  required String projectId,
  required _AuthResult auth,
  required _SeedUser user,
}) async {
  final uri = Uri.http(
    '$_firestoreHost:$_firestorePort',
    '/v1/projects/$projectId/databases/(default)/documents/users/${auth.uid}',
  );
  final response = await client.patch(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${auth.idToken}',
    },
    body: jsonEncode({
      'fields': {
        'uid': {'stringValue': auth.uid},
        'firstName': {'stringValue': user.firstName},
        'lastName': {'stringValue': user.lastName},
        'role': {'stringValue': user.role},
        'registrationDateTime': {'timestampValue': DateTime.now().toUtc().toIso8601String()},
      },
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to write profile for ${user.email}: ${response.body}');
  }
}

const _docIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// Generates a random document ID in the same spirit as Firestore's
/// auto-generated IDs (any unique string works; it doesn't need to match
/// Firestore's own ID algorithm).
String _randomDocId() {
  final rand = Random.secure();
  return List.generate(20, (_) => _docIdChars[rand.nextInt(_docIdChars.length)]).join();
}

/// Posts a message as the given authenticated user, matching the fields
/// BoardService.postMessage() writes in lib/board_service.dart.
///
/// firestore.rules requires `createdAt == request.time` (a true server
/// timestamp), so this uses the `:commit` endpoint with a `REQUEST_TIME`
/// field transform rather than a plain client-supplied timestamp value,
/// which the rules would otherwise reject.
Future<void> _postMessage(
  http.Client client, {
  required String projectId,
  required _AuthResult auth,
  required String authorName,
  required String text,
}) async {
  final docId = _randomDocId();
  final uri = Uri.http(
    '$_firestoreHost:$_firestorePort',
    '/v1/projects/$projectId/databases/(default)/documents:commit',
  );
  final response = await client.post(
    uri,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${auth.idToken}',
    },
    body: jsonEncode({
      'writes': [
        {
          'update': {
            'name': 'projects/$projectId/databases/(default)/documents/messages/$docId',
            'fields': {
              'authorUid': {'stringValue': auth.uid},
              'authorName': {'stringValue': authorName},
              'text': {'stringValue': text},
            },
          },
          'updateTransforms': [
            {'fieldPath': 'createdAt', 'setToServerValue': 'REQUEST_TIME'},
          ],
        },
      ],
    }),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to post message "$text": ${response.body}');
  }
}
