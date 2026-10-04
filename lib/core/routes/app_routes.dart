import 'package:flutter/material.dart';

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

abstract final class AppRoutes {
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
  static const placeDetails = '/place-details';
  static const digitalGuide = '/digital-guide';
  static const facilities = '/facilities';
  static const emergency = '/emergency';
  static const groupTour = '/group-tour';
  static const createGroup = '/create-group';
  static const groupTracking = '/group-tracking';
  static const language = '/language';
  static const profile = '/profile';
  static const editProfile = '/edit-profile';
  static const help = '/help';
  static const about = '/about';

  // Only implemented modules are registered; future module routes are constants.
  static Map<String, WidgetBuilder> get routes => {
    foundation: (_) => const FoundationPreviewScreen(),
    home: (_) => const HomeScreen(),
    explore: (_) => const HomeScreen(),
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
