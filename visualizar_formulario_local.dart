import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VisualizarFormularioLocal extends StatelessWidget {
  final Map<String, dynamic> formData;

  const VisualizarFormularioLocal({required this.formData, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Formulário Local'),
        backgroundColor: const Color.fromARGB(255, 220, 237, 72),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Data e Hora (sem Card)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Data e Hora',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formData['selectedDate'] != null
                          ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(formData['selectedDate']))
                          : 'Não informado',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              // Campos de Texto
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Informações Gerais',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._buildTextFormFields(),
                    ],
                  ),
                ),
              ),
              // Fotos da Acomodação
              _buildImageList(formData['photosAcomodacao'] ?? [], 'Fotos da Acomodação'),
              // Fotos do Calçamento
              _buildImageList(formData['photosCalcamento'] ?? [], 'Fotos do Calçamento'),
              // Fotos da Amarração
              _buildImageList(formData['photosAmarracao'] ?? [], 'Fotos da Amarração'),
              // Foto da Plaqueta
              _buildImageList([formData['photoPlaqueta']] ?? [], 'Foto da Plaqueta'),
              // Sessão de Aprovação
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aprovação',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildTextDetail('Responsável pela Aprovação', formData['nameResp']),
                      _buildTextDetail('CPF da Aprovação', formData['cpfResp']),
                      const SizedBox(height: 8),
                      _buildSignatureSection((formData['signatureImage'])),
                    ],
                  ),
                ),
              ),
              // Danos Registrados
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danos Registrados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (formData['damages'] != null)
                        ...List.generate(
                          (formData['damages'] as List<dynamic>).length,
                          (index) {
                            final damage = formData['damages'][index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextDetail('Descrição', damage['description']),
                                _buildImageList(damage['photos'] ?? [], ''),
                                const Divider(),
                              ],
                            );
                          },
                        )
                      else
                        Text(
                          'Nenhum dano registrado.',
                          style: TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                    ],
                  ),
                ),
              ),
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
      {'key': 'serialNumber', 'label': 'Número de Série'},
      {'key': 'invoiceNumber', 'label': 'Número da Nota Fiscal'},
      {'key': 'invoiceQtty', 'label': 'Quantidade Total de Volumes da NF'},
      {'key': 'invoiceItems', 'label': 'Quantidade Volume Partes e Peças da NF'},
    ];
    return fields.map((field) {
      return _buildTextDetail(field['label']!, formData[field['key']]?.toString());
    }).toList();
  }

  // Constrói um campo de texto com rótulo e valor
  Widget _buildTextDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label: ',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'Não informado',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Constrói uma lista de imagens
  Widget _buildImageList(List<dynamic> urls, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: urls.map((url) {
            if (url is String) {
              return Image.file(
                File(url),
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              );
            } else {
              return Container(); // Ou outra lógica para lidar com URLs inválidas
            }
          }).toList(),
        ),
      ],
    );
  }

  // Constrói a seção de assinatura
  Widget _buildSignatureSection(String? signatureImagePath) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Assinatura',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey,
          ),
        ),
        const SizedBox(height: 8),
        if (signatureImagePath != null && signatureImagePath.isNotEmpty)
          Image.file(
            File(signatureImagePath),
            width: 200,
            height: 100,
            fit: BoxFit.contain,
          )
        else
          Text(
            'Não assinada',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
      ],
    );
  }
}
