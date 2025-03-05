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

  // Verifica se há conexão com a internet
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    print('Sem conexão com a internet. Tentará novamente mais tarde.');
    return;
  }

  if (savedForms.isNotEmpty) {
    final firestore = FirebaseFirestore.instance;

    for (String form in savedForms) {
      try {
        // Decodifica o formulário salvo
        Map<String, dynamic> formData = jsonDecode(form);
        String formId = formData['formId'] ?? DateTime.now().millisecondsSinceEpoch.toString();

        // Processa as fotos
        List<dynamic> photosAcomodacao = formData['photosAcomodacao'] ?? [];
        List<dynamic> photosCalcamento = formData['photosCalcamento'] ?? [];
        List<dynamic> photosAmarracao = formData['photosAmarracao'] ?? [];
        String? photoPlaquetaPath = formData['photoPlaqueta'];
        String? signatureImagePath = formData['signatureImage'];

        List<String> uploadedPhotosAcomodacao = [];
        List<String> uploadedPhotosCalcamento = [];
        List<String> uploadedPhotosAmarracao = [];
        String? uploadedPhotoPlaqueta;
        String? uploadedSignatureImage;

        // Faz o upload das fotos de acomodação
        for (var path in photosAcomodacao) {
          File file = File(path);
          String? url = await uploadImage(file, "acomodacao");
          if (url != null) uploadedPhotosAcomodacao.add(url);
        }

        // Faz o upload das fotos de calcamento
        for (var path in photosCalcamento) {
          File file = File(path);
          String? url = await uploadImage(file, "calcamento");
          if (url != null) uploadedPhotosCalcamento.add(url);
        }

        // Faz o upload das fotos de amarração
        for (var path in photosAmarracao) {
          File file = File(path);
          String? url = await uploadImage(file, "amarracao");
          if (url != null) uploadedPhotosAmarracao.add(url);
        }

        // Faz o upload da foto da plaqueta
        if (photoPlaquetaPath != null) {
          File file = File(photoPlaquetaPath);
          uploadedPhotoPlaqueta = await uploadImage(file, "plaquetas");
        }

        // Faz o upload da assinatura
        if (signatureImagePath != null) {
          File file = File(signatureImagePath);
          uploadedSignatureImage = await uploadImage(file, "assinaturas");
        }

        // Atualiza os dados do formulário com as URLs das fotos
        formData['photosAcomodacao'] = uploadedPhotosAcomodacao;
        formData['photosCalcamento'] = uploadedPhotosCalcamento;
        formData['photosAmarracao'] = uploadedPhotosAmarracao;
        formData['photoPlaqueta'] = uploadedPhotoPlaqueta;
        formData['signatureImage'] = uploadedSignatureImage;

        // Processa os danos
        List<dynamic> damages = formData['damages'] ?? [];
        for (var damage in damages) {
          List<dynamic> photos = damage['photos'];
          List<String> uploadedUrls = [];
          for (var photoPath in photos) {
            File photoFile = File(photoPath);
            String? url = await uploadImage(photoFile, "danos");
            if (url != null) {
              uploadedUrls.add(url);
            }
          }
          // Atualiza os danos com as URLs
          damage['photos'] = uploadedUrls;
        }

        // Atualiza os dados do formulário
        formData['damages'] = damages;

        // Salva no Firestore
        await FirebaseFirestore.instance.collection('inspection').doc();
        print('Formulário enviado para o Firestore: $formId');
      } catch (e) {
        print('Erro ao enviar formulário para o Firestore: $e');
        return;
      }
    }

    // Após enviar todos os formulários, limpar os dados locais
    await prefs.remove('pending_forms');
    print('Todos os formulários pendentes foram enviados e removidos localmente.');
  }
}
