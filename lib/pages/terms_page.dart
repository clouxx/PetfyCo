import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';

const _termsUrl = 'https://www.petfyco.co/terminos';

class TermsPage extends StatefulWidget {
  const TermsPage({super.key});

  @override
  State<TermsPage> createState() => _TermsPageState();
}

class _TermsPageState extends State<TermsPage> {
  WebViewController? _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (_) => setState(() => _loading = false),
        ))
        ..loadRequest(Uri.parse(_termsUrl));
    } else {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        elevation: 0,
      ),
      body: kIsWeb ? _webFallback() : _mobileWebView(),
    );
  }

  Widget _mobileWebView() {
    return Stack(
      children: [
        WebViewWidget(controller: _ctrl!),
        if (_loading)
          const Center(child: CircularProgressIndicator()),
      ],
    );
  }

  Widget _webFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: AppColors.purple),
            const SizedBox(height: 16),
            const Text(
              'Términos y Condiciones',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Toca el botón para leer los Términos y Condiciones en tu navegador.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                final uri = Uri.parse(_termsUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              icon: const Icon(Icons.open_in_browser),
              label: const Text('Abrir Términos y Condiciones'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
