import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'board_screen.dart';
import 'profile_setup_screen.dart';

class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key, required this.user});
  final User user;

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(child: Text('Could not load profile. Try again.')),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final data = snapshot.data?.data();
        final isComplete = data != null
          && (data['firstName'] as String?)?.isNotEmpty == true
          && (data['lastName'] as String?)?.isNotEmpty == true
          && (data['role'] as String?)?.isNotEmpty == true;
          if (!isComplete) {
          return ProfileSetupScreen(user: user, existing: data);
        }
        return const BoardScreen();
      },
    );
  }
}