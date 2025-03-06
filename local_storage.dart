import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'inspection_form.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:crypto/crypto.dart';

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

// Função para verificar e enviar formulários pendentes
Future<void> checkAndSendPendingForms() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> savedForms = prefs.getStringList('pending_forms') ?? [];

  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('Sem conexão com a internet. Tentará novamente mais tarde.');
    return;
  }

  if (savedForms.isNotEmpty) {
    final firestore = FirebaseFirestore.instance;

    for (String form in savedForms) {
      try {
        Map<String, dynamic> formData = jsonDecode(form);
        String formId = formData['formId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

        // Upload de fotos
        List<String> uploadedPhotosAcomodacao = await uploadPhotos(formData['photosAcomodacao'], "acomodacao");
        List<String> uploadedPhotosCalcamento = await uploadPhotos(formData['photosCalcamento'], "calcamento");
        List<String> uploadedPhotosAmarracao = await uploadPhotos(formData['photosAmarracao'], "amarracao");

        formData['photosAcomodacao'] = uploadedPhotosAcomodacao;
        formData['photosCalcamento'] = uploadedPhotosCalcamento;
        formData['photosAmarracao'] = uploadedPhotosAmarracao;

        if (formData['photoPlaqueta'] != null) {
          formData['photoPlaqueta'] = await uploadImage(File(formData['photoPlaqueta']), "plaquetas");
        }
        if (formData['signatureImage'] != null) {
          formData['signatureImage'] = await uploadImage(File(formData['signatureImage']), "assinaturas");
        }

        // Upload de fotos de danos
        List<dynamic> damages = formData['damages'] ?? [];
        for (var damage in damages) {
          damage['photos'] = await uploadPhotos(damage['photos'], "danos");
        }
        formData['damages'] = damages;

        // Envio para o Firestore
        await firestore.collection('inspection').doc(formId).set(formData);
        print('Formulário enviado para o Firestore: $formId');

      } catch (e) {
        print('Erro ao enviar formulário para o Firestore: $e');
        return;
      }
    }

    await prefs.remove('pending_forms');
    print('Todos os formulários pendentes foram enviados e removidos localmente.');
  }
}

Future<List<String>> uploadPhotos(List<dynamic>? photos, String folder) async {
  if (photos == null || photos.isEmpty) return [];

  List<String> uploadedUrls = [];
  for (var path in photos) {
    if (path is String && File(path).existsSync()) {
      String? url = await uploadImage(File(path), folder);
      if (url != null) uploadedUrls.add(url);
    } else {
      print('Arquivo não encontrado: $path');
    }
  }
  return uploadedUrls;
}

Future<void> syncPendingDamages() async {
  
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('Sem conexão com a internet. Tentará novamente mais tarde.');
    return;
  }
  
  try {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedDamages = prefs.getStringList('pending_damages') ?? [];

    if (savedDamages.isEmpty) return;

    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } on SocketException catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) return;

    List<String> remainingDamages = [];

    for (String damageJson in savedDamages) {
      Map<String, dynamic> damageData = jsonDecode(damageJson);
      
      List<String> updatedPhotoUrls = [];
      for (String localPath in damageData['photos']) {
        if (!localPath.startsWith('http')) { // Se for um caminho local, faz upload
          String? url = await uploadImage(File(localPath), "danos");
          if (url != null) {
            updatedPhotoUrls.add(url);
          }
        } else {
          updatedPhotoUrls.add(localPath);
        }
      }

      damageData['photos'] = updatedPhotoUrls;

      await FirebaseFirestore.instance
          .collection('inspection')
          .doc(damageData['formId'])
          .collection('damages')
          .add(damageData);

      print('Avaria sincronizada no Firestore.');
    }

    await prefs.setStringList('pending_damages', remainingDamages);
    print('Todas as avarias pendentes foram sincronizadas.');

  } catch (e) {
    print('Erro ao sincronizar avarias pendentes: $e');
  }
}
