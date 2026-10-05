import 'package:flutter/material.dart';

import 'sync_controller.dart';

class CloudStatus extends StatelessWidget {
  const CloudStatus({
    super.key,
    required this.sync,
    required this.child,
    required this.onSignOut,
  });
  final SyncController sync;
  final Widget child;
  final VoidCallback onSignOut;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sync,
    builder: (context, _) => Column(
      children: [
        if (sync.busy || sync.error != null)
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sync.busy) ...[
                      Text(
                        sync.loading
                            ? 'Loading saved data…'
                            : 'Saving changes…',
                        semanticsLabel: sync.loading
                            ? 'Loading saved data'
                            : 'Saving changes, please wait',
                      ),
                      const SizedBox(height: 8),
                      const LinearProgressIndicator(),
                    ],
                    if (sync.error != null && !sync.busy) ...[
                      Text(sync.error!),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: sync.retry,
                            child: const Text('Reload Saved Data'),
                          ),
                          TextButton(
                            onPressed: onSignOut,
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: AbsorbPointer(
            absorbing: sync.busy || sync.error != null,
            child: child,
          ),
        ),
      ],
    ),
  );
}
