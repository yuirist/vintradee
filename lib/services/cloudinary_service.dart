import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:convert';

class CloudinaryService {
  // Cloudinary Configuration
  static const String cloudName = 'dfz9svj5s';
  static const String apiKey =
      '859337745878245'; // Not needed for unsigned uploads, but kept for reference
  static const String preset = 'vintrade_preset'; // Unsigned preset

  String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Upload an image file to Cloudinary using unsigned preset and return the secure URL
  ///
  /// [imageFile] - The image file to upload
  /// Returns the secure URL of the uploaded image
  Future<String> uploadImage(File imageFile) async {
    // Log configuration before upload
    debugPrint('📤 Starting Cloudinary upload...');
    debugPrint('   Cloud Name: $cloudName');
    debugPrint('   Preset: $preset (unsigned)');
    debugPrint('   Upload URL: $uploadUrl');
    debugPrint('   Image path: ${imageFile.path}');

    try {
      // Create multipart request
      final request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      // Add the unsigned preset (this is what makes it unsigned - no API key/signature needed)
      request.fields['upload_preset'] = preset;

      // Add the image file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          imageFile.path,
        ),
      );

      debugPrint('📡 Sending upload request to Cloudinary...');

      // Send the request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final secureUrl = responseData['secure_url'] as String?;

        if (secureUrl != null) {
          debugPrint('✅ Image uploaded successfully: $secureUrl');
          return secureUrl;
        } else {
          debugPrint('❌ Response data: $responseData');
          throw Exception(
              'Upload failed: No secure_url in response. Response: ${response.body}');
        }
      } else {
        final errorBody = response.body;
        debugPrint('❌ Upload failed with status ${response.statusCode}');
        debugPrint('❌ Error response: $errorBody');

        // Try to parse error message
        try {
          final errorData = json.decode(errorBody) as Map<String, dynamic>;
          final errorMessage = errorData['error']?['message'] ?? errorBody;
          throw Exception(
              'Cloudinary upload failed (${response.statusCode}): $errorMessage');
        } catch (_) {
          throw Exception(
              'Cloudinary upload failed (${response.statusCode}): $errorBody');
        }
      }
    } catch (e) {
      debugPrint('❌ Error uploading image to Cloudinary: $e');
      debugPrint('❌ Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Upload multiple images to Cloudinary
  ///
  /// [imageFiles] - List of image files to upload
  /// Returns a list of secure URLs
  Future<List<String>> uploadImages(List<File> imageFiles) async {
    try {
      final List<String> urls = [];

      for (final imageFile in imageFiles) {
        final url = await uploadImage(imageFile);
        urls.add(url);
      }

      return urls;
    } catch (e) {
      debugPrint('❌ Error uploading images to Cloudinary: $e');
      rethrow;
    }
  }
}
