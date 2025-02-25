import 'dart:io';
import 'package:flutter/material.dart';
import 'package:inspection_multiple_damage/pdf_generator.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_extend/share_extend.dart';

class EditarFormulario extends StatefulWidget {
  final String formId; // ID do formulário a ser visualizado
  const EditarFormulario({required this.formId});

  @override
  _EditarFormularioState createState() => _EditarFormularioState();
}

class _EditarFormularioState extends State<EditarFormulario> {
  Map<String, dynamic>? formData; // Armazena os dados do formulário
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(), // controlador para o campo "CPF do Responsável pela aprovação"
    'cpfResp': TextEditingController(), // controlador para o campo "Carga"
    'serialNumber': TextEditingController(),
    'invoiceNumber': TextEditingController(),
    'damageDescription': TextEditingController(),
    'placaCarreta': TextEditingController(), // Novo controlador para o campo "Placa da Carreta"
    'equipment': TextEditingController(), // Novo controlador para o campo "Equipamento"
    'freight': TextEditingController(), // Novo controlador para o campo "transportadora"
    'plate': TextEditingController(), // Novo controlador para o campo "placas"
    'driverID': TextEditingController(), // Novo controlador para o campo "CPF"
    'nameResp': TextEditingController(), // Novo controlador para o campo "Responsável pela Liberação da Carga"
    'invoiceQtty': TextEditingController(), // Novo controlador para o campo "Quantidade de Volumes"
    'invoiceItems': TextEditingController(), // Novo controlador para o campo "Quantidade Partes e Peças"
  };

  // String _currentDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
  DateTime? _selectedDate; // PARA NOVO PICKDATETIME

  String _hasDamage = 'Selecione'; // Variável para controlar o estado de seleção da avaria
  List<Map<String, Object>> _damages = []; // Lista que conterá mapas com tipos garantidos
  Map<String, Object>? convertedMap; // Inicialize como nulo, será usado após a conversão
  String _damageDescription = ''; // Descrição da avaria
  List<File> _damagePhotos = []; // Lista de fotos relacionadas a avarias
  final List<File> _photosCarga = []; // Lista final de fotos de carga
  List<File> _photosAcomodacao = [];
  List<File> _photosCalcamento = [];
  List<File> _photosAmarracao = [];
  final List<File> _photosDamage = [];
  File? _photoPlaqueta; // Para a foto da plaqueta
  File? _signatureImage; // Para armazenar a assinatura como imagem

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

          // Inicializa os controladores com os valores do Firestore
          _controllers['name']?.text = formData?['name'] ?? '';
          _controllers['cpfResp']?.text = formData?['cpfResp'] ?? '';
          _controllers['serialNumber']?.text = formData?['serialNumber'] ?? '';
          _controllers['invoiceNumber']?.text = formData?['invoiceNumber'] ?? '';
          _controllers['placaCarreta']?.text = formData?['placaCarreta'] ?? '';
          _controllers['equipment']?.text = formData?['equipment'] ?? '';
          _controllers['freight']?.text = formData?['freight'] ?? '';
          _controllers['plate']?.text = formData?['plate'] ?? '';
          _controllers['driverID']?.text = formData?['driverID'] ?? '';
          _controllers['nameResp']?.text = formData?['nameResp'] ?? '';
          _controllers['invoiceQtty']?.text = formData?['invoiceQtty'] ?? '';
          _controllers['invoiceItems']?.text = formData?['invoiceItems'] ?? '';

          _controllers['damageDescription']?.text = formData?['damageDescription'] ?? '';

          _selectedDate = formData?['selectedDate'] != null
              ? DateTime.parse(formData!['selectedDate'])
              : null;
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
    return GestureDetector(
      onTap: () {
        // Mostra a imagem em tamanho maior ao clicar
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            height: height,
            width: width,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // Constrói um campo de texto com rótulo e valor
  Widget _buildTextDetail(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2, // Aumentado para dar mais espaço à primeira coluna
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
            flex: 3, // Ajustado para equilibrar o espaço
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
          children: urls.map((url) => _buildImage(url)).toList(),
        ),
      ],
    );
  }

  // Exibe a assinatura sem necessidade de clique para ampliar
  Widget _buildSignatureSection(String? signatureUrl) {
    if (signatureUrl == null || signatureUrl.isEmpty) {
      return const SizedBox.shrink(); // Retorna um espaço vazio se não houver URL
    }
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
        Container(
          width: double.infinity, // Ocupa toda a largura disponível
          height: 150, // Altura fixa para melhor visualização
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              signatureUrl,
              fit: BoxFit.contain, // Garante que a imagem caiba dentro do contêiner
            ),
          ),
        ),
      ],
    );
  }

  // Função para gerar o PDF e compartilhar
  Future<void> _generateAndSharePDF() async {
    if (formData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dados do formulário não carregados.')),
      );
      return;
    }

    try {
      // Gera o PDF
final pdfFile = await PdfGenerator().generatePdf(
      name: _controllers['name']!.text,
      cpfResp: _controllers['cpfResp']!.text,
      serialNumber: _controllers['serialNumber']!.text,
      invoiceNumber: _controllers['invoiceNumber']!.text,
      placaCarreta: _controllers['placaCarreta']!.text,
      equipment: _controllers['equipment']!.text,
      freight: _controllers['freight']!.text,
      plate: _controllers['plate']!.text,
      driverID: _controllers['driverID']!.text,
      nameResp: _controllers['nameResp']!.text,
      invoiceQtty: _controllers['invoiceQtty']!.text,
      invoiceItems: _controllers['invoiceItems']!.text,

      reportDate: _selectedDate != null
          ? DateFormat('dd/mm/yyyy', 'pt_BR').format(_selectedDate!)
          : 'Data não selecionada',
      hasDamage: _hasDamage == 'Sim',
      damageDescription: _controllers['damageDescription']!.text,
      photosCarga: _photosCarga,
      photosAcomodacao: _photosAcomodacao,
      photosAmarracao: _photosAmarracao,
      photosCalcamento: _photosCalcamento,
      photosDamage: _photosDamage,
      damagesData: _damages, //incluído para teste de emissão de PDF
      photoPlaqueta: _photoPlaqueta,
      signatureImage: _signatureImage,
    );

      // Compartilha o PDF
      ShareExtend.share(pdfFile.path, 'application/pdf');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao gerar PDF: $e')),
      );
    }
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
      appBar: AppBar(
        title: const Text('Detalhes do Formulário'),
        backgroundColor: Colors.blueGrey,
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
                      formData!['selectedDate'] != null
                          ? DateFormat('dd/MM/yyyy HH:mm')
                              .format(DateTime.parse(formData!['selectedDate']))
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
              _buildImageList(formData!['photosAcomodacao'] ?? [], 'Fotos da Acomodação'),
              // Fotos do Calçamento
              _buildImageList(formData!['photosCalcamento'] ?? [], 'Fotos do Calçamento'),
              // Fotos da Amarração
              _buildImageList(formData!['photosAmarracao'] ?? [], 'Fotos da Amarração'),
              // Foto da Plaqueta
              _buildImageList([formData!['photoPlaqueta']].whereType<String>().toList(), 'Foto da Plaqueta'),
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
                      _buildTextDetail('Responsável pela Aprovação', formData!['nameResp']),
                      _buildTextDetail('CPF da Aprovação', formData!['cpfResp']),
                      const SizedBox(height: 8),
                      _buildSignatureSection(formData!['signatureImage']),
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
                      if (formData!['damages'] != null)
                        ...List.generate(
                          (formData!['damages'] as List<dynamic>).length,
                          (index) {
                            final damage = formData!['damages'][index];
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
              // Botão para gerar PDF
              Center(
                child: ElevatedButton(
                  onPressed: _generateAndSharePDF,
                  child: Text('Gerar PDF'),
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
      return _buildTextDetail(field['label']!, formData![field['key']]?.toString());
    }).toList();
  }
}
