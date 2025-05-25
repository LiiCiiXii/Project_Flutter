import 'package:flutter/material.dart';
import 'package:flutter_project/services/product_service.dart';
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
  final List<int> categoryIds = [1, 2, 3, 4]; // Adjust based on actual API IDs

  List<dynamic> apiProducts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts(categoryIds[_selectedCategoryIndex]); // Fetch initial category
  }

  void _fetchProducts(int categoryId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final products = await ProductService.fetchProductsByCategory(categoryId);
      setState(() {
        apiProducts = products;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching products: $e');
      setState(() {
        isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Gemstore',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        children: [
          _buildTopCategories(),
          _buildBanner(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Feature Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Show all',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
          _buildHorizontalProducts(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            elevation: 10,
            selectedItemColor: Colors.black,
            unselectedItemColor: Colors.grey,
            currentIndex: _selectedIndex,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            onTap: _onNavTapped,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_outlined),
                activeIcon: const _NavBarIconWithHighlight(icon: Icons.home_outlined),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.search),
                activeIcon: const _NavBarIconWithHighlight(icon: Icons.search),
                label: 'Search',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.shopping_cart_outlined),
                activeIcon: const _NavBarIconWithHighlight(icon: Icons.shopping_cart_outlined),
                label: 'Cart',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.person_outline),
                activeIcon: const _NavBarIconWithHighlight(icon: Icons.person_outline),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopCategories() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
            onTap: () {
              setState(() {
                _selectedCategoryIndex = index;
              });
              _fetchProducts(categoryIds[index]);
            },
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

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.asset(
              'assets/images/banner_2.jpg',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            const Positioned(
              bottom: 20,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Autumn Collection',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '2022',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalProducts() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SizedBox(
      height: 300,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: apiProducts.length,
        itemBuilder: (context, index) {
          final product = apiProducts[index];
          return _buildProductCard(
            image: product['images'][0],
            title: product['title'],
            price: '\$${product['price'].toString()}',
          );
        },
      ),
    );
  }

  Widget _buildProductCard({
    required String image,
    required String title,
    required String price,
  }) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              image,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Category Icon Widget
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
        CircleAvatar(
          backgroundColor: selected ? Colors.black : Colors.grey.shade200,
          child: Icon(icon, color: selected ? Colors.white : Colors.grey),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(color: selected ? Colors.black : Colors.grey),
        ),
      ],
    );
  }
}

// Optional: Highlight effect for selected bottom nav
class _NavBarIconWithHighlight extends StatelessWidget {
  final IconData icon;

  const _NavBarIconWithHighlight({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: const BoxDecoration(
        color: Colors.black12,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.black),
    );
  }
}