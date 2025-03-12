// ignore_for_file: unused_local_variable

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
//import 'inspection_form.dart';
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
Future<void> checkAndSendPendingForms(Function(double) onProgressUpdate) async {
  final prefs = await SharedPreferences.getInstance();
  List<String> savedForms = prefs.getStringList('pending_forms') ?? [];

  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('Sem conexão com a internet. Tentará novamente mais tarde.');
    return;
  }

  if (savedForms.isNotEmpty) {
    final firestore = FirebaseFirestore.instance;

    // Calcula o progresso por formulário
    double progressIncrement = 1.0 / savedForms.length;
    double currentProgress = 0.0;

    for (int i = 0; i < savedForms.length; i++) {
      String form = savedForms[i];
      try {
        Map<String, dynamic> formData = jsonDecode(form);

        // Converte a lista de danos para List<Map<String, dynamic>>
        if (formData['damages'] != null) {
          formData['damages'] = List<Map<String, dynamic>>.from(formData['damages']);
        }

        String formId = formData['formId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

        // Upload de fotos
        List<String> uploadedPhotosAcomodacao = await uploadPhotos(formData['photosAcomodacao'], "acomodacao");
        currentProgress += progressIncrement * 0.25; // 25% do progresso
        onProgressUpdate(currentProgress);

        List<String> uploadedPhotosCalcamento = await uploadPhotos(formData['photosCalcamento'], "calcamento");
        currentProgress += progressIncrement * 0.25; // 50% do progresso
        onProgressUpdate(currentProgress);

        List<String> uploadedPhotosAmarracao = await uploadPhotos(formData['photosAmarracao'], "amarracao");
        currentProgress += progressIncrement * 0.25; // 75% do progresso
        onProgressUpdate(currentProgress);

        formData['photosAcomodacao'] = uploadedPhotosAcomodacao;
        formData['photosCalcamento'] = uploadedPhotosCalcamento;
        formData['photosAmarracao'] = uploadedPhotosAmarracao;

        if (formData['photoPlaqueta'] != null) {
          formData['photoPlaqueta'] = await uploadImage(File(formData['photoPlaqueta']), "plaquetas");
          currentProgress += progressIncrement * 0.1; // 85% do progresso
          onProgressUpdate(currentProgress);
        }
        if (formData['signatureImage'] != null) {
          formData['signatureImage'] = await uploadImage(File(formData['signatureImage']), "assinaturas");
          currentProgress += progressIncrement * 0.1; // 95% do progresso
          onProgressUpdate(currentProgress);
        }

        // Upload de fotos de danos
        List<Map<String, dynamic>> damages = formData['damages'] ?? [];
        for (var damage in damages) {
          if (damage['photos'] != null) {
            damage['photos'] = await uploadPhotos(damage['photos'], "danos");
          }
        }
        formData['damages'] = damages;

        // Envio para o Firestore
        await firestore.collection('inspection').doc(formId).set(formData);
        print('Formulário enviado para o Firestore: $formId');

        // Atualiza o progresso
        currentProgress += progressIncrement * 0.05; // 100% do progresso
        onProgressUpdate(currentProgress);

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
    if (path is String) {
      if (path.startsWith('http')) { // Se já for URL, ignora
        uploadedUrls.add(path);
      } else {
        File file = File(path);
        if (file.existsSync()) {
          String? url = await uploadImage(file, folder);
          if (url != null) uploadedUrls.add(url);
        } else {
          print('Arquivo não encontrado: $path');
        }
      }
    }
  }
  return uploadedUrls;
}

// Função para sincronizar os danos
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
        if (!localPath.startsWith('http') && !localPath.startsWith('https')) { // Verifica se é um caminho local
          String? url = await uploadImage(File(localPath), "danos");
          if (url != null) {
            updatedPhotoUrls.add(url);
          }
        } else {
          updatedPhotoUrls.add(localPath); // Já é uma URL, mantém inalterada
        }
      }

      damageData['photos'] = updatedPhotoUrls;

      // Salva os danos como parte do formulário principal
      await FirebaseFirestore.instance
          .collection('inspection')
          .doc(damageData['formId'])
          .update({
            'damages': FieldValue.arrayUnion([damageData]),
          });

      print('Avaria sincronizada no Firestore: $damageData');
    }

    await prefs.setStringList('pending_damages', remainingDamages);
    print('Todas as avarias pendentes foram sincronizadas.');
  } catch (e) {
    print('Erro ao sincronizar avarias pendentes: $e');
  }
}
