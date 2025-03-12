// ignore_for_file: unused_field

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Suporte à localização
import 'package:permission_handler/permission_handler.dart'; // Gerenciar permissões
import 'home_screen.dart'; // Importa a tela inicial
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart'; // Para verificar a conectividade
import 'local_storage.dart'; // Importa o arquivo onde você implementou checkAndSendPendingForms()

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Garante a inicialização correta
  await requestPermissions(); // Solicita permissões ao iniciar
  await Firebase.initializeApp(); // Inicializa o Firebase

  // Habilita a persistência offline do Firestore
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );

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
    return MaterialApp(
      debugShowCheckedModeBanner: false, // Desativa o banner de debug
      home: ConnectivityListener(), // Wrapper para monitorar a conectividade
      supportedLocales: const [
        Locale('pt', 'BR'), // Apenas Português do Brasil
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Suporte para widgets Material
        GlobalWidgetsLocalizations.delegate, // Suporte para widgets
        GlobalCupertinoLocalizations.delegate, // Suporte para widgets Cupertino
      ],
    );
  }
}

// Widget para monitorar a conectividade
class ConnectivityListener extends StatefulWidget {
  @override
  _ConnectivityListenerState createState() => _ConnectivityListenerState();
}

class _ConnectivityListenerState extends State<ConnectivityListener> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  double _syncProgress = 0.0; // Progresso da sincronização


  @override
  void initState() {
    super.initState();

    // Monitora a conectividade com a internet
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
      // Verifica se há pelo menos uma conexão ativa
      if (results.any((result) => result != ConnectivityResult.none)) {
        // Se houver conexão, sincroniza formulários pendentes
        await checkAndSendPendingForms((progress) {
        setState(() {
          _syncProgress = progress;
        });
      });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel(); // Cancela o listener ao sair
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(); // Exibe a tela inicial
  }
}
