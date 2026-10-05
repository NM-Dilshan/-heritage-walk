import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InviteCodeCard extends StatelessWidget {
  const InviteCodeCard({super.key, required this.code});
  final String code;
  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Invite Code', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(
            code,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text('Share this code with your travel group.'),
          const SizedBox(height: 4),
          const Text(
            'Signed-in users can join with this code. Keep it private to your travel group.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy'),
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: code));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invite code copied')),
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to copy the invite code.'),
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    ),
  );
}
