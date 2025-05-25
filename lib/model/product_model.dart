class Product {
  final int id;
  final String title;
  final String image;
  final String price;
  final String description;
  final String category;

  Product({
    required this.id,
    required this.title,
    required this.image,
    required this.price,
    required this.description,
    required this.category,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      title: json['title'],
      image: json['images'][0],
      price: json['price'].toString(),
      description: json['description'],
      category: json['category']['name'],
    );
  }
}