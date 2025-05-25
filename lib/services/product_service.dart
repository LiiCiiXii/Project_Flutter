import 'dart:convert';
import 'package:http/http.dart' as http;

class ProductService {
  static const String _baseUrl = 'https://api.escuelajs.co/api/v1';

  // Fetch products by category using the correct endpoint
  static Future<List<dynamic>> fetchProductsByCategory(int categoryId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/categories/$categoryId/products'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> products = json.decode(response.body);
      return products;
    } else {
      throw Exception('Failed to load products for category $categoryId');
    }
  }

  // Fetch all products (useful for search)
  static Future<List<dynamic>> fetchAllProducts() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/products'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> products = json.decode(response.body);
      return products;
    } else {
      throw Exception('Failed to load products');
    }
  }

  // Fetch products with pagination (optional)
  static Future<List<dynamic>> fetchProductsWithPagination({
    int offset = 0,
    int limit = 20,
  }) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/products?offset=$offset&limit=$limit'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> products = json.decode(response.body);
      return products;
    } else {
      throw Exception('Failed to load products');
    }
  }

  // Search products by title
  static Future<List<dynamic>> searchProducts(String query) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/products/?title=$query'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> products = json.decode(response.body);
      return products;
    } else {
      throw Exception('Failed to search products');
    }
  }
}