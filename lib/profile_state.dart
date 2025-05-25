import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:io';

class ProfileState {
  // Ana state değişkenleri
  Map<String, dynamic>? userData;
  List<dynamic> playlists = [];
  bool isLoading = true;
  bool isFollowing = false;
  int followerCount = 0;
  int followingCount = 0;
  String? authToken;
  String? currentUserId;
  File? imageFile;
  bool isUpdatingImage = false;

  // Düzenleme modu için değişkenler
  bool isEditing = false;
  List<File> additionalImages = [];
  List<Map<String, dynamic>> currentAdditionalImages = [];

  // Tab kontrolü için
  int selectedTabIndex = 0;

  // Form kontrolcüleri
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  final TextEditingController linkNameController = TextEditingController();
  final TextEditingController linkUrlController = TextEditingController();

  // Etkinlik formu için
  List<Map<String, dynamic>> events = [];
  final TextEditingController eventCityController = TextEditingController();
  final TextEditingController eventVenueController = TextEditingController();
  final TextEditingController eventTimeController = TextEditingController();
  DateTime? selectedEventDate;

  // WebView management
  int? currentlyExpandedIndex;
  final Map<String, WebViewController> activeWebViews = {};

  void populateFormFields() {
    if (userData != null) {
      firstNameController.text = userData!['firstName'] ?? '';
      lastNameController.text = userData!['lastName'] ?? '';
      bioController.text = userData!['bio'] ?? '';

      if (userData!['profileLink'] != null) {
        linkNameController.text = userData!['profileLink']['name'] ?? '';
        linkUrlController.text = userData!['profileLink']['url'] ?? '';
      }

      if (userData!['events'] != null) {
        events = List<Map<String, dynamic>>.from(userData!['events']);
      }

      if (userData!['additionalImages'] != null) {
        currentAdditionalImages = List<Map<String, dynamic>>.from(
            userData!['additionalImages'].map((img) => {
              'filename': img['filename'],
              'url': '${getApiBaseUrl()}/uploads/${img['filename']}',
              'uploadDate': img['uploadDate']
            })
        );
      }
    }
  }

  String getApiBaseUrl() {
    // Bu fonksiyon url_constants.dart'tan gelecek
    return 'http://your-api-url'; // Placeholder
  }

  void addEvent() {
    if (selectedEventDate != null &&
        eventTimeController.text.isNotEmpty &&
        eventCityController.text.isNotEmpty &&
        eventVenueController.text.isNotEmpty) {
      events.add({
        'date': selectedEventDate!.toIso8601String(),
        'time': eventTimeController.text,
        'city': eventCityController.text,
        'venue': eventVenueController.text,
      });

      // Form alanlarını temizle
      eventTimeController.clear();
      eventCityController.clear();
      eventVenueController.clear();
      selectedEventDate = null;
    }
  }

  void removeEvent(int index) {
    if (index >= 0 && index < events.length) {
      events.removeAt(index);
    }
  }

  void removeAdditionalImage(String filename) {
    currentAdditionalImages.removeWhere((img) => img['filename'] == filename);
  }

  ImageProvider getProfileImage() {
    if (imageFile != null) {
      return FileImage(imageFile!);
    } else if (userData?['profileImage'] != null &&
        userData!['profileImage'].isNotEmpty &&
        userData!['profileImage'] != 'image.jpg') {
      return NetworkImage('${getApiBaseUrl()}/uploads/${userData!['profileImage']}');
    }
    return const AssetImage('assets/default_profile.png');
  }

  String getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  List<dynamic> parsePlaylistData(List<dynamic>? playlists) {
    return (playlists ?? []).map((playlist) {
      return {
        '_id': playlist['_id']?.toString(),
        'name': playlist['name']?.toString() ?? 'Untitled Playlist',
        'description': playlist['description']?.toString() ?? '',
        'musicCount': playlist['musicCount'] ?? 0,
        'musics': (playlist['musics'] as List<dynamic>?)?.map((music) {
          return {
            'title': music['title']?.toString(),
            'artist': music['artist']?.toString(),
            'spotifyId': music['spotifyId']?.toString(),
          };
        }).toList() ?? [],
      };
    }).toList();
  }

  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    bioController.dispose();
    linkNameController.dispose();
    linkUrlController.dispose();
    eventCityController.dispose();
    eventVenueController.dispose();
    eventTimeController.dispose();
  }
}