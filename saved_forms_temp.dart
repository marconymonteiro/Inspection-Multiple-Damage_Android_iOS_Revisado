import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedForms extends StatefulWidget {
  @override
  _SavedFormsState createState() => _SavedFormsState();
}

class _SavedFormsState extends State<SavedForms> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allForms = [];
  List<Map<String, dynamic>> _filteredForms = [];

  @override
  void initState() {
    super.initState();
    _loadForms();
    _searchController.addListener(_filterForms);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadForms() async {
    List<Map<String, dynamic>> firestoreForms = await _loadFormsFromFirestore();
    List<Map<String, dynamic>> localForms = await _loadFormsLocally();

    // Marcar a origem dos formulários
    for (var form in firestoreForms) {
      form['origin'] = 'firestore'; // Indica que veio do Firestore
    }
    for (var form in localForms) {
      form['origin'] = 'local'; // Indica que está salvo localmente
    }

    // Mesclar listas, garantindo que os locais que ainda não foram sincronizados sejam mantidos
    Map<String, Map<String, dynamic>> uniqueForms = {
      for (var form in [...localForms, ...firestoreForms]) form['formId']: form
    };

    setState(() {
      _allForms = uniqueForms.values.toList();
      _filteredForms = _allForms;
    });
  }

  Future<List<Map<String, dynamic>>> _loadFormsFromFirestore() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('inspection').get();
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['formId'] = doc.id; // Adiciona o ID do documento
        return data;
      }).toList();
    } catch (e) {
      print('Erro ao carregar formulários do Firestore: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadFormsLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedFormsJson = prefs.getStringList('pending_forms') ?? [];
      return savedFormsJson
          .map((jsonString) => jsonDecode(jsonString) as Map<String, dynamic>)
          .toList();
    } catch (e) {
      print('Erro ao carregar formulários locais: $e');
      return [];
    }
  }

  void _filterForms() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredForms = _allForms.where((form) {
        final name = form['name']?.toString().toLowerCase() ?? '';
        final serialNumber = form['serialNumber']?.toString().toLowerCase() ?? '';
        final invoiceNumber = form['invoiceNumber']?.toString().toLowerCase() ?? '';
        return name.contains(query) ||
            serialNumber.contains(query) ||
            invoiceNumber.contains(query);
      }).toList();
    });
  }

  Future<void> _deleteForm(String formId, String origin) async {
    try {
      if (origin == 'firestore') {
        await FirebaseFirestore.instance.collection('inspection').doc(formId).delete();
      } else {
        final prefs = await SharedPreferences.getInstance();
        List<String> savedFormsJson = prefs.getStringList('pending_forms') ?? [];
        savedFormsJson.removeWhere((jsonString) {
          final form = jsonDecode(jsonString) as Map<String, dynamic>;
          return form['formId'] == formId;
        });
        await prefs.setStringList('pending_forms', savedFormsJson);
      }

      setState(() {
        _allForms.removeWhere((form) => form['formId'] == formId);
        _filteredForms.removeWhere((form) => form['formId'] == formId);
      });
    } catch (e) {
      print('Erro ao excluir formulário: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Formulários Salvos"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadForms,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar formulário...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _filteredForms.isEmpty
                ? Center(child: Text("Nenhum formulário encontrado"))
                : ListView.builder(
                    itemCount: _filteredForms.length,
                    itemBuilder: (context, index) {
                      final form = _filteredForms[index];
                      final formId = form['formId'];
                      final origin = form['origin'];
                      final statusIcon = origin == 'firestore'
                          ? Icon(Icons.cloud_done, color: Colors.green) // 🟢 Sincronizado
                          : Icon(Icons.cloud_off, color: Colors.orange); // 🟡 Apenas local

                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: statusIcon,
                          title: Text(form['name'] ?? 'Sem nome'),
                          subtitle: Text("N° Série: ${form['serialNumber'] ?? 'N/A'}"),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteForm(formId, origin),
                          ),
                          onTap: () {
                            // Lógica para abrir e editar o formulário, se necessário
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
