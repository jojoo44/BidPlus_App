// account_actions_dialogs.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../main.dart';

class AccountActionsDialogs {
  static void showLogoutDialog(
    BuildContext context, {
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.logout, color: Colors.blue, size: 40),
            const SizedBox(height: 20),
            const Text(
              "Confirm Logout",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Are you sure you want to log out of your account?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (onConfirm != null) {
                  onConfirm();
                } else {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
              child: const Text(
                "Logout",
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ dialog منفصل بـ context صحيح
  static void _showHasActiveItemsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D27),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, color: Colors.orange, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Cannot Delete Account",
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "You have active projects or negotiations. Please complete or close them before deleting your account.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                minimumSize: const Size(double.infinity, 48),
              ),
              // ✅ يستخدم dialogContext الصحيح
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("OK", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  static void showDeleteAccountDialog(BuildContext context) {
    final confirmController = TextEditingController();
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1D27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 40,
                ),
                const SizedBox(height: 20),
                const Text(
                  "Are you sure?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "All project data will be permanently deleted. This action cannot be undone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Type "DELETE" to confirm',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: confirmController,
                  decoration: InputDecoration(
                    hintText: "DELETE",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: const Color(0xFF12141D),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3243),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          if (confirmController.text.trim() != 'DELETE') {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please type DELETE to confirm'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          setDialogState(() => isDeleting = true);
                          try {
                            final userId = supabase.auth.currentUser?.id;
                            if (userId == null) throw Exception('User not found');

                            // ✅ مانجر: شيك RFP Active
                            final activeRFPs = await supabase
                                .from('RFP')
                                .select('rfpID')
                                .eq('creatorUser', userId)
                                .eq('status', 'Active');

                            // ✅ مانجر: شيك NegoRounds
                            final activeNegoManager = await supabase
                                .from('NegoRounds')
                                .select('roundID')
                                .eq('manager_id', userId);

                            // ✅ كونتراكتور: شيك NegoSession Active
                            final activeNegoContractor = await supabase
                                .from('NegoSession')
                                .select('session_id')
                                .eq('contractor_id', userId)
                                .eq('status', 'Active');

                            // ✅ كونتراكتور: شيك proposals بحالات نشطة
                            final activeProposals = await supabase
                                .from('proposals')
                                .select('ProposalID')
                                .eq('submitterUserId', userId)
                                .inFilter('status', [
                                  'Submitted',
                                  'Under Review',
                                  'Accepted',
                                ]);

                            final bool hasActive =
                                (activeRFPs as List).isNotEmpty ||
                                (activeNegoManager as List).isNotEmpty ||
                                (activeNegoContractor as List).isNotEmpty ||
                                (activeProposals as List).isNotEmpty;

                            if (hasActive) {
                              setDialogState(() => isDeleting = false);
                              if (context.mounted) {
                                Navigator.pop(context);
                                // ✅ يمرر context الخارجي الصحيح
                                _showHasActiveItemsDialog(context);
                              }
                              return;
                            }

                            await supabase.rpc('delete_user');
                            await supabase.auth.signOut();

                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            setDialogState(() => isDeleting = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const CircularProgressIndicator(color: Colors.red)
                      : const Text(
                          "Delete Account",
                          style: TextStyle(color: Colors.red),
                        ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}