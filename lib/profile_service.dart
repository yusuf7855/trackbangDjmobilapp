import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'profile_state.dart';
import './url_constants.dart';

class ProfileService {
  final ProfileState _state;
  final bool Function() _isMounted;
  final ImagePicker _picker = ImagePicker();

  ProfileService(this._state, this._isMounted);

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isMounted()) {
      _state.authToken = prefs.getString('auth_token');
      _state.currentUserId = prefs.getString('user_id');
    }
  }

  Future<void> fetchCurrentUser() async {
    if (!_isMounted() || _state.authToken == null) return;

    _state.isLoading = true;

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/me'),
        headers: {'Authorization': 'Bearer ${_state.authToken}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isMounted()) {
          _state.userData = data;
          _state.currentUserId = data['_id'];
          _state.followerCount = data['followers']?.length ?? 0;
          _state.followingCount = data['following']?.length ?? 0;
          _state.isLoading = false;
          _state.isFollowing = data['followers']?.contains(_state.currentUserId) ?? false;
          _state.populateFormFields();
        }
        await fetchPlaylists();
      } else {
        _handleFetchError("Profile could not be loaded");
      }
    } catch (e) {
      _handleFetchError("An error occurred: $e");
    }
  }

  void _handleFetchError(String message) {
    if (_isMounted()) {
      _state.isLoading = false;
      // Burada snackbar gösterme işlemi için callback kullanılabilir
    }
  }

  Future<void> fetchPlaylists() async {
    if (_state.currentUserId == null || !_isMounted()) return;

    try {
      final response = await http.get(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/playlists/user/${_state.currentUserId}'),
        headers: {'Authorization': 'Bearer ${_state.authToken}'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (_isMounted() && data['success'] == true) {
          _state.playlists = _state.parsePlaylistData(data['playlists']);
        }
      }
    } catch (e) {
      // Hata yönetimi
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile == null || !_isMounted()) return;

      final file = File(pickedFile.path);
      _state.imageFile = file;

      await uploadProfileImage();
    } catch (e) {
      if (!_isMounted()) return;
      // Hata gösterme
    }
  }

  Future<void> pickAdditionalImages() async {
    try {
      final List<XFile>? pickedFiles = await _picker.pickMultiImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFiles == null || !_isMounted()) return;

      final totalImages = _state.currentAdditionalImages.length +
          _state.additionalImages.length +
          pickedFiles.length;
      if (totalImages > 3) {
        // Maksimum 3 resim hatası
        return;
      }

      _state.additionalImages.addAll(pickedFiles.map((file) => File(file.path)));
    } catch (e) {
      if (!_isMounted()) return;
      // Hata gösterme
    }
  }

  Future<void> uploadProfileImage() async {
    if (_state.imageFile == null || _state.authToken == null || !_isMounted()) return;

    _state.isUpdatingImage = true;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UrlConstants.apiBaseUrl}/api/upload-profile-image'),
      )..headers['Authorization'] = 'Bearer ${_state.authToken}'
        ..files.add(await http.MultipartFile.fromPath('profileImage', _state.imageFile!.path));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (!_isMounted()) return;

      if (response.statusCode == 200) {
        await fetchCurrentUser();
        // Başarı mesajı
      } else {
        // Hata mesajı
      }
    } catch (e) {
      if (!_isMounted()) return;
      // Sunucu hatası
    } finally {
      if (_isMounted()) {
        _state.isUpdatingImage = false;
      }
    }
  }

  Future<void> uploadAdditionalImages() async {
    if (_state.additionalImages.isEmpty || _state.authToken == null) return;

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${UrlConstants.apiBaseUrl}/api/upload-additional-images'),
      )..headers['Authorization'] = 'Bearer ${_state.authToken}';

      for (var image in _state.additionalImages) {
        request.files.add(await http.MultipartFile.fromPath('additionalImages', image.path));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        _state.additionalImages.clear();
        return;
      }
    } catch (e) {
      // Hata yönetimi
    }
  }

  Future<void> saveProfile() async {
    if (_state.authToken == null || !_isMounted()) return;

    try {
      _state.isLoading = true;

      if (_state.additionalImages.isNotEmpty) {
        await uploadAdditionalImages();
      }

      final response = await http.put(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_state.authToken}',
        },
        body: json.encode({
          'firstName': _state.firstNameController.text,
          'lastName': _state.lastNameController.text,
          'bio': _state.bioController.text,
          'profileLink': {
            'name': _state.linkNameController.text,
            'url': _state.linkUrlController.text,
          },
          'events': _state.events,
        }),
      );

      if (response.statusCode == 200 && _isMounted()) {
        _state.isEditing = false;
        await fetchCurrentUser();
        // Başarı mesajı
      } else {
        // Hata mesajı
      }
    } catch (e) {
      // Hata yönetimi
    } finally {
      if (_isMounted()) _state.isLoading = false;
    }
  }

  Future<void> deleteAdditionalImage(String filename) async {
    if (_state.authToken == null) return;

    try {
      final response = await http.delete(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/additional-image/$filename'),
        headers: {'Authorization': 'Bearer ${_state.authToken}'},
      );

      if (response.statusCode == 200) {
        _state.removeAdditionalImage(filename);
        // Başarı mesajı
      }
    } catch (e) {
      // Hata yönetimi
    }
  }

  Future<void> toggleFollow() async {
    if (_state.authToken == null || _state.userData == null || !_isMounted()) return;

    try {
      final endpoint = _state.isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('${UrlConstants.apiBaseUrl}/api/$endpoint/${_state.userData!['_id']}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_state.authToken}',
        },
      );

      if (response.statusCode == 200 && _isMounted()) {
        _state.isFollowing = !_state.isFollowing;
        _state.followerCount += _state.isFollowing ? 1 : -1;
        // Başarı mesajı
      }
    } catch (e) {
      // Hata yönetimi
    }
  }

  void cleanupPreviousWebViews(int currentIndex) {
    if (_state.currentlyExpandedIndex != null && _state.currentlyExpandedIndex != currentIndex) {
      final keysToRemove = _state.activeWebViews.keys
          .where((key) => key.startsWith('${_state.currentlyExpandedIndex}-'))
          .toList();
      for (var key in keysToRemove) {
        _state.activeWebViews.remove(key);
      }
    }
  }

  void cleanupWebViewsForIndex(int index) {
    final keysToRemove = _state.activeWebViews.keys
        .where((key) => key.startsWith('$index-'))
        .toList();
    for (var key in keysToRemove) {
      _state.activeWebViews.remove(key);
    }
  }
}