import '../localization/app_localizations.dart';
import '../../features/navigation_guide/models/navigation_destination.dart';
import '../../features/discovery_planning/screens/explore_screen.dart';
import '../../features/admin/screens/admin_reviews_screen.dart';

import 'package:flutter/material.dart';

import '../../features/admin/screens/admin_screens.dart';
import '../../features/admin/services/catalog_controller.dart';
import '../../features/admin/screens/emergency_admin_screens.dart';

import '../../features/foundation/screens/foundation_preview_screen.dart';

import '../../features/auth_profile/screens/splash_screen.dart';
import '../../features/auth_profile/screens/login_screen.dart';
import '../../features/auth_profile/screens/register_screen.dart';
import '../../features/auth_profile/screens/profile_screen.dart';
import '../../features/auth_profile/screens/edit_profile_screen.dart';
import '../../features/auth_profile/screens/auth_success_placeholder_screen.dart';

import '../../features/discovery_planning/screens/home_screen.dart';
import '../../features/discovery_planning/screens/plan_tour_screen.dart';
import '../../features/discovery_planning/screens/generated_itinerary_screen.dart';
import '../../features/discovery_planning/screens/favorites_screen.dart';
import '../../features/discovery_planning/screens/my_itineraries_screen.dart';

import '../../features/navigation_guide/screens/navigation_screen.dart';
import '../../features/navigation_guide/screens/place_details_screen.dart';
import '../../features/navigation_guide/screens/digital_guide_screen.dart';
import '../../features/navigation_guide/screens/nearby_facilities_screen.dart';
import '../../features/navigation_guide/screens/emergency_support_screen.dart';
import '../../features/navigation_guide/widgets/place_destination_chooser.dart';
import '../../features/discovery_planning/models/heritage_place.dart';

import '../../features/group_support/screens/group_tour_screen.dart';
import '../../features/group_support/screens/create_group_screen.dart';
import '../../features/group_support/screens/group_details_screen.dart';
import '../../features/group_support/screens/group_tracking_screen.dart';
import '../../features/group_support/models/tour_group.dart';
import '../../features/group_support/screens/language_selection_screen.dart';
import '../../features/group_support/screens/help_support_screen.dart';
import '../../features/group_support/screens/about_screen.dart';

abstract final class AppRoutes {
  static const adminReviews = '/admin/reviews';
  static const adminEmergency = '/admin/emergency-contacts';
  static const adminEmergencyAdd = '/admin/emergency-contacts/add';
  static const adminEmergencyEdit = '/admin/emergency-contacts/edit';
  static const admin = '/admin';
  static const adminPlaces = '/admin/places';
  static const adminPlaceAdd = '/admin/places/add';
  static const adminPlaceEdit = '/admin/places/edit';
  static const adminPlacePreview = '/admin/places/preview';
  static const foundation = '/';
  static const splash = '/splash';
  static const authSuccess = '/auth-success';
  static const login = '/login';
  static const register = '/register';
  static const home = '/home';
  static const explore = '/explore';
  static const planTour = '/plan-tour';
  static const itinerary = '/itinerary';
  static const generatedItinerary = '/generated-itinerary';
  static const itineraries = '/itineraries';
  static const favorites = '/favorites';
  static const map = '/map';
  static const navigation = '/navigation';
  static const placeDetails = '/place-details';
  static const digitalGuide = '/digital-guide';
  static const facilities = '/facilities';
  static const emergency = '/emergency';
  static const groupTour = '/group-tour';
  static const groupTours = '/group-tours';
  static const groupDetails = '/group-details';
  static const createGroup = '/create-group';
  static const groupTracking = '/group-tracking';
  static const language = '/language';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const help = '/help';
  static const helpSupport = '/help-support';
  static const about = '/about';

  // Only implemented modules are registered; future module routes are constants.
  static HeritagePlace? _optionalPlace(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return argument is HeritagePlace ? argument : null;
  }

  static Widget _placeScreen(
    BuildContext context,
    String title,
    String routeName,
    Widget Function(HeritagePlace) builder,
  ) {
    final place = _optionalPlace(context);
    return place == null
        ? PlaceDestinationChooser(title: title, routeName: routeName)
        : builder(place);
  }

  static String? _groupId(BuildContext context) {
    final argument = ModalRoute.of(context)?.settings.arguments;
    return argument is TourGroup
        ? argument.id
        : argument is String
        ? argument
        : null;
  }

  static Map<String, WidgetBuilder> get routes => {
    adminReviews: (_) => const AdminGuard(child: AdminReviewsScreen()),
    adminEmergency: (_) => const AdminGuard(child: AdminEmergencyScreen()),
    adminEmergencyAdd: (_) => const AdminGuard(child: AdminEmergencyForm()),
    adminEmergencyEdit: (context) => AdminGuard(
      child: AdminEmergencyForm(
        contactId: ModalRoute.of(context)?.settings.arguments is String
            ? ModalRoute.of(context)!.settings.arguments as String
            : '',
      ),
    ),
    admin: (_) => const AdminGuard(child: AdminDashboardScreen()),
    adminPlaces: (_) => const AdminGuard(child: AdminPlacesScreen()),
    adminPlaceAdd: (_) => const AdminGuard(child: AdminPlaceFormScreen()),
    adminPlaceEdit: (context) => AdminGuard(
      child: AdminPlaceFormScreen(
        placeId: ModalRoute.of(context)?.settings.arguments is String
            ? ModalRoute.of(context)!.settings.arguments as String
            : '',
      ),
    ),
    adminPlacePreview: (context) => AdminGuard(
      child: Builder(
        builder: (context) {
          final argument = _optionalPlace(context);
          final place = CatalogScope.of(context).places
              .where((p) => p.id == argument?.id)
              .firstOrNull;
          return place == null
              ? const Scaffold(
                  body: SafeArea(
                    child: Center(
                      child: UiText(
                        'This place is unavailable. Return to the catalog.',
                      ),
                    ),
                  ),
                )
              : PlaceDetailsScreen(place: place, adminPreview: true);
        },
      ),
    ),
    language: (_) => const LanguageSelectionScreen(),
    helpSupport: (_) => const HelpSupportScreen(),
    help: (_) => const HelpSupportScreen(),
    about: (_) => const AboutScreen(),
    foundation: (_) => const FoundationPreviewScreen(),
    groupTours: (_) => const GroupTourScreen(),
    groupTour: (_) => const GroupTourScreen(),
    createGroup: (_) => const CreateGroupScreen(),
    groupDetails: (context) => GroupDetailsScreen(groupId: _groupId(context)),
    groupTracking: (context) => GroupTrackingScreen(groupId: _groupId(context)),
    map: (context) => NavigationScreen(
      place: ModalRoute.of(context)?.settings.arguments is RouteDestination
          ? ModalRoute.of(context)!.settings.arguments as RouteDestination
          : null,
    ),
    navigation: (context) => NavigationScreen(
      place: ModalRoute.of(context)?.settings.arguments is RouteDestination
          ? ModalRoute.of(context)!.settings.arguments as RouteDestination
          : null,
    ),
    placeDetails: (context) => _placeScreen(
      context,
      'Place Details',
      placeDetails,
      (place) => PlaceDetailsScreen(place: place),
    ),
    digitalGuide: (context) => _placeScreen(
      context,
      'Digital Guide',
      digitalGuide,
      (place) => DigitalGuideScreen(place: place),
    ),
    facilities: (context) =>
        NearbyFacilitiesScreen(place: _optionalPlace(context)),
    emergency: (_) => const EmergencySupportScreen(),
    home: (_) => const HomeScreen(),
    explore: (_) => const ExploreScreen(),
    planTour: (_) => const PlanTourScreen(),
    generatedItinerary: (_) => const GeneratedItineraryScreen(),
    favorites: (_) => const FavoritesScreen(),
    itineraries: (_) => const MyItinerariesScreen(),
    itinerary: (_) => const MyItinerariesScreen(),
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    register: (_) => const RegisterScreen(),
    profile: (_) => const ProfileScreen(),
    editProfile: (_) => const EditProfileScreen(),
    authSuccess: (_) => const AuthSuccessPlaceholderScreen(),
  };
}
