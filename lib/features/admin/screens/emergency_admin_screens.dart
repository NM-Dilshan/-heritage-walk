import 'package:flutter/material.dart';

import '../../../core/firebase/backend_error.dart';
import '../../../core/routes/app_routes.dart';
import '../../discovery_planning/widgets/discovery_layout.dart';
import '../../navigation_guide/models/emergency_contact.dart';
import '../../navigation_guide/services/emergency_controller.dart';

class AdminEmergencyScreen extends StatefulWidget {
  const AdminEmergencyScreen({super.key});
  @override
  State<AdminEmergencyScreen> createState() => _AdminEmergencyScreenState();
}

class _AdminEmergencyScreenState extends State<AdminEmergencyScreen> {
  String _query = '', _category = 'All';
  Future<void> _delete(
    EmergencyController service,
    EmergencyContact contact,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${contact.name}?'),
        content: const Text('This removes the contact from Emergency Support.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await service.delete(contact.id);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(backendMessage(error))));
      }
    }
  }

  Future<void> _view(EmergencyContact contact) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(contact.name),
      content: SingleChildScrollView(
        child: Text(
          '${contact.phoneNumber ?? ""}\n${contact.category}\n${contact.description}\nPriority: ${contact.priority}\n'
          '${contact.isActive ? "Active" : "Inactive"} • ${contact.isVerified ? "Verified" : "Unverified"}\n'
          'Created: ${contact.createdAt?.toLocal() ?? "Unknown"}\nCreated by: ${contact.createdBy}\n'
          'Updated: ${contact.updatedAt?.toLocal() ?? "Unknown"}\nUpdated by: ${contact.updatedBy}',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final service = EmergencyScope.of(context);
    final contacts = service.search(query: _query, category: _category);
    return DiscoveryLayout(
      title: 'Emergency Contacts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: service.busy
                ? null
                : () =>
                      Navigator.pushNamed(context, AppRoutes.adminEmergencyAdd),
            icon: const Icon(Icons.add),
            label: const Text('Add Contact'),
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search contacts',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category filter'),
            items: [
              for (final category in ['All', ...EmergencyContact.categories])
                DropdownMenuItem(value: category, child: Text(category)),
            ],
            onChanged: (value) => setState(() => _category = value ?? 'All'),
          ),
          if (service.adminLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (service.adminError != null) ...[
            Text(service.adminError!),
            TextButton(
              onPressed: service.reloadAdmin,
              child: const Text('Reload contacts'),
            ),
          ],
          if (service.busy) const LinearProgressIndicator(),
          if (!service.adminLoading &&
              service.adminError == null &&
              contacts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No emergency contacts found. Add a contact with an independently verified number.',
              ),
            ),
          for (final contact in contacts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${contact.category} • ${contact.phoneNumber} • Priority ${contact.priority}',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          label: Text(contact.isActive ? 'Active' : 'Inactive'),
                        ),
                        Chip(
                          label: Text(
                            contact.isVerified ? 'Verified' : 'Unverified',
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _view(contact),
                          child: const Text('View'),
                        ),
                        TextButton(
                          onPressed: service.busy
                              ? null
                              : () => Navigator.pushNamed(
                                  context,
                                  AppRoutes.adminEmergencyEdit,
                                  arguments: contact.id,
                                ),
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: service.busy
                              ? null
                              : () => _delete(service, contact),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AdminEmergencyForm extends StatefulWidget {
  const AdminEmergencyForm({super.key, this.contactId});
  final String? contactId;
  @override
  State<AdminEmergencyForm> createState() => _AdminEmergencyFormState();
}

class _AdminEmergencyFormState extends State<AdminEmergencyForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _description = TextEditingController(),
      _priority = TextEditingController(text: '100');
  String? _category, _id, _error;
  EmergencyContact? _original;
  bool _active = true, _verified = false, _saving = false, _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final service = EmergencyScope.of(context);
    if (widget.contactId != null) {
      if (service.adminLoading) return;
      _original = service.adminContacts
          .where((c) => c.id == widget.contactId)
          .firstOrNull;
      if (_original == null) return;
      _name.text = _original!.name;
      _phone.text = _original!.phoneNumber ?? '';
      _description.text = _original!.description;
      _priority.text = _original!.priority.toString();
      _category = _original!.category;
      _active = _original!.isActive;
      _verified = _original!.isVerified;
    }
    _id = _original?.id ?? service.repository?.newId();
    _initialized = true;
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _description, _priority]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save(EmergencyController service) async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final contact = EmergencyContact.fromMap({
      ...?_original?.toMap(),
      'id': _id,
      'name': _name.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'description': _description.text.trim(),
      'category': _category,
      'priority': int.parse(_priority.text.trim()),
      'isActive': _active,
      'isVerified': _verified,
    });
    try {
      await service.save(contact, create: _original == null);
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) setState(() => _error = backendMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = EmergencyScope.of(context);
    return PopScope(
      canPop: !_saving,
      child: DiscoveryLayout(
        title: _original == null
            ? 'Add Emergency Contact'
            : 'Edit Emergency Contact',
        child: !_initialized
            ? service.adminLoading
                  ? const Center(child: CircularProgressIndicator())
                  : const Text(
                      'This contact is unavailable. Return to the list.',
                    )
            : Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter a number you have checked with an authoritative source. No emergency numbers are supplied automatically.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                      ),
                      validator: EmergencyValidation.requiredText,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        for (final category in EmergencyContact.categories)
                          DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                      ],
                      validator: EmergencyValidation.requiredText,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _category = value),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phone,
                      enabled: !_saving,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                      ),
                      validator: EmergencyValidation.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      enabled: !_saving,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                      validator: EmergencyValidation.requiredText,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _priority,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Priority (0–999; lower first)',
                      ),
                      validator: EmergencyValidation.priority,
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: _active,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _active = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verified'),
                      subtitle: const Text(
                        'Mark verified only after checking an authoritative source',
                      ),
                      value: _verified,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _verified = value),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_saving) const LinearProgressIndicator(),
                    FilledButton(
                      onPressed: _saving || service.busy
                          ? null
                          : () => _save(service),
                      child: const Text('Save Contact'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }
}
