// lib/screens/user_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_ce/hive.dart';
import 'login_screen.dart';
import '../providers/auth_provider.dart';
import 'package:hipster_videocallingapp/screens/video_callscreen.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/user_provider.dart';

class UserListScreen extends ConsumerStatefulWidget {
  const UserListScreen({super.key});

  @override
  ConsumerState<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends ConsumerState<UserListScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(userProvider);
    final searchQuery = _searchController.text.toLowerCase();

    return Scaffold(
      // SIDE NAVIGATION DRAWER
      drawer: _buildDrawer(context),

      appBar: AppBar(
        title: const Text(
          'Hipster',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 6,
        centerTitle: true,
        actions: [
          // Join call button
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () => _showJoinCallDialog(context),
            tooltip: 'Join Call',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(userProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // SEARCH BAR
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),

          // USER LIST
          Expanded(
            child: usersAsync.when(
              loading: () => _buildShimmerList(),
              error: (err, stack) => _buildErrorWidget(err),
              data: (users) {
                final filtered = users.where((user) {
                  final name = '${user['first_name']} ${user['last_name']}'.toLowerCase();
                  return name.contains(searchQuery);
                }).toList();

                if (filtered.isEmpty && searchQuery.isNotEmpty) {
                  return const Center(
                    child: Text('No users found', style: TextStyle(fontSize: 16)),
                  );
                }

                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return _buildUserCard(user, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // DRAWER BUILDER
  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // DRAWER HEADER
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.deepPurple, Colors.purpleAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.deepPurple),
                ),
                SizedBox(height: 12),
                Text(
                  'Hipster Video App',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Welcome back!',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          // NAVIGATION ITEMS
          ListTile(
            leading: const Icon(Icons.home, color: Colors.deepPurple),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              //  Navigate to home if needed
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: Colors.deepPurple),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              //  Navigate to profile screen
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.deepPurple),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              // Close drawer first
              Navigator.pop(context);
              // Use AuthProvider to logout and reset state
              try {
                await ref.read(authProvider.notifier).logout();
              } catch (_) {
                // fallback: clear persisted flag directly
                try {
                  await Hive.box('auth').put('isLoggedIn', false);
                } catch (_) {}
              }
              // Navigate to login and remove all other routes
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, _controller.value * 60, 0),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Use the fixed test channel name for reproducible testing
            const channelId = 'TestingApp';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoCallScreen(channelId: channelId),
              ),
            );

            // Show channel ID so user knows which room was used
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Starting call in room: TestingApp'),
                duration: Duration(seconds: 3),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // AVATAR
                Hero(
                  tag: 'user_${user['id']}',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(50),
                    child: CachedNetworkImage(
                      imageUrl: user['avatar'],
                      width: 62,
                      height: 62,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        child: Container(color: Colors.white),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.person, size: 32, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // NAME + EMAIL
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${user['first_name']} ${user['last_name']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'],
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),

                // CALL ICON
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Colors.deepPurple,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: const SizedBox(height: 84),
        ),
      ),
    );
  }

  // Show dialog to join a call by channel ID
  Future<void> _showJoinCallDialog(BuildContext context) async {
    final channelController = TextEditingController();
    bool isHovered = false;
    
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (context) => Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.2),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with Icon
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.deepPurple, Colors.deepPurple.shade300],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: const Icon(
                      Icons.video_call_rounded,
                      size: 64,
                      color: Colors.white,
                    ).animate(onPlay: (controller) => controller.repeat())
                      .shimmer(duration: 2000.ms, color: Colors.white30)
                      .animate() // Add a one-time animation
                      .scale(duration: 400.ms, curve: Curves.easeOutBack),
                  ).animate().fadeIn().slideY(begin: -0.2),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: const Text(
                      'Join Video Call',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ).animate().fadeIn(delay: 200.ms).slideX(),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: const Text(
                      'Enter the channel ID shared by the other person',
                      style: TextStyle(color: Colors.black54),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms).slideX(),
                  ),

                  // Channel ID Input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: StatefulBuilder(
                      builder: (context, setState) => TextField(
                        controller: channelController,
                        style: const TextStyle(
                          fontSize: 18,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX',
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          prefixIcon: const Icon(
                            Icons.key_rounded,
                            color: Colors.deepPurple,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.deepPurple,
                              width: 2,
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideX(),
                    ),
                  ),

                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StatefulBuilder(
                            builder: (context, setState) => MouseRegion(
                              onEnter: (_) => setState(() => isHovered = true),
                              onExit: (_) => setState(() => isHovered = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                transform: Matrix4.identity()
                                  ..scale(isHovered ? 1.02 : 1.0),
                                child: ElevatedButton(
                                  onPressed: () {
                                    final channelId = channelController.text.trim();
                                    if (channelId.isNotEmpty) {
                                      Navigator.pop(context);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VideoCallScreen(
                                            channelId: channelId,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: isHovered ? 8 : 4,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'Join Call',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
                  ),
                ],
              ),
            ),
          ).animate().scale(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Offline Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Using cached data', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(userProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
          ),
        ],
      ),
    );
  }
}