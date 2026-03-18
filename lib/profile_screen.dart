import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'contractor_edit_account_screen.dart';
import 'account_actions_dialogs.dart';
import 'change_password_screen.dart';
import 'login_screen.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  final bool isManager;
  const ProfileScreen({super.key, required this.isManager});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _username = '';
  String _email = '';
  String? _photoUrl;
  bool _isLoading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('User')
          .select('username, email, photoUrl, notificationsEnabled')
          .eq('id', userId)
          .single();
      setState(() {
        _username = data['username'] ?? 'User';
        _email = data['email'] ?? '';
        _photoUrl = data['photoUrl'];
        _notificationsEnabled = data['notificationsEnabled'] ?? true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12141D),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: const Text("Profile", style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 35,
                        backgroundColor: const Color(0xFF3395FF),
                        backgroundImage: _photoUrl != null
                            ? NetworkImage(_photoUrl!) as ImageProvider
                            : null,
                        child: _photoUrl == null
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 35,
                              )
                            : null,
                      ),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _username,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _email,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle("GENERAL"),
                  _buildProfileItem(Icons.person_outline, "Edit Profile", () {
                    if (widget.isManager) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            isManager: true,
                            initialName: _username,
                            initialEmail: _email,
                            initialContact: '',
                            initialCompany: '',
                          ),
                        ),
                      ).then((_) => _loadProfile());
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ContractorEditAccountScreen(),
                        ),
                      );
                    }
                  }),

                  _buildProfileItem(
                    Icons.lock_outline,
                    "Change Password",
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordScreen(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle("SETTINGS"),
                  _buildProfileItem(
                    Icons.notifications_none,
                    "Notifications",
                    () {},
                    trailing: Switch(
                      value: _notificationsEnabled,
                      activeThumbColor: Colors.blue,
                      onChanged: (v) async {
                        setState(() => _notificationsEnabled = v);
                        final userId = supabase.auth.currentUser?.id;
                        if (userId != null) {
                          await supabase
                              .from('User')
                              .update({'notificationsEnabled': v})
                              .eq('id', userId);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle("ACCOUNT MANAGEMENT"),
                  _buildProfileItem(Icons.delete_outline, "Delete Account", () {
                    AccountActionsDialogs.showDeleteAccountDialog(context);
                  }, textColor: Colors.red),

                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF1E161E),
                        padding: const EdgeInsets.all(15),
                      ),
                      onPressed: () => AccountActionsDialogs.showLogoutDialog(
                        context,
                        onConfirm: _logout,
                      ),
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
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
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

  Widget _buildProfileItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color textColor = Colors.white,
    Widget? trailing,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1E212A),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: textColor == Colors.red ? Colors.red : Colors.grey,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: textColor, fontSize: 15),
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
            ],
          ),
        ),
      ),
    ),
  );
}
