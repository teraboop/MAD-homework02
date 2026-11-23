import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.user, this.existing});
  final User user;
  final Map<String, dynamic>? existing;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  Future<void> saveUserRecord(User user, {
      required String firstName,
      required String lastName,
      required String role,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'firstName': firstName,
          'lastName': lastName,
          'role': role,
          'registrationDateTime': FieldValue.serverTimestamp(),
        });
  }
  Widget build(BuildContext context) {
    final firstNameController = TextEditingController(text: widget.existing?['firstName']);
    final lastNameController = TextEditingController(text: widget.existing?['lastName']);
    final roleController = TextEditingController(text: widget.existing?['role']);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile Setup')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: 'Role'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await saveUserRecord(
                  widget.user,
                  firstName: firstNameController.text,
                  lastName: lastNameController.text,
                  role: roleController.text,
                );
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}