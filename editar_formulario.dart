import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Importe o pacote do Firestore

class EditarFormulario extends StatefulWidget {
  final String formId; // ID do formulário a ser visualizado
  const EditarFormulario({required this.formId});

  @override
  _EditarFormularioState createState() => _EditarFormularioState();
}

class _EditarFormularioState extends State<EditarFormulario> {
  Map<String, dynamic>? formData; // Armazena os dados do formulário

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  // Carrega os dados do Firestore usando o formId
  Future<void> _loadFormData() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final docSnapshot =
          await firestore.collection('inspection').doc(widget.formId).get();
      if (docSnapshot.exists) {
        setState(() {
          formData = docSnapshot.data() as Map<String, dynamic>;
        });
      } else {
        print('Documento não encontrado.');
      }
    } catch (e) {
      print('Erro ao carregar dados do Firestore: $e');
    }
  }

  // Exibe uma imagem com base no URL
  Widget _buildImage(String? url, {double height = 100, double width = 100}) {
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink(); // Retorna um espaço vazio se não houver URL
    }
    return Image.network(
      url,
      height: height,
      width: width,
      fit: BoxFit.cover,
    );
  }

  // Constrói um campo de texto com rótulo e valor
  Widget _buildTextDetail(String label, String? value) {
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          TextSpan(text: value ?? 'Não informado'),
        ],
      ),
    );
  }

  // Constrói uma lista de imagens
  Widget _buildImageList(List<dynamic> urls) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: urls.map((url) => _buildImage(url)).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (formData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Carregando Formulário...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Formulário')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data e Hora
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data e Hora: ${formData!['selectedDate'] != null ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(formData!['selectedDate'])) : 'Não informado'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Campos de Texto
              ..._buildTextFormFields(),

              // Fotos da Acomodação
              const Text(
                'Fotos da Acomodação',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImageList(formData!['photosAcomodacao'] ?? []),
              const SizedBox(height: 16),

              // Fotos do Calçamento
              const Text(
                'Fotos do Calçamento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImageList(formData!['photosCalcamento'] ?? []),
              const SizedBox(height: 16),

              // Fotos da Amarração
              const Text(
                'Fotos da Amarração',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImageList(formData!['photosAmarracao'] ?? []),
              const SizedBox(height: 16),

              // Foto da Plaqueta
              const Text(
                'Foto da Plaqueta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImage(formData!['photoPlaqueta']),
              const SizedBox(height: 16),

              // Assinatura
              const Text(
                'Assinatura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImage(formData!['signatureImage']),
              const SizedBox(height: 16),

              // Danos Registrados
              const Text(
                'Danos Registrados',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (formData!['damages'] != null)
                ...List.generate(
                  (formData!['damages'] as List<dynamic>).length,
                  (index) {
                    final damage = formData!['damages'][index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextDetail('Descrição', damage['description']),
                        _buildImageList(damage['photos'] ?? []),
                        const Divider(),
                      ],
                    );
                  },
                )
              else
                const Text('Nenhum dano registrado.'),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói os campos de texto com base nos dados do formulário
  List<Widget> _buildTextFormFields() {
    final fields = [
      {'key': 'equipment', 'label': 'Equipamento'},
      {'key': 'freight', 'label': 'Transportadora'},
      {'key': 'placaCarreta', 'label': 'Placa da Carreta'},
      {'key': 'plate', 'label': 'Placa do Cavalo'},
      {'key': 'name', 'label': 'Nome do Motorista'},
      {'key': 'driverID', 'label': 'CPF do Motorista'},
      {'key': 'nameResp', 'label': 'Responsável pela Aprovação'},
      {'key': 'cpfResp', 'label': 'CPF da Aprovação'},
      {'key': 'serialNumber', 'label': 'Número de Série'},
      {'key': 'invoiceNumber', 'label': 'Número da Nota Fiscal'},
      {'key': 'invoiceQtty', 'label': 'Quantidade Total de Volumes da NF'},
      {'key': 'invoiceItems', 'label': 'Quantidade Volume Partes e Peças da NF'},
    ];

    return fields.map((field) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextDetail(field['label']!, formData![field['key']]?.toString()),
          const SizedBox(height: 16),
        ],
      );
    }).toList();
  }
}
