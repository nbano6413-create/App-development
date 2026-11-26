
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:material_ui/material_ui.dart';

import '../data/tools_data.dart';
import '../models/pdf_tool.dart';
import '../providers/app_state.dart';
import '../services/ad_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tool_card.dart';
import 'settings_screen.dart';
import 'tool_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState appState;

  const HomeScreen({
    super.key,
    required this.appState,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController =
  TextEditingController();

  int _currentBottomNavIndex = 0;

  BannerAd? _bannerAd;
  bool _isBannerAdLoaded = false;

  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
    _loadNativeAd();
  }

  // TEMPORARY: Open Google Mobile Ads Ad Inspector
  Future<void> _openAdInspector() async {
    try {
      MobileAds.instance.openAdInspector((error) {
        if (error != null) {
          debugPrint('Ad Inspector Error: ${error.message}');
        } else {
          debugPrint('Ad Inspector closed successfully');
        }
      });
    } catch (e) {
      debugPrint('Unable to open Ad Inspector: $e');
    }
  }

  // Load Banner Ad
  void _loadBannerAd() {
    if (AdService.instance.isPremium) return;

    _bannerAd = AdService.instance.createHomeBannerAd(
      onAdLoaded: () {
        if (!mounted) return;

        setState(() {
          _isBannerAdLoaded = true;
        });
      },
    );
  }

  // Load Native Ad
  void _loadNativeAd() {
    if (AdService.instance.isPremium) return;

    _nativeAd = NativeAd(
      adUnitId: AdService.nativeAdUnitId,
      factoryId: 'listTile',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _isNativeAdLoaded = true;
          });

          debugPrint('Native Ad Loaded Successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (mounted) {
            setState(() {
              _nativeAd = null;
              _isNativeAdLoaded = false;
            });
          }

          debugPrint('Native Ad failed to load: $error');
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerAd?.dispose();
    _nativeAd?.dispose();
    super.dispose();
  }

  void _navigateToTool(PdfTool tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolDetailScreen(
          tool: tool,
          appState: widget.appState,
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          appState: widget.appState,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        child: IndexedStack(
          index: _currentBottomNavIndex,
          children: [
            _buildHomeTab(isDark),
            _buildHistoryTab(isDark),
            _buildPremiumTab(isDark),
            _buildMoreTab(isDark),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          boxShadow: AppTheme.cardShadow,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentBottomNavIndex,
          onTap: (index) {
            setState(() {
              _currentBottomNavIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.primaryPurple,
          unselectedItemColor:
          isDark ? AppTheme.textSecondaryDark : Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'History',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.workspace_premium_rounded),
              label: 'Premium',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_rounded),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(bool isDark) {
    final searchQuery =
    widget.appState.searchQuery.trim().toLowerCase();

    final filteredTools = searchQuery.isEmpty
        ? ToolsData.allTools
        : ToolsData.allTools.where((t) {
      return t.name.toLowerCase().contains(searchQuery) ||
          t.description.toLowerCase().contains(searchQuery);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDark),
          const SizedBox(height: 12),

          // TEMPORARY Ad Inspector button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _openAdInspector,
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Ad Inspector'),
            ),
          ),

          const SizedBox(height: 8),
          _buildSearchBar(isDark),
          const SizedBox(height: 20),

          if (searchQuery.isNotEmpty) ...[
            Text(
              'Search Results (${filteredTools.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            if (filteredTools.isEmpty)
              SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 60,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No PDF tools found matching "${widget.appState.searchQuery}"',
                        style: TextStyle(
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: filteredTools.length,
                itemBuilder: (context, index) {
                  return ToolCard(
                    tool: filteredTools[index],
                    onTap: () =>
                        _navigateToTool(filteredTools[index]),
                  );
                },
              ),
          ] else ...[
            _buildPremiumBanner(isDark),
            const SizedBox(height: 24),

            _buildCategorySection(
              category: ToolCategory.popular,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            _buildCategorySection(
              category: ToolCategory.conversion,
              isDark: isDark,
            ),
            const SizedBox(height: 24),

            _buildCategorySection(
              category: ToolCategory.security,
              isDark: isDark,
            ),

            if (_isNativeAdLoaded && _nativeAd != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppTheme.darkSurface
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppTheme.cardShadow,
                  border: Border.all(
                    color: AppTheme.primaryPurple.withValues(
                      alpha: 0.3,
                    ),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            'Sponsored',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                            AppTheme.primaryPurple.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Ad',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 250,
                      child: AdWidget(ad: _nativeAd!),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            _buildCategorySection(
              category: ToolCategory.optimization,
              isDark: isDark,
            ),
          ],

          if (_isBannerAdLoaded && _bannerAd != null) ...[
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                width: _bannerAd!.size.width.toDouble(),
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
          ],

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Docverter: PDF\nConverter',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Convert and Manage PDFs Easily',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : const Color(0xFF4A4B57),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Fast • Secure • Smart PDF Tools',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryPurple,
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            IconButton(
              onPressed: _navigateToSettings,
              icon: const Icon(
                Icons.settings_rounded,
                size: 28,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppTheme.cardShadow,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/images/app_logo.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppTheme.cardShadow,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          widget.appState.setSearchQuery(val);
        },
        decoration: InputDecoration(
          hintText: 'Search PDF Tools...',
          hintStyle: TextStyle(
            color: isDark
                ? AppTheme.textSecondaryDark
                : Colors.grey.shade400,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 10),
            child: Icon(
              Icons.search_rounded,
              color: AppTheme.primaryPurple,
              size: 26,
            ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 20,
          ),
          suffixIcon: widget.appState.searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(
              Icons.clear_rounded,
              color: Colors.grey,
            ),
            onPressed: () {
              _searchController.clear();
              widget.appState.setSearchQuery('');
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryPurple,
            AppTheme.primaryPurple.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppTheme.buttonShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Upgrade to Premium',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Unlimited PDF conversions & zero ads.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection({
    required ToolCategory category,
    required bool isDark,
  }) {
    final tools = ToolsData.allTools
        .where((t) => t.category == category)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryPurple,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  category.title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                _showAllCategoryToolsBottomSheet(category);
              },
              child: const Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: AppTheme.primaryPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.primaryPurple,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 14,
            childAspectRatio: 0.82,
          ),
          itemCount: tools.length,
          itemBuilder: (context, index) {
            return ToolCard(
              tool: tools[index],
              onTap: () => _navigateToTool(tools[index]),
            );
          },
        ),
      ],
    );
  }

  void _showAllCategoryToolsBottomSheet(ToolCategory category) {
    final categoryTools = ToolsData.allTools
        .where((t) => t.category == category)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark =
            Theme.of(ctx).brightness == Brightness.dark;

        return Container(
          height: MediaQuery.of(ctx).size.height * 0.65,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurface
                : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                category.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: categoryTools.length,
                  itemBuilder: (context, index) {
                    return ToolCard(
                      tool: categoryTools[index],
                      onTap: () {
                        Navigator.pop(ctx);
                        _navigateToTool(categoryTools[index]);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // History Tab
  Widget _buildHistoryTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Conversion History',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Saved output documents in Downloads',
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : Colors.grey,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All converted files are automatically saved directly into your device Downloads folder.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Premium Tab
  Widget _buildPremiumTab(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTheme.primaryPurple,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'My Docverter Premium',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unlock fast offline PDF tools, batch conversions, and ad-free experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'You already have full offline access!',
                  ),
                ),
              );
            },
            child: const Text('GET PREMIUM ACCESS'),
          ),
        ],
      ),
    );
  }

  // More / Settings Tab
  Widget _buildMoreTab(bool isDark) {
    return SettingsScreen(appState: widget.appState);
  }
}
