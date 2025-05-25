import 'package:flutter/material.dart';
import 'package:flutter_project/services/product_service.dart';
import 'package:flutter_project/views/all_product_page.dart';
import 'package:flutter_project/views/cart_page.dart';
import 'package:flutter_project/views/profile_page.dart';
import 'package:flutter_project/views/search_page.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  int _selectedCategoryIndex = 0;

  final List<String> categories = ['Women', 'Men', 'Accessories', 'Beauty'];
  final List<int> categoryIds = [1, 2, 3, 4];

  List<dynamic> featuredProducts = [];
  List<dynamic> recommendedProducts = [];
  List<dynamic> topCollectionProducts = [];
  List<dynamic> allProducts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  void _fetchAllData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      print('Starting to fetch data...');
      
      // Fetch products from the selected category first
      final selectedCategoryProducts = await ProductService.fetchProductsByCategory(categoryIds[_selectedCategoryIndex]);
      print('Fetched ${selectedCategoryProducts.length} products from category ${categoryIds[_selectedCategoryIndex]}');
      
      // Try to fetch from other categories, but don't fail if some don't work
      List<dynamic> otherProducts = [];
      try {
        final category2Products = await ProductService.fetchProductsByCategory(2);
        otherProducts.addAll(category2Products);
        print('Fetched ${category2Products.length} products from category 2');
      } catch (e) {
        print('Failed to fetch from category 2: $e');
      }

      try {
        final category3Products = await ProductService.fetchProductsByCategory(3);
        otherProducts.addAll(category3Products);
        print('Fetched ${category3Products.length} products from category 3');
      } catch (e) {
        print('Failed to fetch from category 3: $e');
      }

      setState(() {
        allProducts = [...selectedCategoryProducts, ...otherProducts];
        featuredProducts = selectedCategoryProducts.take(6).toList();
        recommendedProducts = otherProducts.take(4).toList();
        topCollectionProducts = allProducts.take(8).toList();
        isLoading = false;
      });

      print('Data loaded successfully!');
      print('Featured: ${featuredProducts.length}, Recommended: ${recommendedProducts.length}, Top: ${topCollectionProducts.length}');
      
    } catch (e) {
      print('Error fetching data: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load products. Please try again.';
      });
    }
  }

  void _onCategoryTapped(int index) {
    setState(() {
      _selectedCategoryIndex = index;
    });
    _fetchCategoryProducts(categoryIds[index]);
  }

  void _fetchCategoryProducts(int categoryId) async {
    try {
      print('Fetching products for category: $categoryId');
      final products = await ProductService.fetchProductsByCategory(categoryId);
      setState(() {
        featuredProducts = products.take(6).toList();
      });
      print('Updated featured products: ${featuredProducts.length}');
    } catch (e) {
      print('Error fetching category products: $e');
    }
  }

  void _onNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const CartPage()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
    }
  }

  void _navigateToAllProducts(String title, List<dynamic> products) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllProductsPage(
          title: title,
          products: products,
          categoryId: categoryIds[_selectedCategoryIndex],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'GemStore',
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            color: Colors.black87,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: isLoading 
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading products...'),
              ],
            ),
          )
        : errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(errorMessage!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _fetchAllData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopCategories(),
                  _buildMainBanner(),
                  _buildFeaturedProducts(),
                  if (recommendedProducts.isNotEmpty) _buildPromoBanner(),
                  if (recommendedProducts.isNotEmpty) _buildRecommendedSection(),
                  if (topCollectionProducts.isNotEmpty) _buildTopCollectionSection(),
                  const SizedBox(height: 100), // Space for bottom nav
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildTopCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(categories.length, (index) {
          IconData icon;
          switch (categories[index]) {
            case 'Women':
              icon = Icons.female;
              break;
            case 'Men':
              icon = Icons.male;
              break;
            case 'Accessories':
              icon = Icons.watch;
              break;
            case 'Beauty':
              icon = Icons.brush;
              break;
            default:
              icon = Icons.category;
          }

          return GestureDetector(
            onTap: () => _onCategoryTapped(index),
            child: _CategoryIcon(
              label: categories[index],
              icon: icon,
              selected: _selectedCategoryIndex == index,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMainBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFD4A574), Color(0xFFB8956A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (featuredProducts.isNotEmpty)
            Positioned(
              right: 20,
              top: 20,
              bottom: 20,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  featuredProducts[0]['images'][0],
                  width: 120,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 120,
                      color: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.image, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          const Positioned(
            left: 20,
            top: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Autumn',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Collection',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '2024',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedProducts() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Feature Products',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _navigateToAllProducts('Featured Products', featuredProducts),
                child: const Text(
                  'Show all',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        if (featuredProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text('No featured products available'),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: featuredProducts.length,
              itemBuilder: (context, index) {
                final product = featuredProducts[index];
                return _buildProductCard(
                  image: product['images'][0],
                  title: product['title'],
                  price: '\$${product['price'].toString()}',
                  width: 160,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (recommendedProducts.isNotEmpty)
            Positioned(
              right: 20,
              top: 10,
              bottom: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recommendedProducts[0]['images'][0],
                  width: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      color: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.image, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          const Positioned(
            left: 20,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW COLLECTION',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'HANG OUT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '& PARTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recommended',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _navigateToAllProducts('Recommended Products', recommendedProducts),
                child: const Text(
                  'Show all',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: recommendedProducts.take(4).length,
            itemBuilder: (context, index) {
              final product = recommendedProducts[index];
              return _buildHorizontalProductCard(
                image: product['images'][0],
                title: product['title'],
                price: '\$${product['price'].toString()}',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopCollectionSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Top Collection',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _navigateToAllProducts('Top Collection', topCollectionProducts),
                child: const Text(
                  'Show all',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        _buildCollectionBanner(),
        _buildCollectionGrid(),
      ],
    );
  }

  Widget _buildCollectionBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      height: 140,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFF4D03F), Color(0xFFE67E22)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          if (topCollectionProducts.isNotEmpty)
            Positioned(
              right: 20,
              top: 10,
              bottom: 10,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  topCollectionProducts[0]['images'][0],
                  width: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 100,
                      color: Colors.white.withOpacity(0.3),
                      child: const Icon(Icons.image, color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          const Positioned(
            left: 20,
            top: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sale up to 40%',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'FOR SLIM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '& BEAUTY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionGrid() {
    if (topCollectionProducts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('No collection products available'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: topCollectionProducts.take(4).length,
        itemBuilder: (context, index) {
          final product = topCollectionProducts[index];
          return _buildProductCard(
            image: product['images'][0],
            title: product['title'],
            price: '\$${product['price'].toString()}',
            width: double.infinity,
          );
        },
      ),
    );
  }

  Widget _buildProductCard({
    required String image,
    required String title,
    required String price,
    required double width,
  }) {
    return Container(
      width: width == double.infinity ? null : width,
      margin: width == double.infinity ? null : const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                image,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 40),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalProductCard({
    required String image,
    required String title,
    required String price,
  }) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            child: Image.network(
              image,
              width: 80,
              height: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: 80,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image, color: Colors.grey),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    price,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

  Widget _buildBottomNavBar() {
    return Container(
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
          currentIndex: _selectedIndex,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: _onNavTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.search),
              label: 'Search',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart_outlined),
              label: 'Cart',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _CategoryIcon({
    required this.label,
    required this.icon,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: selected ? Colors.white : Colors.grey,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.grey,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}