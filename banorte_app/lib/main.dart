import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';
import 'theme.dart';

void main() => runApp(
      MaterialApp(
        title: 'Banorte · Finanzas Personales',
        debugShowCheckedModeBanner: false,
        theme: banorteTheme(),
        home: const DashboardScreen(),
      ),
    );

