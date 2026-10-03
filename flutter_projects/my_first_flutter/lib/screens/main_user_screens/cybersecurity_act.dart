import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

// The official text of the Act, bundled with the app so it opens instantly
// and works without internet. To publish an amended version, replace this
// file (keeping the name) and release a new build.
const String _actAsset = 'assets/legal/cybersecurity-act-2020-act-1038.pdf';

class CybersecurityActScreen extends StatefulWidget {
  const CybersecurityActScreen({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  State<CybersecurityActScreen> createState() => _CybersecurityActScreenState();
}

class _CybersecurityActScreenState extends State<CybersecurityActScreen> {
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openAsset(_actAsset),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Cybersecurity Act, 2020',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          PdfViewPinch(
            controller: _controller,
            padding: 8,
            backgroundDecoration:
                const BoxDecoration(color: Color(0xFFE9ECEF)),
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                ),
              ),
              pageLoaderBuilder: (_) => const Center(
                child: CircularProgressIndicator(
                  color: Colors.black,
                ),
              ),
              errorBuilder: (_, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Sorry, the Act could not be opened. '
                    'Please try again later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: PdfPageNumber(
                controller: _controller,
                builder: (context, loadingState, page, pagesCount) {
                  if (loadingState != PdfLoadingState.success ||
                      pagesCount == null) {
                    return const SizedBox.shrink();
                  }
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Page $page of $pagesCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
