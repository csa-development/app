import 'package:flutter/material.dart';

import '../../widgets/swipe_back.dart';

class CsaUnits extends StatelessWidget {
  const CsaUnits({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text('CSA Units'),
        ),
      ),
      body: const SwipeBack(
        child: Center(child: Text('This is the csa  Page')),
      ),
    );
  }
}
