import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'account_actions_dialogs.dart';

class ProfileScreen extends StatelessWidget {
  final bool isManager = true; // يمكنك تغييرها بناءً على نوع المستخدم الحالي

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D), // اللون الداكن حسب الصورة
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // قسم رأس الصفحة (الصورة والاسم)
            Row(
              children: [
                Stack(
                  children: [
                    const CircleAvatar(
                      radius: 35,
                      backgroundImage: NetworkImage(
                        'https://via.placeholder.com/150',
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Alex Doe",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "alex.doe@example.com",
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),

            // الأقسام (General, Settings, Support)
            _buildSectionTitle("GENERAL"),
            _buildProfileItem(Icons.person_outline, "Edit Profile", () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(isManager: isManager),
                ),
              );
            }),
            _buildProfileItem(Icons.lock_outline, "Change Password", () {}),

            const SizedBox(height: 20),
            _buildSectionTitle("SETTINGS"),
            _buildProfileItem(
              Icons.notifications_none,
              "Notifications",
              () {},
              trailing: Switch(
                value: true,
                onChanged: (v) {},
                activeColor: Colors.blue,
              ),
            ),
            _buildProfileItem(Icons.dark_mode_outlined, "Appearance", () {}),

            const SizedBox(height: 20),
            _buildSectionTitle("SUPPORT"),
            _buildProfileItem(Icons.help_outline, "Help & Support", () {}),
            _buildProfileItem(
              Icons.privacy_tip_outlined,
              "Privacy Policy",
              () {},
            ),

            const SizedBox(height: 20),
            _buildSectionTitle("ACCOUNT MANAGEMENT"),
            _buildProfileItem(Icons.delete_outline, "Delete Account", () {
              AccountActionsDialogs.showDeleteAccountDialog(context);
            }, textColor: Colors.red),

            const SizedBox(height: 30),
            // زر الخروج الأحمر في الأسفل
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFF1E161E),
                  padding: const EdgeInsets.all(15),
                ),
                onPressed: () =>
                    AccountActionsDialogs.showLogoutDialog(context),
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text(
                  "Logout",
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildProfileItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color textColor = Colors.white,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E212A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor == Colors.red ? Colors.red : Colors.grey,
        ),
        title: Text(title, style: TextStyle(color: textColor, fontSize: 15)),
        trailing:
            trailing ??
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
