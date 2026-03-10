import 'package:flutter_riverpod/flutter_riverpod.dart';

class CartItem {
  final String name;
  final String description;
  final int price;
  final String emoji;
  final int quantity;

  const CartItem({
    required this.name,
    required this.description,
    required this.price,
    required this.emoji,
    this.quantity = 1,
  });

  CartItem copyWith({int? quantity}) => CartItem(
        name: name,
        description: description,
        price: price,
        emoji: emoji,
        quantity: quantity ?? this.quantity,
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  void add(CartItem item) {
    final idx = state.indexWhere((e) => e.name == item.name);
    if (idx >= 0) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(quantity: state[i].quantity + 1) else state[i],
      ];
    } else {
      state = [...state, item];
    }
  }

  void decrement(String name) {
    final idx = state.indexWhere((e) => e.name == name);
    if (idx < 0) return;
    if (state[idx].quantity > 1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == idx) state[i].copyWith(quantity: state[i].quantity - 1) else state[i],
      ];
    } else {
      state = [for (final e in state) if (e.name != name) e];
    }
  }

  void remove(String name) {
    state = [for (final e in state) if (e.name != name) e];
  }

  void clear() => state = [];

  int get totalItems => state.fold(0, (s, e) => s + e.quantity);
  int get totalPrice => state.fold(0, (s, e) => s + e.price * e.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);
