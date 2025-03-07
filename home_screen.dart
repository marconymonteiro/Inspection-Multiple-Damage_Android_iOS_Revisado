import 'package:flutter/material.dart';
import 'inspection_form.dart'; // Importa a tela de novo formulário
import 'saved_forms.dart'; // Importa a tela de formulários salvos
import 'package:uuid/uuid.dart';
import 'local_storage.dart'; // Importa o arquivo onde você implementou checkAndSendPendingForms()

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

  @override
  void initState() {
    super.initState();
    _checkAndSyncPendingForms(); // Verifica e envia formulários pendentes ao iniciar
  }

  // Função para verificar e sincronizar formulários pendentes
  Future<void> _checkAndSyncPendingForms() async {
    setState(() {
      _isLoading = true; // Ativa o estado de carregamento
    });

    try {
      await checkAndSendPendingForms(); // Chama a função para sincronizar formulários pendentes
    } catch (e) {
      print('Erro ao sincronizar formulários pendentes: $e');
    } finally {
      setState(() {
        _isLoading = false; // Desativa o estado de carregamento
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tela Inicial'),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo do cliente - Imagem acima dos botões
                Image.asset(
                  'assets/logo_cliente.png', // Caminho para a logo do cliente
                  width: 150, // Ajuste o tamanho conforme necessário
                  height: 150,
                ),
                SizedBox(height: 30), // Espaçamento entre a logo e os botões

                // Botão para iniciar um novo formulário
                ElevatedButton(
                  onPressed: () {
                    final formId = generateUniqueFormId(); // Gera um ID único para o formulário
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FormularioInspecao(formId: formId),
                      ),
                    );
                  },
                  child: Text('Novo Formulário'),
                ),
                SizedBox(height: 20),

                // Botão para consultar formulários salvos
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SavedForms(), // Navega para a tela de formulários salvos
                      ),
                    );
                  },
                  child: Text('Consultar Formulários'),
                ),
              ],
            ),
          ),
          // Tela de carregamento enquanto sincroniza formulários pendentes
          Visibility(
            visible: _isLoading,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
