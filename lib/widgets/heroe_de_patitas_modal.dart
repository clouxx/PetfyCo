import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

/// Product ID configurado en App Store Connect / Google Play Console.
const String _kAliadoProductId = 'aliado_petfyco_mensual';

/// Shows the "Aliado Petfyco" donation modal.
/// Call [HeroeDePatitasModal.show(context)] to display it.
class HeroeDePatitasModal extends StatefulWidget {
  const HeroeDePatitasModal({super.key, required this.recentPets});
  final List<Map<String, dynamic>> recentPets;

  static Future<void> show(BuildContext context) async {
    final sb = Supabase.instance.client;
    List<Map<String, dynamic>> pets = [];
    try {
      final data = await sb
          .from('pets')
          .select('id, nombre, pet_photos(url, position)')
          .order('created_at', ascending: false)
          .limit(3);
      pets = List<Map<String, dynamic>>.from(data);
    } catch (_) {}

    if (!context.mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => HeroeDePatitasModal(recentPets: pets),
    );
  }

  @override
  State<HeroeDePatitasModal> createState() => _HeroeDePatitasModalState();
}

class _HeroeDePatitasModalState extends State<HeroeDePatitasModal> {
  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  ProductDetails? _product;
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _subscription = _iap.purchaseStream.listen(_onPurchaseUpdate);
    _loadProduct();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final available = await _iap.isAvailable();
    if (!available) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final response = await _iap.queryProductDetails({_kAliadoProductId});
    if (mounted) {
      setState(() {
        _product = response.productDetails.isNotEmpty ? response.productDetails.first : null;
        _loading = false;
      });
    }
  }

  Future<void> _purchase() async {
    if (_product == null) return;
    setState(() => _purchasing = true);
    final param = PurchaseParam(productDetails: _product!);
    await _iap.buyNonConsumable(purchaseParam: param);
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _iap.completePurchase(purchase);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Gracias por ser Aliado Petfyco! 💜')),
          );
        }
      } else if (purchase.status == PurchaseStatus.error ||
          purchase.status == PurchaseStatus.canceled) {
        if (mounted) setState(() => _purchasing = false);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 20),

            // Title
            Text(
              'Aliado Petfyco',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.purple,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Illustration
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(
                color: AppColors.purple.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism, size: 56, color: AppColors.purple),
            ),
            const SizedBox(height: 20),

            // Description
            Text(
              'Sé un Aliado Petfyco y ayúdanos a seguir salvando vidas. No podemos con todo solos: necesitamos que nos des una ',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.5),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text('patita.', style: TextStyle(fontSize: 15, color: AppColors.purple, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),

            // "Hazlo por" section
            if (widget.recentPets.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(Icons.favorite, color: AppColors.purple, size: 18),
                  const SizedBox(width: 8),
                  const Text('Hazlo por:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.recentPets.length,
                  itemBuilder: (_, i) {
                    final pet = widget.recentPets[i];
                    final nombre = pet['nombre'] as String? ?? '';
                    final photos = pet['pet_photos'];
                    String? imgUrl;
                    if (photos is List && photos.isNotEmpty) {
                      final sorted = photos.whereType<Map>().map((e) => Map<String, dynamic>.from(e as Map)).toList()
                        ..sort((a, b) => (a['position'] as int? ?? 0).compareTo(b['position'] as int? ?? 0));
                      imgUrl = sorted.first['url'] as String?;
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: SizedBox(
                              width: 80, height: 90,
                              child: imgUrl != null
                                  ? Image.network(imgUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: AppColors.purple.withOpacity(0.1), child: const Icon(Icons.pets, color: AppColors.purple, size: 30)))
                                  : Container(color: AppColors.purple.withOpacity(0.1), child: const Icon(Icons.pets, color: AppColors.purple, size: 30)),
                            ),
                          ),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                              ),
                              child: Text(nombre, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Price
            Text(
              _product?.price ?? _getPrice(context),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.purple),
            ),
            const SizedBox(height: 20),

            // CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || _purchasing || _product == null) ? null : _purchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.purple,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.purple.withOpacity(0.5),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _loading || _purchasing
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Quiero ser Aliado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),

            // Skip button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Ahora no', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  String _getPrice(BuildContext context) {
    try {
      final country = View.of(context).platformDispatcher.locale.countryCode;
      if (country == 'CO') return '5.000 COP / mes';
    } catch (_) {}
    return '\$1.00 USD / mes';
  }
}
