import 'package:flutter/material.dart';
import 'inspection_form.dart';
import 'saved_forms.dart';
import 'saved_offline.dart';
import 'package:uuid/uuid.dart';
import 'local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart'; // Para verificar a conexão

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
  bool _isConnected = true; // Novo estado para armazenar a conexão

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      setState(() {
        _isConnected = connectivityResult != ConnectivityResult.none;
      });
    });
    _checkAndSyncPendingForms();
  }

  // Verifica a conectividade com a internet
  Future<void> _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isConnected = connectivityResult != ConnectivityResult.none;
    });
  }

  // Verifica e sincroniza formulários pendentes com Firestore
  Future<void> _checkAndSyncPendingForms() async {
    setState(() => _isLoading = true);
    try {
      await checkAndSendPendingForms();
      await _checkPendingFormsLocally(); // Atualiza o estado após sincronização
    } catch (e) {
      print('Erro ao sincronizar formulários pendentes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Verifica se há formulários salvos localmente e pendentes de sincronização
  Future<void> _checkPendingFormsLocally() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? savedFormsJson = prefs.getStringList('pending_forms');
    setState(() {
      _hasPendingForms = savedFormsJson != null && savedFormsJson.isNotEmpty;
    });
  }

  // Garante que a tela seja atualizada ao retornar para ela
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkConnectivity();
    _checkPendingFormsLocally();
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
                Image.asset(
                  'assets/logo_cliente.png',
                  width: 150,
                  height: 150,
                ),
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
                      _checkPendingFormsLocally(); // Atualiza ao voltar
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

                // Botão "Formulários Pendentes" (aparece apenas se houver pendentes)
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
                        _checkPendingFormsLocally(); // Atualiza ao voltar
                      });
                    },
                    child: Text('Formulários Pendentes'),
                  )
                else if (_isConnected)
                  Column(
                    children: [
                      Icon(Icons.cloud_done, color: Colors.green, size: 40),
                      Text('Todos os formulários foram sincronizados'),
                    ],
                  ),
              ],
            ),
          ),
          Visibility(
            visible: _isLoading,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }
}
