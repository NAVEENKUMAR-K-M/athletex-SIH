// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Auth + basic user/profile data access.
/// Collections used:
/// - users/{uid}          : { email, role, createdAt, ... }
/// - athletes/{uid}       : athlete profile (created lazily if role == 'athlete')
/// - admins/{uid} (opt.)  : admin profile (created lazily if role == 'admin')
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Sign up with email/password and persist role in `users/{uid}`.
  /// If role == 'athlete', creates a minimal profile in `athletes/{uid}`.
  Future<User?> signUp(String email, String password, String role) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // users/{uid}
      await _firestore.collection('users').doc(uid).set({
        'email': email,
        'role': role,
        'createdAt': Timestamp.now(),
      }, SetOptions(merge: true));

      // Create minimal profile based on role
      if (role == 'athlete') {
        await _ensureAthleteProfile(uid: uid, email: email);
      } else if (role == 'admin') {
        await _ensureAdminProfile(uid: uid, email: email);
      }

      return userCredential.user;
    } catch (e) {
      print('Signup error: $e');
      return null;
    }
  }

  /// Email/password login
  Future<User?> logIn(String email, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Google sign-in (creates users/{uid} on first login).
  /// Defaults role to 'athlete' for brand new Google users and ensures an athlete profile.
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      final uid = user.uid;

      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        // New Google user → default to 'athlete'
        await userRef.set({
          'email': user.email,
          'role': 'athlete',
          'createdAt': Timestamp.now(),
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        }, SetOptions(merge: true));

        await _ensureAthleteProfile(
          uid: uid,
          email: user.email ?? '',
          displayName: user.displayName,
          photoURL: user.photoURL,
        );
      } else {
        // Existing user: ensure profile if role is athlete and profile missing
        final data = userDoc.data() ?? {};
        final role = (data['role'] ?? 'athlete').toString();
        if (role == 'athlete') {
          await _ensureAthleteProfile(
            uid: uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoURL: user.photoURL,
          );
        } else if (role == 'admin') {
          await _ensureAdminProfile(
            uid: uid,
            email: user.email ?? '',
            displayName: user.displayName,
            photoURL: user.photoURL,
          );
        }
      }

      return user;
    } catch (e) {
      print('Google sign-in error: $e');
      return null;
    }
  }

  /// Returns the role from users/{uid}. (null if not set)
  Future<String?> getUserRole(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data();
      return data?['role'] as String?;
    } catch (e) {
      print('Error fetching role: $e');
      return null;
    }
  }

  /// Loads athlete profile for the given uid.
  /// Tries `athletes/{uid}` first; if missing and users/{uid}.role == 'athlete',
  /// returns the users/{uid} data as a fallback (so your UI still has something).
  Future<Map<String, dynamic>?> getAthleteData(String uid) async {
    try {
      // Prefer dedicated athlete profile
      final athleteDoc = await _firestore.collection('athletes').doc(uid).get();
      if (athleteDoc.exists) {
        final data = athleteDoc.data();
        return data == null ? null : Map<String, dynamic>.from(data);
      }

      // Fallback to users/{uid} if role == athlete
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null;
      final userData = userDoc.data() ?? {};
      if ((userData['role'] ?? '') == 'athlete') {
        return Map<String, dynamic>.from(userData);
      }

      return null;
    } catch (e) {
      print('getAthleteData error: $e');
      return null;
    }
  }

  /// Sign out (also signs out Google if applicable)
  Future<void> logOut() async {
    try {
      // Google may throw if not connected—wrap in try/catch
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  User? get currentUser => _auth.currentUser;

  // -------------------------
  // Helpers (internal)
  // -------------------------

  Future<void> _ensureAthleteProfile({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    final ref = _firestore.collection('athletes').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    // Create a minimal profile doc
    await ref.set({
      'uid': uid,
      'email': email,
      'name': displayName ?? _guessNameFromEmail(email),
      'photoURL': photoURL,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
      // Add more athlete fields as needed (age, sport, etc.)
    }, SetOptions(merge: true));
  }

  Future<void> _ensureAdminProfile({
    required String uid,
    required String email,
    String? displayName,
    String? photoURL,
  }) async {
    final ref = _firestore.collection('admins').doc(uid);
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'uid': uid,
      'email': email,
      'name': displayName ?? _guessNameFromEmail(email),
      'photoURL': photoURL,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  String _guessNameFromEmail(String email) {
    final local = (email.split('@').first).replaceAll('.', ' ');
    if (local.isEmpty) return 'User';
    // Capitalize first letter of each part
    return local
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + (p.length > 1 ? p.substring(1) : ''))
        .join(' ');
  }
}
