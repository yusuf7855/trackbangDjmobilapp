import 'package:flutter/material.dart';
import './url_constants.dart';

class ProfileInfoSection extends StatelessWidget {
  final Map<String, dynamic> userData;
  final int followerCount;
  final int followingCount;
  final int playlistCount;
  final bool isFollowing;
  final VoidCallback onFollowToggle;
  final bool isCurrentUser;

  const ProfileInfoSection({
    Key? key,
    required this.userData,
    required this.followerCount,
    required this.followingCount,
    required this.playlistCount,
    required this.isFollowing,
    required this.onFollowToggle,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: userData['profileImage'] != null &&
                    userData['profileImage'] != ''
                    ? NetworkImage(userData['profileImage'])
                    : const AssetImage('assets/default_profile.png') as ImageProvider,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${userData['firstName']} ${userData['lastName']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${userData['username']}',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildStatColumn(followerCount, "Followers"),
                        _buildStatColumn(followingCount, "Following"),
                        _buildStatColumn(playlistCount, "Playlists"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isCurrentUser) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onFollowToggle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isFollowing ? Colors.grey : Colors.indigo,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isFollowing ? "Unfollow" : "Follow",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatColumn(int count, String label) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}