class Order {
  final int id;
  final String oid;
  final String name;
  final String seller;
  final String buyer;
  final String image;
  final bool sended;
  final double price;

  const Order({
    required this.id,
    required this.oid,
    required this.name,
    required this.seller,
    required this.buyer,
    required this.image,
    required this.sended,
    required this.price,
  });

  factory Order.fromJson(Map<String, dynamic> map) {
    return Order(
      id: (map['id'] as num).toInt(),
      oid: (map['Oid'] ?? '') as String,
      name: (map['name'] ?? '') as String,
      seller: (map['seller'] ?? '') as String,
      buyer: (map['buyer'] ?? '') as String,
      image: (map['image'] ?? '') as String,
      sended: (map['sended'] as bool?) ?? false,
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toInsertJson() => {
        'Oid': oid,
        'name': name,
        'price': price,
        'buyer': buyer,
        'seller': seller,
        'image': image,
        'sended': sended,
      };
}
