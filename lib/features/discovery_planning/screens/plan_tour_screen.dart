import '../../../core/localization/app_localizations.dart';

import 'package:flutter/material.dart';

import '../../../core/routes/app_routes.dart';
import '../../../shared/widgets/heritage_button.dart';
import '../models/itinerary.dart';
import '../services/discovery_scope.dart';
import '../services/itinerary_service.dart';
import '../widgets/category_chip.dart';
import '../widgets/discovery_layout.dart';
import '../widgets/section_header.dart';

class PlanTourScreen extends StatefulWidget {
  const PlanTourScreen({super.key});
  @override
  State<PlanTourScreen> createState() => _PlanTourScreenState();
}

class _PlanTourScreenState extends State<PlanTourScreen> {
  final _form = GlobalKey<FormState>();
  String? _destination, _duration;
  DateTime? _date;
  final Set<String> _interests = {};
  String _style = 'Balanced';
  bool _initialized = false;
  bool _busy = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final plan =
        ModalRoute.of(context)?.settings.arguments as TourPlan? ??
        DiscoveryScope.of(context).itineraries.draftPlan;
    if (plan != null) {
      _destination = plan.destination;
      _duration = plan.duration;
      _date = plan.date;
      _interests.addAll(plan.interests);
      _style = plan.travelStyle;
    }
    _initialized = true;
  }

  Future<void> _generate() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final service = DiscoveryScope.of(context).itineraries;
    final plan = TourPlan(
      destination: _destination!,
      date: _date!,
      duration: _duration!,
      interests: _interests.toList(),
      travelStyle: _style,
    );
    setState(() => _busy = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      final itinerary = service.generate(plan);
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.generatedItinerary,
        arguments: itinerary.id,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: UiText(
              'Please check your selections and choose a future date.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: DiscoveryLayout(
      title: 'Plan Your Tour',
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            UiText(
              'Create a personalized heritage journey',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SectionHeader(title: 'Choose your destination'),
            DropdownButtonFormField<String>(
              key: ValueKey(
                DiscoveryScope.of(context).discovery.availableDestinations
                    .join(','),
              ),
              initialValue:
                  DiscoveryScope.of(context).discovery.availableDestinations
                      .contains(_destination)
                  ? _destination
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: AppLocalizations.text(
                  context,
                  'Where would you like to explore?',
                ),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              items: DiscoveryScope.of(context).discovery.availableDestinations
                  .map(
                    (destination) => DropdownMenuItem(
                      value: destination,
                      child: Text(destination),
                    ),
                  )
                  .toList(),
              validator: (value) => localizeError(
                context,
                ((value) =>
                    !DiscoveryScope.of(context).discovery.availableDestinations
                        .contains(value)
                    ? 'Select a destination'
                    : null)(value),
              ),
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _destination = value),
            ),
            const SectionHeader(title: 'When are you going?'),
            FormField<DateTime>(
              initialValue: _date,
              validator: (value) => localizeError(
                context,
                ((value) {
                  if (value == null) return 'Select a date';
                  final now = DateTime.now();
                  return DateUtils.dateOnly(value)
                          .isBefore(DateUtils.dateOnly(now))
                      ? 'Choose today or a future date'
                      : null;
                })(value),
              ),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: UiText(
                      _date == null ? 'Select Date' : 'Select Date: {0}',
                      args: _date == null ? const [] : [formatTourDate(_date!)],
                    ),
                    onPressed: _busy
                        ? null
                        : () async {
                            final today = DateUtils.dateOnly(DateTime.now());
                            final initial =
                                _date == null || _date!.isBefore(today)
                                ? today
                                : _date!;
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: initial,
                              firstDate: today,
                              lastDate: DateTime(today.year + 5, 12, 31),
                            );
                            if (mounted && selected != null) {
                              setState(() => _date = selected);
                              field.didChange(selected);
                            }
                          },
                  ),
                  if (field.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: UiText(
                        field.errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SectionHeader(title: 'How much time do you have?'),
            FormField<String>(
              initialValue: _duration,
              validator: (value) => localizeError(
                context,
                ((value) => value == null ? 'Select a duration' : null)(value),
              ),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ItineraryService.durations
                        .map(
                          (duration) => CategoryChip(
                            label: duration,
                            selected: _duration == duration,
                            onSelected: () {
                              if (_busy) return;
                              setState(() => _duration = duration);
                              field.didChange(duration);
                            },
                          ),
                        )
                        .toList(),
                  ),
                  if (field.hasError)
                    UiText(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SectionHeader(
              title: 'What inspires you?',
              subtitle: 'Choose one or more interests',
            ),
            FormField<int>(
              initialValue: _interests.length,
              validator: (value) => localizeError(
                context,
                ((value) => (value ?? 0) == 0
                    ? 'Select at least one interest'
                    : null)(value),
              ),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ItineraryService.interests
                        .map(
                          (interest) => FilterChip(
                            label: UiText(interest),
                            selected: _interests.contains(interest),
                            onSelected: _busy
                                ? null
                                : (selected) {
                                    setState(() {
                                      if (selected) {
                                        _interests.add(interest);
                                      } else {
                                        _interests.remove(interest);
                                      }
                                    });
                                    field.didChange(_interests.length);
                                  },
                          ),
                        )
                        .toList(),
                  ),
                  if (field.hasError)
                    UiText(
                      field.errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            const SectionHeader(title: 'Your travel style'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ItineraryService.styles
                  .map(
                    (style) => CategoryChip(
                      label: style,
                      selected: _style == style,
                      onSelected: () {
                        if (!_busy) setState(() => _style = style);
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 28),
            HeritageButton(
              label: 'Generate My Itinerary',
              onPressed: _generate,
              isLoading: _busy,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}
