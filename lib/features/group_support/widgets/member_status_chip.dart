import 'package:flutter/material.dart';

class MemberStatusChip extends StatelessWidget {
  const MemberStatusChip({super.key, required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) =>
      Chip(avatar: Icon(icon, size: 18), label: Text(label));
}
