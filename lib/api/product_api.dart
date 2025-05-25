import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/product_model.dart';

class ProductApi {
  static Future<List<Product>> fetchProducts() async {
    final url = Uri.parse('https://api.escuelajs.co/api/v1/products');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      List data = jsonDecode(response.body);
      return data.map((item) => Product.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load products');
    }
  }
}