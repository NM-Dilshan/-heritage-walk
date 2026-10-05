import 'place_image_catalog.dart';

abstract final class PlaceValidation {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty
      ? 'This field is required'
      : value.trim().length > 10000
      ? 'Use at most 10000 characters'
      : null;
  static String? coordinate(String? value, double limit) {
    if (value == null || value.trim().isEmpty) return null;
    final number = double.tryParse(value.trim());
    return number == null || !number.isFinite || number.abs() > limit
        ? 'Enter a number between -${limit.toInt()} and ${limit.toInt()}'
        : null;
  }

  static String? image(String? value) =>
      value == null ||
          value.trim().isEmpty ||
          PlaceImageReferences.isAsset(value.trim()) ||
          PlaceImageReferences.isRemote(value.trim())
      ? null
      : 'Enter a packaged assets/ path or valid HTTPS image URL';
}
