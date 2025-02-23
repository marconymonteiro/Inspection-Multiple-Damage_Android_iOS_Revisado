import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_extend/share_extend.dart';
import 'pdf_generator.dart';
import 'package:image/image.dart' as img;
import 'package:signature/signature.dart'; // Pacote para captura de assinatura
import 'package:cloud_firestore/cloud_firestore.dart'; // Importe o pacote do Firestore
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class FormularioInspecao extends StatefulWidget {
  final String formId; // ID do formulário a ser editado
  FormularioInspecao({required this.formId});
  @override
  _FormularioInspecaoState createState() => _FormularioInspecaoState();
}

class _FormularioInspecaoState extends State<FormularioInspecao> {
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
  File? _photoPlaqueta; // Para a foto da plaqueta
  File? _signatureImage; // Para armazenar a assinatura como imagem
  final SignatureController _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  String damageJsonDecode(String jsonString) {
  // Implementação para decodificar o JSON
  return jsonString; // Exemplo simples
  }

  // Função de Upload das imagens

  Future<String?> uploadImage(File imageFile, String folder) async {
  try {
    // Nome do arquivo único
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Caminho no Storage
    Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName.jpg');

    // Upload da imagem
    UploadTask uploadTask = ref.putFile(imageFile);
    TaskSnapshot snapshot = await uploadTask;

    // Retorna a URL da imagem no Firebase Storage
    return await snapshot.ref.getDownloadURL();
  } catch (e) {
    print("Erro ao enviar imagem: $e");
    return null;
  }
}

 // Gera um hash MD5 - Nome único para as imagens
  Future<String> generateImageHash(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return md5.convert(bytes).toString(); // Gera um hash MD5
  }

    // Função auxiliar para evitar upload duplicado de imagens
  Future<String?> uploadIfNotExists(File? imageFile, String folder, String? existingUrl) async {
    if (imageFile == null || existingUrl != null) {
      return existingUrl; // Return the existing URL if the file hasn't changed
    }

    try {
      // Generate a unique hash for the file to avoid duplicates
      final bytes = await imageFile.readAsBytes();
      final fileHash = md5.convert(bytes).toString();
      final fileName = '$fileHash.jpg';

      // Reference to the file in Firebase Storage
      Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

      // Check if the file already exists
      final metadata = await ref.getMetadata().catchError((_) => null);
      if (metadata != null) {
        // File already exists, return its download URL
        return await ref.getDownloadURL();
      }

      // Upload the file if it doesn't exist
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // Return the download URL of the uploaded file
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erro ao enviar imagem: $e");
      return null;
    }
    }

    Future<void> _loadForm() async {
      try {
        final firestore = FirebaseFirestore.instance;
        final formRef = firestore.collection('inspection').doc(widget.formId);

        final docSnapshot = await formRef.get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>;

          setState(() {
            _hasDamage = data['hasDamage'] ?? 'Selecione';
            _selectedDate = data['selectedDate'] != null ? DateTime.parse(data['selectedDate']) : null;

            _photosAcomodacao = (data['photosAcomodacao'] as List?)?.map((url) => File(url)).toList() ?? [];
            _photosCalcamento = (data['photosCalcamento'] as List?)?.map((url) => File(url)).toList() ?? [];
            _photosAmarracao = (data['photosAmarracao'] as List?)?.map((url) => File(url)).toList() ?? [];
            _photoPlaqueta = data['photoPlaqueta'] != null ? File(data['photoPlaqueta']) : null;
            _signatureImage = data['signatureImage'] != null ? File(data['signatureImage']) : null;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar dados do Firestore.')),
        );
        print('Erro ao carregar dados do Firestore: $e');
      }
    }

  // Salvar as imagens no Firestore e salvar os links no firebase

  Future<void> _saveForm() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    // Referência ao Firestore
    final firestore = FirebaseFirestore.instance;
    final formRef = firestore.collection('inspection').doc(widget.formId);

    // Carrega os dados existentes do formulário
    final docSnapshot = await formRef.get();
    Map<String, dynamic> existingData = {};
    if (docSnapshot.exists) {
      existingData = docSnapshot.data() as Map<String, dynamic>;
    }

    // Upload das imagens apenas se necessário
    String? photoPlaquetaUrl = await uploadIfNotExists(
      _photoPlaqueta,
      "plaquetas",
      existingData['photoPlaqueta'],
    );

    String? signatureImageUrl = await uploadIfNotExists(
      _signatureImage,
      "assinaturas",
      existingData['signatureImage'],
    );

    List<String> photosAcomodacaoUrls = await Future.wait(
      _photosAcomodacao.asMap().entries.map((entry) async {
        int index = entry.key;
        File file = entry.value;
        String? existingUrl = existingData['photosAcomodacao']?[index];
        return await uploadIfNotExists(file, "acomodacao", existingUrl) ?? '';
      }),
    );

    List<String> photosCalcamentoUrls = await Future.wait(
      _photosCalcamento.asMap().entries.map((entry) async {
        int index = entry.key;
        File file = entry.value;
        String? existingUrl = existingData['photosCalcamento']?[index];
        return await uploadIfNotExists(file, "calcamento", existingUrl) ?? '';
      }),
    );

    List<String> photosAmarracaoUrls = await Future.wait(
      _photosAmarracao.asMap().entries.map((entry) async {
        int index = entry.key;
        File file = entry.value;
        String? existingUrl = existingData['photosAmarracao']?[index];
        return await uploadIfNotExists(file, "amarracao", existingUrl) ?? '';
      }),
    );

    // Preparar os dados para salvar no Firestore
    final Map<String, dynamic> formData = {
      'name': _controllers['name']!.text,
      'cpfResp': _controllers['cpfResp']!.text,
      'serialNumber': _controllers['serialNumber']!.text,
      'invoiceNumber': _controllers['invoiceNumber']!.text,
      'placaCarreta': _controllers['placaCarreta']!.text,
      'equipment': _controllers['equipment']!.text,
      'freight': _controllers['freight']!.text,
      'plate': _controllers['plate']!.text,
      'driverID': _controllers['driverID']!.text,
      'nameResp': _controllers['nameResp']!.text,
      'invoiceQtty': _controllers['invoiceQtty']!.text,
      'invoiceItems': _controllers['invoiceItems']!.text,
      'selectedDate': _selectedDate?.toIso8601String(),
      'hasDamage': _hasDamage,
      'damages': _damages.map((damage) => {
            'description': damage['description'],
            'photos': (damage['photos'] as List<File>).map((photo) async {
              String? url = await uploadIfNotExists(photo, "danos", null);
              return url ?? "";
            }).toList(),
          }).toList(),
      'photosAcomodacao': photosAcomodacaoUrls,
      'photosCalcamento': photosCalcamentoUrls,
      'photosAmarracao': photosAmarracaoUrls,
      'photoPlaqueta': photoPlaquetaUrl,
      'signatureImage': signatureImageUrl,
    };

    // Salvar no Firestore
    await formRef.set(formData, SetOptions(merge: true));

    // Feedback ao usuário
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Formulário salvo com sucesso no Firestore!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro ao salvar no Firestore.')),
    );
    print('Erro ao salvar no Firestore: $e');
  }
  }

  void _addPhotoToDamage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _damagePhotos.add(File(image.path));
      });
    }
  }

void _saveDamage() {
  if (_damageDescription.trim().isNotEmpty || _damagePhotos.isNotEmpty) {
    try {
      // Criamos o mapa dinâmico inicialmente
      Map<String, dynamic> dynamicMap = {
        'description': _damageDescription.trim(),
        'photos': List<File>.from(_damagePhotos),
      };

      // Convertendo o mapa dinâmico para garantir o tipo correto
      Map<String, Object> convertedMap = Map<String, Object>.from(dynamicMap);

      setState(() {
        _damages.add(convertedMap); // Adicionamos o mapa convertido à lista
        _damageDescription = ''; // Limpa a descrição
        _damagePhotos.clear(); // Limpa a lista de fotos
      });

      print('Avaria salva com sucesso: $convertedMap');
    } catch (e) {
      print('Erro ao salvar avaria: $e');
    }
  } else {
    print('Nenhuma avaria foi fornecida para salvar.');
  }
}

  void _editDamage(int index) {
  final damage = _damages[index];
  setState(() {
    _damageDescription = damage['description'] as String; // Casting explícito para String
    _damagePhotos = List<File>.from(damage['photos'] as List); // Casting para List
    _damages.removeAt(index);
  });
}

void _showPhoto(File photo, {required VoidCallback onDelete}) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.file(photo),
          const SizedBox(height: 16), // Adiciona espaçamento entre a imagem e os botões
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () async {
                  final shouldDelete = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Excluir Imagem'),
                        content: const Text('Tem certeza de que deseja excluir esta imagem?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      );
                    },
                  );
                  if (shouldDelete == true) {
                    onDelete();
                    Navigator.pop(context); // Fecha o diálogo principal
                  }
                },
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text('Excluir'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

//  String _hasDamage = 'Selecione';
  final List<File> _photosDamage = [];
  String reportDate = ""; // Variável para armazenar a data formatada.

  @override
  void initState() {
    super.initState();
    _loadForm();
  }

  Future<void> _pickDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate ?? DateTime.now()),
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );

        // Formatando para dd/MM/yyyy HH:mm
        reportDate = DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!);
        print('Data e hora selecionadas: $reportDate'); // Verifique no console
        });
      }
    }
  }

  Future<Uint8List> _compressImage(File image) async {
      final bytes = await image.readAsBytes();
      final decodedImage = img.decodeImage(bytes);
      final compressedImage = img.encodeJpg(decodedImage!, quality: 50);
      return Uint8List.fromList(compressedImage);
    }

  Future<void> _pickImage(List<File> photoList) async {
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final tempFile = File(photo.path);
      final compressedBytes = await _compressImage(tempFile);
      final compressedFile = await File(tempFile.path).writeAsBytes(compressedBytes);
      setState(() {
        photoList.add(compressedFile);
      });
    }
  }

  // Método para capturar a foto da plaqueta (única imagem)
Future<void> _pickPlaquetaPhoto() async {
  final ImagePicker picker = ImagePicker();
  final XFile? photo = await picker.pickImage(source: ImageSource.camera);
  if (photo != null) {
    final tempFile = File(photo.path);
    final compressedBytes = await _compressImage(tempFile);
    final compressedFile = await File(tempFile.path).writeAsBytes(compressedBytes);
    setState(() {
      _photoPlaqueta = compressedFile;
    });
  }
}

  // Campo Assinatura

  Future<void> _clearSignature() async {
    setState(() {
      _signatureController.clear(); // Limpa o estado interno do controlador
      _signatureImage?.delete();   // Remove o arquivo de imagem anterior, se existir
      _signatureImage = null;      // Remove a referência à imagem salva
    });
  }

  Future<void> _saveSignature() async {
    if (_signatureController.isNotEmpty) {
      final Uint8List? data = await _signatureController.toPngBytes();
      if (data != null) {
        final tempDir = Directory.systemTemp;

        // Adiciona um identificador único ao nome do arquivo (timestamp)
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filePath = '${tempDir.path}/signature_$timestamp.png';

        // Cria ou substitui o arquivo
        final file = File(filePath);
        await file.writeAsBytes(data, mode: FileMode.write); // Sobrescreve o arquivo

        // Remove a assinatura anterior, se existir
        if (_signatureImage != null) {
          await _signatureImage!.delete();
        }

        setState(() {
          _signatureImage = file; // Salva a nova assinatura
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Assinatura vazia. Por favor, desenhe uma assinatura.')),
      );
    }
  }

  Widget _buildSignatureSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assinatura do Responsável pela Liberação',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black),
          ),
          child: Signature(
            controller: _signatureController,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ElevatedButton.icon(
              onPressed: _clearSignature,
              icon: const Icon(Icons.clear),
              label: const Text('Limpar'),
            ),
            ElevatedButton.icon(
              onPressed: _saveSignature,
              icon: const Icon(Icons.save),
              label: const Text('Salvar Assinatura'),
            ),
          ],
        ),
        if (_signatureImage != null)
          Image.file(_signatureImage!, height: 100, width: 200, fit: BoxFit.cover),
      ],
    );
  }

  Widget _buildPhotoPreview(List<File> photos, {required VoidCallback onDelete}) {
    return photos.isNotEmpty
        ? Wrap(
            spacing: 8,
            runSpacing: 8,
            children: photos.map((photo) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: () => _showFullImage(photo),
                    child: Image.file(photo, height: 100, width: 100, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => _confirmDeletePhoto(photo, photos),
                  ),
                ],
              );
            }).toList(),
          )
        : const SizedBox();
  }

  // Método para confirmar a exclusão de uma foto (reutilizado para todos os campos)
  Future<void> _confirmDeletePhoto(File photo, List<File> photoList) async {
    final shouldDelete = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Excluir Imagem'),
          content: const Text('Tem certeza que deseja excluir esta imagem?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Não'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sim'),
            ),
          ],
        );
      },
    );
    if (shouldDelete == true) {
      setState(() {
        photoList.remove(photo);
      });
    }
  }

  // Método para exibir a imagem em tamanho completo (reutilizado para todos os campos)
  void _showFullImage(File photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.file(photo),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final pdfFile = await PdfGenerator().generatePdf(
      //formId: widget.formId, // Adicione o formId aqui
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
    );

    await ShareExtend.share(pdfFile.path, 'application/pdf');
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Formulário de Inspeção')),
    body: Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Data e Hora: ${_selectedDate != null ? DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate!) : 'Selecione a data e hora'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDateTime,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._buildTextFormFields(),

              TextFormField(
              controller: _controllers['invoiceQtty'],
              keyboardType: TextInputType.number, // Define o teclado numérico
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Permite apenas números
              decoration: const InputDecoration(
                labelText: 'Quantidade de Volumes',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira a quantidade de volumes';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controllers['invoiceItems'],
              keyboardType: TextInputType.number, // Define o teclado numérico
              inputFormatters: [FilteringTextInputFormatter.digitsOnly], // Permite apenas números
              decoration: const InputDecoration(
                labelText: 'Quantidade Partes e Peças',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira a quantidade de partes e peças';
                }
                return null;
              },
            ),

             // Foto da Plaqueta
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _pickPlaquetaPhoto,
                child: const Text('Adicionar Foto da Plaqueta'),
              ),
              const SizedBox(height: 8), // Espaçamento entre o botão e a foto
              if (_photoPlaqueta != null)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    GestureDetector(
                      onTap: () => _showFullImage(_photoPlaqueta!),
                      child: Image.file(_photoPlaqueta!, height: 100, width: 100, fit: BoxFit.cover),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _confirmDeletePhoto(_photoPlaqueta!, [_photoPlaqueta!]),
                    ),
                  ],
                ),

              const SizedBox(height: 16),
                const Text(
                  'Registros da Carga',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _pickImage(_photosAcomodacao),
                child: const Text('Adicionar Fotos de Acomodação'),
              ),
              _buildPhotoPreview(_photosAcomodacao, onDelete: () {}),
              const SizedBox(height: 16),

              // Fotos do Calçamento
              ElevatedButton(
                onPressed: () => _pickImage(_photosCalcamento),
                child: const Text('Adicionar Fotos de Calçamento'),
              ),
              _buildPhotoPreview(_photosCalcamento, onDelete: () {}),
              const SizedBox(height: 16),

              // Fotos da Amarração
              ElevatedButton(
                onPressed: () => _pickImage(_photosAmarracao),
                child: const Text('Adicionar Fotos de Amarração'),
              ),
              _buildPhotoPreview(_photosAmarracao, onDelete: () {}),
              const SizedBox(height: 16),

              const SizedBox(height: 16),
                const Text(
                  'Registros da Avarias',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _hasDamage,
                decoration: const InputDecoration(labelText: 'Há Avarias?'),
                items: ['Selecione', 'Sim', 'Não'].map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _hasDamage = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              if (_hasDamage == 'Sim') ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Descrição da avaria',
                    alignLabelWithHint: true, // Alinha o rótulo com o topo do campo
                    border: OutlineInputBorder(), // Adiciona uma borda ao redor do campo
                  ),
                  keyboardType: TextInputType.multiline, // Permite múltiplas linhas
                  textInputAction: TextInputAction.newline, // Habilita "Enter" para criar uma nova linha
                  maxLines: null, // Permite linhas ilimitadas
                  minLines: 3, // Mostra pelo menos 3 linhas por padrão
                  onChanged: (value) {
                    _damageDescription = value;
                  },
                  initialValue: _damageDescription,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, insira a descrição da avaria';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Adicionar Foto da Avaria'),
                  onPressed: () => _pickImage(_damagePhotos)
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8, // Adiciona espaçamento vertical entre as linhas
                  children: _damagePhotos.map((photo) {
                    return GestureDetector(
                      onTap: () => _showPhoto(photo, onDelete: () {
                        setState(() {
                          _damagePhotos.remove(photo);
                        });
                      }),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          Image.file(
                            photo,
                            height: 100,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => _confirmDeletePhoto(photo, _damagePhotos),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Salvar Avaria'),
                  onPressed: _saveDamage,
                ),
                const SizedBox(height: 16),
                if (_damages.isNotEmpty)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _damages.length,
                    itemBuilder: (context, index) {
                      final damage = _damages[index];
                      return Card(
                        child: ListTile(
                          title: Text(damage['description'] as String),
                          subtitle: Wrap(
                            spacing: 8,
                            runSpacing: 8, // Adiciona espaçamento vertical entre as linhas
                              children: (damage['photos'] != null ? damage['photos'] as List<File> : []).map<Widget>((photo) {
                              return GestureDetector(
                                onTap: () => _showPhoto(photo, onDelete: () {
                                  setState(() {
                                      if (damage['photos'] != null && damage['photos'] is List<File>) {
                                      (damage['photos'] as List<File>).remove(photo);
                                    }                                                                    });
                                }),
                                child: Image.file(
                                  photo,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ),
                              );
                            }).toList(),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _editDamage(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  final shouldDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Excluir Avaria'),
                                        content: const Text('Tem certeza que deseja excluir esta avaria?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('Não'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('Sim'),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                  if (shouldDelete ?? false) {
                                    setState(() {
                                      _damages.removeAt(index);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
              // Campo Assinatura
              const SizedBox(height: 16),
                const Text(
                  'Dados de Aprovação',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _controllers['nameResp'],
                  decoration: const InputDecoration(labelText: 'Responsável pela Aprovação'),
                  validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _controllers['cpfResp'],
                  decoration: const InputDecoration(labelText: 'CPF da Aprovação'),
                  validator: (value) => value == null || value.isEmpty ? 'Campo obrigatório' : null,
                ),
                const SizedBox(height: 16),
                _buildSignatureSection(),
              
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveForm,
                child: const Text('Salvar Formulário'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Gerar PDF'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

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
  ];

  return fields.map((field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controllers[field['key']],
          decoration: InputDecoration(labelText: field['label']),
          validator: (value) =>
              value == null || value.isEmpty ? 'Campo obrigatório' : null,
        ),
        const SizedBox(height: 16),
      ],
    );
  }).toList();
}
}
