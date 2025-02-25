import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importe o Firestore
import 'editar_formulario.dart';

class SavedForms extends StatefulWidget {
  @override
  _ConsultaFormulariosState createState() => _ConsultaFormulariosState();
}

class _ConsultaFormulariosState extends State<SavedForms> {
  TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allForms = [];
  List<Map<String, dynamic>> _filteredForms = [];

  @override
  void initState() {
    super.initState();
    _loadFormsFromFirestore();
    // Listener para filtrar formulários
    _searchController.addListener(() {
      setState(() {
        final query = _searchController.text.toLowerCase();
        _filteredForms = _allForms.where((form) {
          final name = form['name']?.toString().toLowerCase() ?? '';
          final serialNumber = form['serialNumber']?.toString().toLowerCase() ?? '';
          final invoiceNumber = form['invoiceNumber']?.toString().toLowerCase() ?? '';
          return name.contains(query) ||
              serialNumber.contains(query) ||
              invoiceNumber.contains(query);
        }).toList();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Carrega todos os formulários do Firestore
  Future<void> _loadFormsFromFirestore() async {
    try {
      final QuerySnapshot snapshot =
          await FirebaseFirestore.instance.collection('inspection').get();
      setState(() {
        _allForms = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id; // Adiciona o ID do documento ao mapa
          return data;
        }).toList();
        _filteredForms = _allForms; // Inicialmente, exibe todos
      });
    } catch (e) {
      print('Erro ao carregar formulários do Firestore: $e');
    }
  }

  // Remove um formulário do Firestore
  Future<void> _deleteForm(String formId) async {
    try {
      await FirebaseFirestore.instance.collection('inspection').doc(formId).delete();
      setState(() {
        _allForms.removeWhere((form) => form['id'] == formId);
        _filteredForms.removeWhere((form) => form['id'] == formId);
      });
    } catch (e) {
      print('Erro ao excluir formulário: $e');
    }
  }

  // Mostra o pop-up de confirmação para exclusão
  void _confirmDelete(BuildContext context, String formId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja excluir este formulário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fecha o diálogo
              _deleteForm(formId); // Exclui o formulário
            },
            child: Text('Sim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Formulários Salvos')),
      body: Column(
        children: [
          // Campo de busca
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar formulários',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          // Lista de formulários
          Expanded(
            child: ListView.builder(
              itemCount: _filteredForms.length,
              itemBuilder: (context, index) {
                final form = _filteredForms[index];
                return ListTile(
                  title: Text(form['equipment'] ?? 'Equipamento'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Número de Série: ${form['serialNumber'] ?? ''}'),
                      Text('Nota Fiscal: ${form['invoiceNumber'] ?? ''}'),
                    ],
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(context, form['id']),
                  ),
                  onTap: () {
                    // Navegar para edição
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditarFormulario(formId: form['id']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
