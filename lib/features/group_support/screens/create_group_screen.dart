import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../../discovery_planning/services/discovery_scope.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../services/group_tour_service.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});
  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  String? _destination;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final place = DiscoveryScope.of(context).discovery.places
        .firstWhere((place) => place.id == _destination);
    final group = GroupTourScope.of(context).createGroup(_name.text, place);
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.groupDetails,
      arguments: group.id,
    );
  }

  @override
  Widget build(BuildContext context) => DiscoveryLayout(
    title: 'Create New Group',
    child: Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Bring your travel group together',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'You will lead this group. Added demo members are demonstration entries, not real user accounts.',
          ),
          const SizedBox(height: 24),
          HeritageTextField(
            label: 'Group Name',
            controller: _name,
            maxLength: 60,
            validator: GroupTourService.validateName,
            prefixIcon: const Icon(Icons.groups_outlined),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(
              DiscoveryScope.of(context).discovery.places
                  .map((p) => p.id)
                  .join(','),
            ),
            initialValue:
                DiscoveryScope.of(context).discovery.places
                    .any((p) => p.id == _destination)
                ? _destination
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Destination'),
            items: DiscoveryScope.of(context).discovery.places
                .map(
                  (place) => DropdownMenuItem(
                    value: place.id,
                    child: Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            validator: (value) =>
                !DiscoveryScope.of(context).discovery.places
                    .any((p) => p.id == value)
                ? 'Select a destination'
                : null,
            onChanged: (value) => _destination = value,
          ),
          const SizedBox(height: 28),
          HeritageButton(label: 'Create Group', onPressed: _create),
        ],
      ),
    ),
  );
}
