import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Suporte à localização
import 'package:permission_handler/permission_handler.dart'; // Gerenciar permissões
import 'home_screen.dart'; // Importa a tela inicial
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante a inicialização correta
  await requestPermissions(); // Solicita permissões ao iniciar
  await Firebase.initializeApp(); // Inicializa o Firebase
  runApp(const InspectionApp());
}

// Função para solicitar permissões
Future<void> requestPermissions() async {
  // Lista de permissões necessárias
  final permissions = [
    Permission.camera, // Permissão para usar a câmera
    Permission.photos, // Para acessar fotos (substitui Permission.storage no Android 13+)
  ];

  // Solicita permissões
  for (var permission in permissions) {
    if (await permission.isDenied || await permission.isPermanentlyDenied) {
      await permission.request();
    }
  }
}

class InspectionApp extends StatelessWidget {
  const InspectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Firebase.initializeApp(), // Aguarda a inicialização do Firebase
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        } else if (snapshot.hasError) {
          return const MaterialApp(home: Scaffold(body: Center(child: Text('Erro ao carregar Firebase'))));
        }
        return MaterialApp(
          debugShowCheckedModeBanner: false, // Desativa o banner de debug
          home: HomeScreen(), // Tela inicial
          supportedLocales: const [
            Locale('pt', 'BR'), // Apenas Português do Brasil
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate, // Suporte para widgets Material
            GlobalWidgetsLocalizations.delegate, // Suporte para widgets
            GlobalCupertinoLocalizations.delegate, // Suporte para widgets Cupertino
          ],
        );
      },
    );
  }
}
