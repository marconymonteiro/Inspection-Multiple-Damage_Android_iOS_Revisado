import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_extend/share_extend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_generator.dart';
import 'package:image/image.dart' as img;
import 'package:signature/signature.dart'; // Pacote para captura de assinatura
import 'package:cloud_firestore/cloud_firestore.dart'; // Importe o pacote do Firestore
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage.dart'; // Importa o arquivo onde você implementou checkAndSendPendingForms()


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
  List<Map<String, dynamic>> _damages = []; // Lista que conterá mapas com tipos garantidos
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
    // Variável para controlar o progresso
  double _progress = 0.0;
  bool _isLoading = false;

  double _syncProgress = 0.0; // Progresso da sincronização

  String damageJsonDecode(String jsonString) {
  // Implementação para decodificar o JSON
  return jsonString; // Exemplo simples
  }

  // Função de Upload das imagens

  Future<String?> uploadImage(File imageFile, String folder) async {
  try {
    // Gera um hash único para o arquivo
    final bytes = await imageFile.readAsBytes();
    final fileHash = md5.convert(bytes).toString();
    final fileName = '$fileHash.jpg';

    // Caminho no Storage
    Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName');

    // Verifica se o arquivo já existe
    try {
      final metadata = await ref.getMetadata();
      return await ref.getDownloadURL(); // Retorna a URL existente
    } catch (e) {
      // Se o arquivo não existir, faz o upload
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    }
    } catch (e) {
      print("Erro ao enviar imagem: $e");
      return null;
    }
  }

  Future<bool> checkInternetConnection() async {
      var connectivityResult = await Connectivity().checkConnectivity();
      print('Resultado da conectividade: $connectivityResult'); // Log para depuração

      return connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.wifi;
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
    try {
      final FullMetadata metadata = await ref.getMetadata();
      // File already exists, return its download URL
      return await ref.getDownloadURL();
    } catch (e) {
      // If metadata retrieval fails, assume the file does not exist and proceed to upload
      UploadTask uploadTask = ref.putFile(imageFile);
      TaskSnapshot snapshot = await uploadTask;

      // Return the download URL of the uploaded file
      return await snapshot.ref.getDownloadURL();
    }
  } catch (e) {
    print("Erro ao enviar imagem: $e");
    return null;
  }
  }

  Future<void> _loadForm() async {
  try {
    // Verifica a conectividade
    bool hasInternet = await checkInternetConnection();

    if (hasInternet) {
      // Tenta carregar os dados do Firestore
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

        // Salva os dados localmente para uso offline
        await saveFormLocally(data);
        return; // Sai do método após carregar os dados do Firestore
      }
    }

    // Carrega os dados localmente se estiver offline ou se o formulário não existir no Firestore
    final localData = await _loadFormLocally();
    if (localData != null) {
      setState(() {
        _hasDamage = localData['hasDamage'] ?? 'Selecione';
        _selectedDate = localData['selectedDate'] != null ? DateTime.parse(localData['selectedDate']) : null;
        _photosAcomodacao = (localData['photosAcomodacao'] as List?)?.map((url) => File(url)).toList() ?? [];
        _photosCalcamento = (localData['photosCalcamento'] as List?)?.map((url) => File(url)).toList() ?? [];
        _photosAmarracao = (localData['photosAmarracao'] as List?)?.map((url) => File(url)).toList() ?? [];
        _photoPlaqueta = localData['photoPlaqueta'] != null ? File(localData['photoPlaqueta']) : null;
        _signatureImage = localData['signatureImage'] != null ? File(localData['signatureImage']) : null;
      });
    } else {
      // Exibe um snackbar informando que nenhum dado foi encontrado
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nenhum dado encontrado localmente.')),
      );
    }
    } catch (e) {
      // Exibe um snackbar em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados. Verifique sua conexão.')),
      );
      print('Erro ao carregar dados: $e');
    }
  }

  Future<void> saveFormLocally(Map<String, dynamic> formData) async {
    final prefs = await SharedPreferences.getInstance();
    if (!formData.containsKey('formId')) {
      formData['formId'] = DateTime.now().millisecondsSinceEpoch.toString();
    }
    final formId = formData['formId'];
    final formJson = jsonEncode(formData);
    
    // Adiciona o JSON do formulário à lista de pendentes
    List<String> pendingForms = prefs.getStringList('pending_forms') ?? [];
    pendingForms.add(formJson);
    await prefs.setStringList('pending_forms', pendingForms);
  }

  Future<Map<String, dynamic>?> _loadFormLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> pendingForms = prefs.getStringList('pending_forms') ?? [];
      for (String formJson in pendingForms) {
        Map<String, dynamic> form = jsonDecode(formJson);
        if (form['formId'] == widget.formId) {
          return form;
        }
      }
    } catch (e) {
      print('Erro ao carregar dados localmente: $e');
    }
    return null;
  }

  // Salvar as imagens no Firestore e salvar os links no firebase

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _progress = 0.0;
    });

    try {
      final Map<String, dynamic> formData = {
        'formId': widget.formId,
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
        'damages': _damages,
        'photosAcomodacao': [],
        'photosCalcamento': [],
        'photosAmarracao': [],
        'photoPlaqueta': null,
        'signatureImage': null,
      };

      // Verifica conexão antes de continuar
      bool hasInternet = await checkInternetConnection();

      if (hasInternet) {
        final formRef = FirebaseFirestore.instance.collection('inspection').doc(widget.formId);

        List<File> allPhotos = [..._photosAcomodacao, ..._photosCalcamento, ..._photosAmarracao];
        int totalTasks = 2 + allPhotos.length; // 2 para assinatura e plaqueta
        int completedTasks = 0;

        void updateProgress() {
          setState(() {
            _progress = (completedTasks / totalTasks).clamp(0.0, 1.0);
          });
        }

        Future<String?> safeUpload(File? file, String folder) async {
          if (file == null) return null;
          try {
            String? url = await _uploadFile(file, folder, null);
            completedTasks++;
            updateProgress();
            return url;
          } catch (e) {
            print('Erro no upload de $folder: $e');
            return null;
          }
        }

        // Faz upload ou salva localmente
        Future<List<String>> uploadMultiple(List<File> files, String folder) async {
          return await Future.wait(
            files.map((file) => safeUpload(file, folder)).toList(),
          ).then((urls) => urls.whereType<String>().toList()); // Remove nulos
        }

        formData['photoPlaqueta'] = await safeUpload(_photoPlaqueta, "plaquetas");
        formData['signatureImage'] = await safeUpload(_signatureImage, "assinaturas");
        formData['photosAcomodacao'] = await uploadMultiple(_photosAcomodacao, "acomodacao");
        formData['photosCalcamento'] = await uploadMultiple(_photosCalcamento, "calcamento");
        formData['photosAmarracao'] = await uploadMultiple(_photosAmarracao, "amarracao");

        bool allUploadsSucceeded = formData.values.where((v) => v is List && v.isEmpty).isEmpty;

        if (allUploadsSucceeded) {
            
          for (var damage in _damages) {
            List<String> updatedPhotoUrls = [];
            for (var photo in damage['photos']) {
              if (!photo.startsWith('http')) { // Se for um caminho local, faz upload
                String? url = await uploadImage(File(photo), "danos");
                if (url != null) {
                  updatedPhotoUrls.add(url);
                }
              } else {
                updatedPhotoUrls.add(photo); // Mantém a URL existente
              }
            }
            damage['photos'] = updatedPhotoUrls;
          }

          formData['damages'] = _damages; // Atualiza os danos no formData
          
          await formRef.set(formData, SetOptions(merge: true));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Formulário salvo no Firestore com sucesso.')),
          );
        } else {
          await saveFormLocally(formData);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao enviar imagens. Formulário salvo localmente.')),
          );
        }
      } else {
        // Salva caminhos locais se estiver offline
        formData['photoPlaqueta'] = _photoPlaqueta?.path;
        formData['signatureImage'] = _signatureImage?.path;
        formData['photosAcomodacao'] = _photosAcomodacao.map((p) => p.path).toList();
        formData['photosCalcamento'] = _photosCalcamento.map((p) => p.path).toList();
        formData['photosAmarracao'] = _photosAmarracao.map((p) => p.path).toList();

        await saveFormLocally(formData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sem internet. Formulário salvo localmente.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar o formulário.')),
      );
      print('Erro ao salvar o formulário: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Monitora o progresso de envio do formulário
  Future<String?> _uploadFile(File? file, String folder, String? existingUrl) async {
    if (file == null || existingUrl != null) {
      return existingUrl;
    }

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference ref = FirebaseStorage.instance.ref().child('$folder/$fileName.jpg');
      UploadTask uploadTask = ref.putFile(file);

      // Monitora o progresso do upload
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double taskProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('Progresso do upload: ${(taskProgress * 100).toStringAsFixed(2)}%');
      });

      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      print("Erro ao enviar imagem: $e");
      return null;
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

  void _saveDamage() async {
    if (_damageDescription.trim().isNotEmpty || _damagePhotos.isNotEmpty) {
      try {
        // Cria o mapa dinâmico
        Map<String, dynamic> dynamicMap = {
          'description': _damageDescription.trim(),
          'photos': _damagePhotos.map<String>((photo) => photo.path.toString()).toList(),
          'formId': widget.formId,
        };

        for (var photo in _damagePhotos) {
          print('Tipo de photo.path: ${photo.path.runtimeType}');
        }

        // Salva a avaria localmente para sincronização posterior
        await saveDamageLocally(dynamicMap);

        // Atualiza a lista _damages com os dados locais
        List<Map<String, dynamic>> localDamages = await loadDamagesLocally(widget.formId);
        setState(() {
          _damages = localDamages;
          _damageDescription = ''; // Limpa a descrição
          _damagePhotos.clear(); // Limpa a lista de fotos
        });

        print('Avaria salva com sucesso: $dynamicMap');
      } catch (e) {
        print('Erro ao salvar avaria: $e');
      }
    } else {
      print('Nenhuma avaria foi fornecida para salvar.');
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Nenhuma avaria foi fornecida para salvar.')),
    );
    }
  }

  Future<void> saveDamageLocally(Map<String, dynamic> damageData) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingDamages = prefs.getStringList('pending_damages') ?? [];
    
    // Verifica se o dano já existe (baseado no formId e description)
    bool exists = false;
    for (int i = 0; i < pendingDamages.length; i++) {
      Map<String, dynamic> existingDamage = jsonDecode(pendingDamages[i]);
      if (existingDamage['formId'] == damageData['formId'] &&
          existingDamage['description'] == damageData['description']) {
        pendingDamages[i] = jsonEncode(damageData); // Atualiza o dano existente
        exists = true;
        break;
      }
    }
    if (!exists) {
      pendingDamages.add(jsonEncode(damageData)); // Adiciona o novo dano
    }
    await prefs.setStringList('pending_damages', pendingDamages);
  }

  Future<List<Map<String, dynamic>>> loadDamagesLocally(String formId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingDamages = prefs.getStringList('pending_damages') ?? [];

    return pendingDamages.map((damageJson) {
      Map<String, dynamic> damage = jsonDecode(damageJson) as Map<String, dynamic>;

      // Garante que 'photos' seja do tipo List<String>
      if (damage.containsKey('photos') && damage['photos'] is List<dynamic>) {
        damage['photos'] = (damage['photos'] as List).map((photo) => photo.toString()).toList();
      }

      return damage;
    }).where((damage) => damage['formId'] == formId).toList(); // Filtra pelo formId
  }

  void _editDamage(int index) async {
    final damage = _damages[index];

    setState(() {
      _damageDescription = damage['description'] as String;
      _damagePhotos = (damage['photos'] as List<dynamic>)
          .map((photo) => File(photo.toString()))
          .toList();
    });

    // Remover a avaria da lista local e do armazenamento
    _damages.removeAt(index);
    await _removeDamageLocally(damage);
  }

  Future<void> _removeDamageLocally(Map<String, dynamic> damage) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> pendingDamages = prefs.getStringList('pending_damages') ?? [];

    pendingDamages.removeWhere((item) {
      Map<String, dynamic> existingDamage = jsonDecode(item);
      return existingDamage['formId'] == damage['formId'] &&
            existingDamage['description'] == damage['description'];
    });

    await prefs.setStringList('pending_damages', pendingDamages);
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
  checkAndSendPendingForms((progress) {
      setState(() {
        _syncProgress = progress;
      });
    });; // Verifica e envia formulários pendentes ao iniciar

    // Carrega o formulário localmente apenas se houver dados salvos
    _loadFormLocally().then((localData) {
      if (localData != null) {
        setState(() {
          _hasDamage = localData['hasDamage'] ?? 'Selecione';
          _selectedDate = localData['selectedDate'] != null ? DateTime.parse(localData['selectedDate']) : null;
          _photosAcomodacao = (localData['photosAcomodacao'] as List?)?.map((path) => File(path)).toList() ?? [];
          _photosCalcamento = (localData['photosCalcamento'] as List?)?.map((path) => File(path)).toList() ?? [];
          _photosAmarracao = (localData['photosAmarracao'] as List?)?.map((path) => File(path)).toList() ?? [];
          _photoPlaqueta = localData['photoPlaqueta'] != null ? File(localData['photoPlaqueta']) : null;
          _signatureImage = localData['signatureImage'] != null ? File(localData['signatureImage']) : null;
        });
      }
    });
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
  void _showFullImage(dynamic image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              panEnabled: true, // Permite arrastar a imagem
              boundaryMargin: const EdgeInsets.all(20), // Margem para movimento
              minScale: 1.0, // Zoom mínimo
              maxScale: 20.0, // Zoom máximo
              child: _getImageWidget(image), // Usa um método separado para exibir a imagem
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        ),
      ),
    );
  }

// Método auxiliar para carregar a imagem corretamente
  Widget _getImageWidget(dynamic image) {
    if (image is File) {
      return Image.file(image); // Caso já seja um File, exibe normalmente
    } else if (image is String && image.startsWith('http')) {
      return Image.network(image); // Caso seja uma URL remota
    } else if (image is String) {
      return Image.file(File(image)); // Caso seja um caminho local, converte para File
    }
    return const SizedBox(); // Retorna um widget vazio se a imagem for inválida
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
          ? DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate!)
          : 'Data não selecionada',
      hasDamage: _hasDamage == 'Sim',
      damageDescription: _controllers['damageDescription']!.text,
      photosCarga: _photosCarga,
      photosAcomodacao: _photosAcomodacao,
      photosCalcamento: _photosCalcamento,
      photosAmarracao: _photosAmarracao,
      damagesData: _damages, // Passa as fotos dos danos aqui
      photoPlaqueta: _photoPlaqueta,
      signatureImage: _signatureImage,
      
      //photosDamage: _photosDamage,
    );

    await ShareExtend.share(pdfFile.path, 'application/pdf');
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: const Text('Formulário de Inspeção')),
    body: Stack(
      children: [
      Padding (
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
                          runSpacing: 8,
                          children: (damage['photos'] != null ? damage['photos'] as List<String> : []).map<Widget>((url) {
                            return GestureDetector(
                              onTap: () => _showFullImage(url),
                              child: url.startsWith('http') ? // Verifica se é uma URL remota
                                Image.network(
                                  url,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                ) :
                                Image.file( // Se não for URL, assume que é caminho local
                                  File(url),
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
                                  await _removeDamageLocally(_damages[index]); // Remove do SharedPreferences
                                  setState(() {
                                    _damages.removeAt(index); // Atualiza a lista na tela
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
      // Tela de carregamento
        Visibility(
          visible: _isLoading,
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: _progress),
                  const SizedBox(height: 16),
                  Text(
                    '${(_progress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    )
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
