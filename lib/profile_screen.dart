import 'package:flutter/material.dart';
import 'edit_profile_screen.dart';
import 'contractor_edit_account_screen.dart';
import 'account_actions_dialogs.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================
  // جيب بيانات المستخدم من Supabase
  // ============================================
  Future<void> _loadProfile() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      final data = await supabase
          .from('User')
          .select('username, email')
          .eq('id', userId)
          .single();

      setState(() {
        _username = data['username'] ?? 'User';
        _email = data['email'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // تسجيل الخروج
  // ============================================
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
                  // Header — بيانات حقيقية من Supabase
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 35,
                        backgroundColor: Color(0xFF3395FF),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 35,
                        ),
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
                          builder: (_) =>
                              const EditProfileScreen(isManager: true),
                        ),
                      );
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
                    () {},
                  ),

                  const SizedBox(height: 20),
                  _buildSectionTitle("SETTINGS"),
                  _buildProfileItem(
                    Icons.notifications_none,
                    "Notifications",
                    () {},
                    trailing: Switch(
                      value: true,
                      onChanged: (v) {},
                      activeThumbColor: Colors.blue,
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
                      // ← تسجيل الخروج الحقيقي
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
