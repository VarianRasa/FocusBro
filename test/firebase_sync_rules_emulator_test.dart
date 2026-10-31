import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusbro/firebase_options.dart';
import 'package:focusbro/services/firebase_emulator_config.dart';

void main() {
  test(
    'Firestore emulator enforces owner access and denies cross-user writes',
    () async {
      const host = '127.0.0.1';
      final client = HttpOverrides.runWithHttpOverrides(
        HttpClient.new,
        _LocalEmulatorHttpOverrides(),
      );
      addTearDown(() => client.close(force: true));

      final projectId = DefaultFirebaseOptions.currentPlatform.projectId;
      final owner = await _createEmulatorAccount(
        client,
        host,
        FirebaseEmulatorConfig.authPort,
        'firestore-owner-${DateTime.now().microsecondsSinceEpoch}@example.test',
      );
      final documentId = 'task-${DateTime.now().microsecondsSinceEpoch}';
      final ownerDocument = _documentUri(
        host,
        FirebaseEmulatorConfig.firestorePort,
        projectId,
        owner.uid,
        'tasks',
        documentId,
      );

      expect(
        await _commitRecord(
          client,
          host,
          FirebaseEmulatorConfig.firestorePort,
          projectId,
          owner.uid,
          'tasks',
          documentId,
          'Owner task',
          owner.idToken,
        ),
        200,
      );
      expect(
        await _send(client, 'GET', ownerDocument, idToken: owner.idToken),
        200,
      );

      final other = await _createEmulatorAccount(
        client,
        host,
        FirebaseEmulatorConfig.authPort,
        'firestore-other-${DateTime.now().microsecondsSinceEpoch}@example.test',
      );
      expect(
        await _send(client, 'GET', ownerDocument, idToken: other.idToken),
        403,
      );
      expect(
        await _commitRecord(
          client,
          host,
          FirebaseEmulatorConfig.firestorePort,
          projectId,
          owner.uid,
          'tasks',
          documentId,
          'Unauthorized overwrite',
          other.idToken,
        ),
        403,
      );
      expect(
        await _send(client, 'GET', ownerDocument),
        403,
      );
      expect(
        await _send(client, 'DELETE', ownerDocument, idToken: owner.idToken),
        403,
      );

      expect(
        await _commitRecord(
          client,
          host,
          FirebaseEmulatorConfig.firestorePort,
          projectId,
          owner.uid,
          'files',
          'file-$documentId',
          'Files remain local',
          owner.idToken,
        ),
        403,
      );
    },
    skip: !FirebaseEmulatorConfig.useEmulators,
  );
}

Future<_EmulatorAccount> _createEmulatorAccount(
  HttpClient client,
  String host,
  int port,
  String email,
) async {
  final uri = Uri(
    scheme: 'http',
    host: host,
    port: port,
    path: '/identitytoolkit.googleapis.com/v1/accounts:signUp',
    queryParameters: const {'key': 'emulator-test-key'},
  );
  final request = await client.postUrl(uri);
  request.headers.contentType = ContentType.json;
  request.write(
    jsonEncode({
      'email': email,
      'password': 'LocalEmulatorTest123!',
      'returnSecureToken': true,
    }),
  );
  final response = await request.close();
  final responseBody = await utf8.decoder.bind(response).join();
  if (response.statusCode != HttpStatus.ok) {
    throw StateError(
      'Auth emulator account creation failed with HTTP ${response.statusCode}.',
    );
  }
  final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
  return _EmulatorAccount(
    uid: decoded['localId'] as String,
    idToken: decoded['idToken'] as String,
  );
}

Future<int> _commitRecord(
  HttpClient client,
  String host,
  int port,
  String projectId,
  String uid,
  String collection,
  String documentId,
  String title,
  String idToken,
) {
  final uri = Uri.parse(
    'http://$host:$port/v1/projects/$projectId/'
    'databases/(default)/documents:commit',
  );
  final documentName = 'projects/$projectId/databases/(default)/documents/'
      'users/$uid/sync/v1/$collection/$documentId';
  return _send(
    client,
    'POST',
    uri,
    idToken: idToken,
    body: {
      'writes': [
        {
          'update': {
            'name': documentName,
            'fields': {
              'entityId': {'stringValue': documentId},
              'schemaVersion': {'integerValue': '1'},
              'updatedAt': {
                'timestampValue': DateTime.now().toUtc().toIso8601String(),
              },
              'deletedAt': {'nullValue': 'NULL_VALUE'},
              'payload': {
                'mapValue': {
                  'fields': {
                    'title': {'stringValue': title},
                  },
                },
              },
            },
          },
        },
      ],
    },
  );
}

Uri _documentUri(
  String host,
  int port,
  String projectId,
  String uid,
  String collection,
  String documentId,
) {
  return Uri(
    scheme: 'http',
    host: host,
    port: port,
    pathSegments: [
      'v1',
      'projects',
      projectId,
      'databases',
      '(default)',
      'documents',
      'users',
      uid,
      'sync',
      'v1',
      collection,
      documentId,
    ],
  );
}

Future<int> _send(
  HttpClient client,
  String method,
  Uri uri, {
  String? idToken,
  Map<String, Object?>? body,
}) async {
  final request = await client.openUrl(method, uri);
  request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
  if (idToken != null) {
    request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $idToken');
  }
  if (body != null) {
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
  }
  final response = await request.close();
  await utf8.decoder.bind(response).join();
  return response.statusCode;
}

class _EmulatorAccount {
  const _EmulatorAccount({required this.uid, required this.idToken});

  final String uid;
  final String idToken;
}

class _LocalEmulatorHttpOverrides extends HttpOverrides {}
