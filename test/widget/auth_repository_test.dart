import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:leaderboard/data/repositories/auth_repository.dart';

import '../helpers/mocks.dart';

void main() {
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;
  late AuthRepository authRepository;

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    authRepository = AuthRepository(client: mockClient);
  });

  Future<void> pumpSignIn(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => authRepository.signInWithEmailAndPassword(
                context: context,
                email: 'a@b.com',
                password: 'password',
              ),
              child: const Text('sign in'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sign in'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSignUp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => authRepository.signUpWithEmailAndPassword(
                context: context,
                username: 'devon',
                email: 'a@b.com',
                password: 'password',
              ),
              child: const Text('sign up'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('sign up'));
    await tester.pumpAndSettle();
  }

  group('signInWithEmailAndPassword error mapping', () {
    testWidgets('unconfirmed email shows the verify-first message', (
      tester,
    ) async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException('Email not confirmed'));

      await pumpSignIn(tester);

      expect(
        find.text('Please verify your email first, then sign in.'),
        findsOneWidget,
      );
    });

    testWidgets('rate limit shows the too-many-attempts message', (
      tester,
    ) async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException('Rate limit exceeded'));

      await pumpSignIn(tester);

      expect(
        find.text('Too many login attempts. Please wait and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('invalid credentials shows the incorrect-login message', (
      tester,
    ) async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException('Invalid login credentials'));

      await pumpSignIn(tester);

      expect(find.text('Incorrect email and/or password.'), findsOneWidget);
    });

    testWidgets('an unrecognized auth error falls back to a generic message', (
      tester,
    ) async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthException('Something else entirely'));

      await pumpSignIn(tester);

      expect(
        find.text('Auth error during sign in: Something else entirely'),
        findsOneWidget,
      );
    });

    testWidgets('a non-auth exception shows the generic retry message', (
      tester,
    ) async {
      when(
        () => mockAuth.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(Exception('boom'));

      await pumpSignIn(tester);

      expect(
        find.text('Error occurred during sign in. Try again.'),
        findsOneWidget,
      );
    });
  });

  group('signUpWithEmailAndPassword error mapping', () {
    testWidgets('a weak password shows the too-weak message', (tester) async {
      when(
        () => mockAuth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(AuthException('Password should be at least 6 characters'));

      await pumpSignUp(tester);

      expect(
        find.text(
          'The password provided is too weak (must be at least 6 characters).',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an already-registered email shows the account-exists message', (
      tester,
    ) async {
      when(
        () => mockAuth.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
          data: any(named: 'data'),
        ),
      ).thenThrow(AuthException('User already registered'));

      await pumpSignUp(tester);

      expect(
        find.text('An account already exists for that email.'),
        findsOneWidget,
      );
    });
  });

  group('signUpWithEmailAndPassword', () {
    testWidgets(
      'passes the username to auth and leaves the profile row to the database',
      (tester) async {
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async => AuthResponse(
            user: const User(
              id: 'u1',
              appMetadata: {},
              userMetadata: {'username': 'devon'},
              aud: 'authenticated',
              createdAt: '2026-09-16T00:00:00Z',
            ),
          ),
        );

        await pumpSignUp(tester);

        verify(
          () => mockAuth.signUp(
            email: 'a@b.com',
            password: 'password',
            data: {'username': 'devon'},
          ),
        ).called(1);
        // The on_auth_user_created trigger creates the users row; a write from
        // the app used to fail silently and leave accounts without one.
        verifyNever(() => mockClient.from(any()));
      },
    );
  });
}
