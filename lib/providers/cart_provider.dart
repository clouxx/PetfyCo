import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kCartKey = 'petfyco_cart';

class CartItem {
  final String productId;
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

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'description': description,
        'price': price,
        'emoji': emoji,
        'quantity': quantity,
        if (imageUrl != null) 'imageUrl': imageUrl,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        productId: j['productId'] as String,
        name: j['name'] as String,
        description: j['description'] as String,
        price: (j['price'] as num).toInt(),
        emoji: j['emoji'] as String,
        quantity: (j['quantity'] as num? ?? 1).toInt(),
        imageUrl: j['imageUrl'] as String?,
      );
}

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList();
        state = list;
      }
    } catch (_) {
      // Si los datos guardados son inválidos, arrancamos con carrito vacío
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCartKey, jsonEncode(state.map((e) => e.toJson()).toList()));
    } catch (_) {}
  }

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
    _save();
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
    _save();
  }

  void remove(String productId) {
    state = [for (final e in state) if (e.productId != productId) e];
    _save();
  }

  void clear() {
    state = [];
    _save();
  }

  int get totalItems => state.fold(0, (s, e) => s + e.quantity);
  int get totalPrice => state.fold(0, (s, e) => s + e.price * e.quantity);
}

final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>(
  (_) => CartNotifier(),
);
