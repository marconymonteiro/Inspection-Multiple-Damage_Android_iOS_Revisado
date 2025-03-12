import 'package:flutter/material.dart';
import 'inspection_form.dart';
import 'saved_forms.dart';
import 'saved_offline.dart';
import 'package:uuid/uuid.dart';
import 'local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
//import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';

// Função para gerar um ID único para o formulário
String generateUniqueFormId() {
  var uuid = Uuid();
  return uuid.v4();
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;
  bool _hasPendingForms = false;
  bool _isConnected = true;
  bool _isSyncing = false; // Novo estado para controlar a sincronização
  int _pendingFormsCount = 0; // Contador de formulários pendentes
  double _syncProgress = 0.0; // Progresso da sincronização

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      setState(() {
        _isConnected = connectivityResult != ConnectivityResult.none;
      });
      if (_isConnected) {
        _checkAndSyncPendingForms();
      }
    });
  }

  // Verifica a conectividade com a internet
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });

    // Se houver conexão, sincroniza formulários pendentes
    if (_isConnected) {
      _checkAndSyncPendingForms();
    }
  }

  // Verifica e sincroniza formulários pendentes com Firestore
  Future<void> _checkAndSyncPendingForms() async {
  if (_isSyncing) return; // Evita múltiplas sincronizações simultâneas

  setState(() {
    _isSyncing = true;
    _syncProgress = 0.0;
  });

  try {
    await checkAndSendPendingForms((progress) {
      setState(() {
        _syncProgress = progress;
      });
    });
    await _checkPendingFormsLocally();
  } catch (e) {
    print('Erro ao sincronizar formulários pendentes: $e');
  } finally {
    setState(() {
      _isSyncing = false;
      _syncProgress = 1.0;
    });
  }
}

  // Verifica se há formulários salvos localmente e pendentes de sincronização
  Future<void> _checkPendingFormsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedFormsJson = prefs.getStringList('pending_forms');
    setState(() {
      _pendingFormsCount = savedFormsJson?.length ?? 0;
      _hasPendingForms = _pendingFormsCount > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tela Inicial')),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/logo_cliente.png', width: 150, height: 150),
                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    final formId = generateUniqueFormId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormularioInspecao(formId: formId),
                    ),
                    ).then((_) {
                      _checkPendingFormsLocally();
                    });
                  },
                  child: Text('Novo Formulário'),
                ),
                SizedBox(height: 20),
                if (_isConnected) ...[
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SavedForms()),
                      );
                    },
                    child: Text('Consultar Formulários'),
                  ),
                  SizedBox(height: 20),
                ],
                if (_hasPendingForms)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SavedOfflineForms()),
                      ).then((_) {
                        _checkPendingFormsLocally();
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_upload, color: Colors.black),
                        SizedBox(width: 5),
                        Text('Formulários Pendentes ($_pendingFormsCount)'),
                      ],
                    ),
                  )
                else if (_isConnected)
                  Column(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green, size: 40),
                      Text('Todos os formulários foram sincronizados'),
                    ],
                  ),
                if (_isSyncing)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Column(
                      children: [
                        Icon(Icons.sync, color: Colors.blue, size: 30),
                        Text('Sincronizando... ${(_syncProgress * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          /*
          if (_isLoading || _isSyncing)
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.5),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            */
        ],
      ),
    );
  }
}
