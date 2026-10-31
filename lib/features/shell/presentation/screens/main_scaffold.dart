import 'package:flutter/material.dart';
import 'package:dailyle/features/practice/presentation/screens/topic_list_screen.dart';
import 'package:dailyle/features/statistics/presentation/screens/statistics_dashboard_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  void _navigateToPhonemePractice(String phoneme) {
    setState(() => _selectedIndex = 0); // Switch to Practice Tab
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đang hiển thị các bài học cho âm vị /$phoneme/'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth >= 600; // Web & Desktop breakpoint

    final screens = [
      const TopicListScreen(),
      StatisticsDashboardScreen(
        onNavigateToPhonemePractice: _navigateToPhonemePractice,
      ),
    ];

    if (isWideScreen) {
      // Web & Desktop layout with NavigationRail
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🔥', style: TextStyle(fontSize: 24)),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Dailyle',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.record_voice_over_outlined),
                  selectedIcon: Icon(Icons.record_voice_over_rounded),
                  label: Text('Luyện tập'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded),
                  label: Text('Kỷ luật & Thống kê'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: screens[_selectedIndex],
            ),
          ],
        ),
      );
    }

    // Android & Mobile layout with Bottom NavigationBar
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.record_voice_over_outlined),
            selectedIcon: Icon(Icons.record_voice_over_rounded),
            label: 'Luyện tập',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Kỷ luật & Thống kê',
          ),
        ],
      ),
    );
  }
}
