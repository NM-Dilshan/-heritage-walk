import 'package:flutter/material.dart';

import '../models/user_profile.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.profile, this.radius = 42});
  final UserProfile profile;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final parts = profile.fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    final initials = parts.isEmpty
        ? '?'
        : '${parts.first.characters.first}${parts.length > 1 ? parts.last.characters.first : ''}'
              .toUpperCase();
    final path = profile.photoPath;
    // Only project asset photos are supported before device integration.
    return Semantics(
      label: 'Profile photo for ${profile.fullName}',
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: path == null
            ? Text(initials, style: Theme.of(context).textTheme.headlineMedium)
            : ClipOval(
                child: Image.asset(
                  path,
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, stack) => Text(initials),
                ),
              ),
      ),
    );
  }
}
