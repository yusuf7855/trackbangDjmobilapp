import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'profile_state.dart';
import 'profile_service.dart';

class ProfileWidgets {
  final ProfileState profileState;
  final ProfileService profileService;
  late BuildContext context;
  final VoidCallback onStateChanged;

  ProfileWidgets({
    required this.profileState,
    required this.profileService,
    required this.context,
    required this.onStateChanged,
  });

  void updateContext(BuildContext newContext) {
    context = newContext;
  }

  Widget buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
            SizedBox(height: 20),
            Text(
              "Profil yükleniyor...",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[800]!, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.person_off,
                color: Colors.grey[600],
                size: 64,
              ),
              const SizedBox(height: 20),
              const Text(
                "Kullanıcı bulunamadı",
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Bu profil mevcut değil",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  icon: const Icon(Icons.login, color: Colors.black),
                  label: const Text(
                    "Giriş Yap",
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildProfileCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 20),
          _buildUserInfoSection(),
          if (profileState.userData?['bio'] != null && profileState.userData!['bio'].isNotEmpty)
            _buildBioSection(),
          if (profileState.userData?['profileLink'] != null &&
              profileState.userData!['profileLink']['url'] != null &&
              profileState.userData!['profileLink']['url'].isNotEmpty)
            _buildLinkSection(),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 20),
          if (profileState.currentUserId != profileState.userData?['_id'])
            _buildFollowButton()
          else
            _buildEditButton(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundImage: profileState.getProfileImage(),
          ),
        ),
        if (profileState.currentUserId == profileState.userData?['_id'] && !profileState.isEditing)
          _buildCameraButton(),
      ],
    );
  }

  Widget _buildCameraButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: IconButton(
        icon: profileState.isUpdatingImage
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            strokeWidth: 2,
          ),
        )
            : const Icon(Icons.camera_alt, size: 20),
        onPressed: profileState.isUpdatingImage ? null : () async {
          await profileService.pickImage();
          onStateChanged();
        },
        color: Colors.black,
      ),
    );
  }

  Widget _buildUserInfoSection() {
    if (profileState.isEditing) {
      return Column(
        children: [
          _buildModernTextField(profileState.firstNameController, 'Ad', Icons.person),
          const SizedBox(height: 16),
          _buildModernTextField(profileState.lastNameController, 'Soyad', Icons.person_outline),
        ],
      );
    }

    return Column(
      children: [
        Text(
          '${profileState.userData?['firstName']} ${profileState.userData?['lastName']}',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[600]!),
          ),
          child: Text(
            '@${profileState.userData?['username']}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: Colors.white70),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildBioSection() {
    if (profileState.isEditing) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: TextField(
            controller: profileState.bioController,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio',
              labelStyle: TextStyle(color: Colors.grey[400]),
              prefixIcon: const Icon(Icons.info_outline, color: Colors.white70),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Text(
          profileState.userData!['bio'],
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // Sadece _buildLinkSection metodunu değiştir - diğer kodlara dokunma
  Widget _buildLinkSection() {
    if (profileState.isEditing) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          children: [
            _buildModernTextField(profileState.linkNameController, 'Link Adı', Icons.link),
            const SizedBox(height: 16),
            _buildModernTextField(profileState.linkUrlController, 'URL', Icons.language),
          ],
        ),
      );
    }

    // Çoklu linkler için - profileLinks listesini kontrol et
    final profileLinks = profileState.userData?['profileLinks'] as List<dynamic>? ?? [];

    if (profileLinks.isEmpty) {
      // Eski tek link sistemi
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: InkWell(
          onTap: () {
            // URL'yi açma işlemi
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[400]!, width: 0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, color: Colors.black87, size: 11),
                const SizedBox(width: 3),
                Text(
                  profileState.userData!['profileLink']['name'],
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Çoklu linkler - yan yana chip'ler
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: profileLinks.map((link) => InkWell(
          onTap: () {
            // URL'yi açma işlemi
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[400]!, width: 0.3),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link, color: Colors.black87, size: 10),
                const SizedBox(width: 2),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 60),
                  child: Text(
                    link['title'] ?? 'Link',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatColumn(profileState.followerCount, "Takipçi"),
        _buildStatColumn(profileState.followingCount, "Takip"),
        _buildStatColumn(profileState.playlists.length, "Bangs"),
      ],
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildEditButton() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: profileState.isEditing ? Colors.grey[700] : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: ElevatedButton(
              onPressed: () {
                profileState.isEditing = !profileState.isEditing;
                onStateChanged();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                profileState.isEditing ? "İptal" : "Profili Düzenle",
                style: TextStyle(
                  fontSize: 16,
                  color: profileState.isEditing ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        if (profileState.isEditing) ...[
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  await profileService.saveProfile();
                  onStateChanged();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Kaydet",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFollowButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: profileState.isFollowing ? Colors.grey[700] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[600]!),
      ),
      child: ElevatedButton(
        onPressed: () async {
          await profileService.toggleFollow();
          onStateChanged();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          profileState.isFollowing ? "Takibi Bırak" : "Takip Et",
          style: TextStyle(
            fontSize: 16,
            color: profileState.isFollowing ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget buildTabBar(TabController tabController) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: TabBar(
        controller: tabController,
        tabs: const [
          Tab(
            icon: Icon(Icons.event),
            text: "Etkinlikler",
          ),
          Tab(
            icon: Icon(Icons.library_music),
            text: "Playlists",
          ),
        ],
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.grey[400],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget buildEventsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (profileState.isEditing) _buildEventForm(),
        const SizedBox(height: 16),
        if (profileState.events.isNotEmpty) ...[
          ...profileState.events.asMap().entries.map((entry) {
            final index = entry.key;
            final event = entry.value;
            final eventDate = DateTime.parse(event['date']);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!, width: 1),
              ),
              child: Row(
                children: [
                  // Sol taraf - Takvim
                  Container(
                    width: 70,
                    height: 70,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          profileState.getMonthName(eventDate.month),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          eventDate.day.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sağ taraf - Etkinlik detayları
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event['city'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                event['time'],
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: Colors.grey[400],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  event['venue'],
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Silme butonu veya artı butonu
                  if (profileState.isEditing)
                    IconButton(
                      onPressed: () {
                        profileState.removeEvent(index);
                        onStateChanged();
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      padding: const EdgeInsets.all(16),
                    )
                  else
                    Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[600]!),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // Etkinlik detaylarını göster veya takvime ekle
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!, width: 1),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.event_busy,
                  color: Colors.grey[600],
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  "Henüz etkinlik eklenmemiş",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEventForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_box, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                "Yeni Etkinlik Ekle",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _selectEventDate,
                    icon: const Icon(Icons.calendar_today, color: Colors.black),
                    label: Text(
                      profileState.selectedEventDate == null
                          ? "Tarih Seç"
                          : "${profileState.selectedEventDate!.day}/${profileState.selectedEventDate!.month}/${profileState.selectedEventDate!.year}",
                      style: const TextStyle(color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[700]!),
                  ),
                  child: TextField(
                    controller: profileState.eventTimeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Saat',
                      labelStyle: TextStyle(color: Colors.grey),
                      suffixIcon: Icon(Icons.access_time, color: Colors.white70),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onTap: _selectEventTime,
                    readOnly: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: TextField(
              controller: profileState.eventCityController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'İl',
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.location_city, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: TextField(
              controller: profileState.eventVenueController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Mekan',
                labelStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.place, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                profileState.addEvent();
                onStateChanged();
                _showSnackbar("Etkinlik eklendi", Colors.green);
              },
              icon: const Icon(Icons.add, color: Colors.black),
              label: const Text(
                "Etkinlik Ekle",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectEventDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      profileState.selectedEventDate = picked;
      onStateChanged();
    }
  }

  Future<void> _selectEventTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.white,
              onPrimary: Colors.black,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      profileState.eventTimeController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
      onStateChanged();
    }
  }

  Widget buildAdditionalImagesSection() {
    if (!profileState.isEditing &&
        profileState.currentAdditionalImages.isEmpty &&
        profileState.additionalImages.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildImageSlot(0),
              const SizedBox(width: 12),
              _buildImageSlot(1),
              const SizedBox(width: 12),
              _buildImageSlot(2),
            ],
          ),
          if (profileState.isEditing) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ElevatedButton.icon(
                onPressed: () async {
                  await profileService.pickAdditionalImages();
                  onStateChanged();
                },
                icon: const Icon(Icons.add_photo_alternate, color: Colors.black),
                label: const Text(
                  "Resim Ekle",
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImageSlot(int index) {
    final allImages = [
      ...profileState.currentAdditionalImages,
      ...profileState.additionalImages.map((file) => {'file': file})
    ];

    if (index < allImages.length) {
      final imageData = allImages[index];

      return Expanded(
        child: Stack(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: imageData.containsKey('file')
                    ? Image.file(
                  imageData['file'] as File,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                )
                    : Image.network(
                  imageData['url'] as String,
                  width: double.infinity,
                  height: 100,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (profileState.isEditing)
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () async {
                    if (imageData.containsKey('file')) {
                      profileState.additionalImages.removeWhere((file) => file == imageData['file']);
                    } else {
                      await profileService.deleteAdditionalImage(imageData['filename'] as String);
                    }
                    onStateChanged();
                  },
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Expanded(
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[700]!, width: 1),
        ),
        child: Center(
          child: Icon(
            Icons.add_photo_alternate,
            color: Colors.grey[600],
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget buildEmptyPlaylistMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[800]!, width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.library_music_outlined,
            color: Colors.grey[600],
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            "Henüz playlist oluşturulmamış",
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
                color == Colors.red ? Icons.error_outline : Icons.check_circle_outline,
                color: Colors.white
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: CupertinoColors.inactiveGray,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}