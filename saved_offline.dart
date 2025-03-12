import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage.dart'; // Importa seu arquivo existente

class SavedOfflineForms extends StatefulWidget {
  @override
  _SavedOfflineFormsState createState() => _SavedOfflineFormsState();
}

class _SavedOfflineFormsState extends State<SavedOfflineForms> {
  List<Map<String, dynamic>> _pendingForms = [];
  bool _isLoading = false;
  double _syncProgress = 0.0; // Progresso da sincronização

  @override
  void initState() {
    super.initState();
    _loadPendingForms();
  }

  Future<void> _loadPendingForms() async {
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    final savedForms = prefs.getStringList('pending_forms') ?? [];
    
    setState(() {
      _pendingForms = savedForms
          .map((json) => jsonDecode(json) as Map<String, dynamic>)
          .toList();
      _isLoading = false;
    });
  }

  void _syncForms() async {
    setState(() => _isLoading = true);

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sem conexão com a internet.')),
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await checkAndSendPendingForms((progress) {
        setState(() {
          _syncProgress = progress;
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sincronização concluída com sucesso.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao sincronizar: $e')),
      );
    } finally {
      await _loadPendingForms(); // Atualiza a lista
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Formulários Pendentes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncForms,
          )
        ],
      ),
      body: _isLoading
          ? Column(
              children: [
                LinearProgressIndicator(value: _syncProgress),
                const SizedBox(height: 16),
                const Center(child: Text('Sincronizando...')),
              ],
            )
          : _pendingForms.isEmpty
              ? const Center(child: Text('Nenhum formulário pendente'))
              : ListView.builder(
                  itemCount: _pendingForms.length,
                  itemBuilder: (context, index) {
                    final form = _pendingForms[index];
                    return ListTile(
                      title: Text('Equipamento: ${form['equipment'] ?? 'N/A'}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nº Série: ${form['serialNumber'] ?? ''}'),
                          Text('Nota Fiscal: ${form['invoiceNumber'] ?? ''}'),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
