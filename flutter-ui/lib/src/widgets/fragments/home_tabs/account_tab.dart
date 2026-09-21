import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../screens/balances_screen.dart';
import '../../typography.dart';
import '../../../constants/app_strings.dart';
import '../../settings_section_card.dart';
import '../../settings_list_item.dart';
import '../../../providers/amplify_provider.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  final _joinFamilyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Trigger user info fetch when the tab is first loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserInfo();
    });
  }

  @override
  void dispose() {
    _joinFamilyController.dispose();
    super.dispose();
  }

  void _loadUserInfo() {
    final amplifyProvider = context.read<AmplifyProvider>();
    amplifyProvider.fetchUserInfo().catchError((error) {
      // Handle sign-out case
      if (error.toString().contains('SignedOut') ||
          error.toString().contains('No user is currently signed in')) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
      return <String, dynamic>{}; // Return empty map to satisfy return type
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AmplifyProvider>(
      builder: (context, amplifyProvider, child) {
        final cachedUserInfo = amplifyProvider.cachedUserInfo;
        final isFetching = amplifyProvider.isFetchingUserInfo;

        // Show cached data immediately if available
        if (cachedUserInfo != null) {
          final name = cachedUserInfo['name'] as String;
          final email = cachedUserInfo['email'] as String;

          return _buildAccountContent(context, name, email);
        }

        // Show loading if currently fetching
        if (isFetching) {
          return const Center(child: CircularProgressIndicator());
        }

        // If no data and not fetching, show retry option
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Tap to load your account information'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  // Use addPostFrameCallback to avoid calling during build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _loadUserInfo();
                  });
                },
                child: const Text('Load Account Info'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAccountContent(BuildContext context, String name, String email) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HeadlineEmphasizedLarge(text: AppStrings.accountTitle),

          // User Profile Section
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.person,
                      size: 28,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.email,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        email,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Financial Information Section
          SettingsSectionCard(
            children: [
              SettingsListItem(
                leadingIcon: Icons.account_balance,
                title: 'View Balances',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BalancesScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // // Family Section
          // SettingsSectionCard(
          //   children: [
          //     SettingsListItem(
          //       leadingIcon: Icons.family_restroom,
          //       title: 'Join Family',
          //       onTap: () {
          //         _showJoinFamilyDialog(context);
          //       },
          //     ),
          //   ],
          // ),

          // Account Actions Section
          SettingsSectionCard(
            children: [
              SettingsListItem(
                leadingIcon: Icons.logout,
                title: 'Sign Out',
                onTap: () {
                  _signOut(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showJoinFamilyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Join Family'),
          content: TextField(
            controller: _joinFamilyController,
            decoration: const InputDecoration(
              labelText: 'Family Code',
              hintText: 'Enter family code',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _joinFamilyController.clear();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement family joining logic
                Navigator.of(context).pop();
                _joinFamilyController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Family joining feature coming soon!'),
                  ),
                );
              },
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  void _signOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();

                try {
                  // Use a small delay to ensure dialog closes properly
                  await Future.delayed(const Duration(milliseconds: 100));

                  if (!mounted) return;

                  // Perform sign out
                  await context.read<AmplifyProvider>().signOut();

                  // Use addPostFrameCallback to ensure navigation happens in next frame
                  if (mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    });
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Sign out failed: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }
}
