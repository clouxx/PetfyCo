import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final String productId; // ID real del producto en store_products
  final String name;
  final String description;
  final int price;
  final String emoji;
  final int quantity;
  final String? imageUrl;

  const CartItem({
    required this.productId,
    required this.name,
    required this.description,
    required this.price,
    required this.emoji,
    this.quantity = 1,
    this.imageUrl,
  });

  CartItem copyWith({int? quantity}) => CartItem(
        productId: productId,
        name: name,
        description: description,
        price: price,
        emoji: emoji,
        quantity: quantity ?? this.quantity,
        imageUrl: imageUrl,
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void add(CartItem item) {
    final idx = state.indexWhere((e) => e.productId == item.productId);
    if (idx >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(quantity: state[i].quantity + 1) else state[i],
      ];
    } else {
      state = [...state, item];
    }
  }

  void decrement(String productId) {
    final idx = state.indexWhere((e) => e.productId == productId);
    if (idx < 0) return;
    if (state[idx].quantity > 1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(quantity: state[i].quantity - 1) else state[i],
      ];
    } else {
      state = [for (final e in state) if (e.productId != productId) e];
    }
  }

  void remove(String productId) {
    state = [for (final e in state) if (e.productId != productId) e];
  }

  void clear() => state = [];

  int get totalItems => state.fold(0, (s, e) => s + e.quantity);
  int get totalPrice => state.fold(0, (s, e) => s + e.price * e.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);
