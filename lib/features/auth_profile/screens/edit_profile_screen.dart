import '../../../core/localization/app_localizations.dart';
import '../../../core/firebase/backend_error.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/heritage_app_bar.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../../../shared/widgets/heritage_text_field.dart';
import '../models/user_profile.dart';
import '../services/auth_validators.dart';
import '../services/profile_service.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _bio = TextEditingController();
  UserProfile? _original;
  bool _removePhoto = false;
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_original != null) return;
    final profile = ProfileScope.of(context).profile;
    _original = profile;
    _name.text = profile.fullName;
    _email.text = profile.email;
    _phone.text = profile.phone;
    _bio.text = profile.bio;
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = ProfileScope.of(context);
    final updated = _original!.copyWith(
      fullName: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      bio: _bio.text.trim(),
      removePhoto: _removePhoto,
    );
    setState(() => _busy = true);
    try {
      await service.update(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: UiText('Profile updated successfully')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: UiText(backendMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    FocusScope.of(context).unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const UiText('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const UiText('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const UiText('Remove Photo'),
              onTap: () => Navigator.pop(context, 'remove'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'remove') {
      setState(() => _removePhoto = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: UiText(
            'Photo selection will be connected during device integration.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: HeritageAppBar(title: 'Edit Profile', showBackButton: !_busy),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: ProfileAvatar(
                        profile: _original!.copyWith(removePhoto: _removePhoto),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _changePhoto,
                        child: const UiText('Change Photo'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    HeritageTextField(
                      label: 'Full Name',
                      controller: _name,
                      validator: (value) =>
                          localizeError(context, (AuthValidators.name)(value)),
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    HeritageTextField(
                      label: 'Email',
                      controller: _email,
                      validator: (value) =>
                          localizeError(context, (AuthValidators.email)(value)),
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_busy,
                    ),
                    if (ProfileScope.of(context).isCloud)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: UiText(
                          'This is your contact email. Your sign-in email is unchanged.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    HeritageTextField(
                      label: 'Phone',
                      controller: _phone,
                      validator: (value) =>
                          localizeError(context, (AuthValidators.phone)(value)),
                      keyboardType: TextInputType.phone,
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 16),
                    HeritageTextField(
                      label: 'Bio',
                      controller: _bio,
                      validator: (value) =>
                          localizeError(context, (AuthValidators.bio)(value)),
                      maxLength: 150,
                      maxLines: 3,
                      keyboardType: TextInputType.multiline,
                      enabled: !_busy,
                    ),
                    const SizedBox(height: 24),
                    HeritageButton(
                      label: 'Save Changes',
                      onPressed: _save,
                      isLoading: _busy,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
