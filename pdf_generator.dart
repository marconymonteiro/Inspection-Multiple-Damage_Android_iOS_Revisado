import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class PdfGenerator {
  // Método auxiliar para carregar ícones
  Future<pw.MemoryImage> _loadIcon(String assetPath) async {
    final iconBytes = await rootBundle.load(assetPath);
    return pw.MemoryImage(iconBytes.buffer.asUint8List());
  }

  // Formata a data do relatório
  String _formatReportDate(String reportDate) {
    try {
      final parsedDate = DateFormat('dd/MM/yyyy HH:mm').parse(reportDate);
      return DateFormat('dd/MM/yyyy HH:mm').format(parsedDate);
    } catch (e) {
      return reportDate; // Retorna original em caso de erro
    }
  }

  // Cria uma seção de fotos com título
  pw.Widget _buildPhotoSection(String title, List<pw.MemoryImage> images) {
    if (images.isEmpty) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 10,
          runSpacing: 10,
          children: images.map((image) {
            return pw.Image(image, width: 180, height: 180);
          }).toList(),
        ),
        pw.SizedBox(height: 20),
      ],
    );
  }

  // Baixa uma imagem de uma URL de forma assíncrona
  Future<Uint8List> _downloadImage(String url) async {
    try {
      print('Baixando imagem da URL: $url'); // Log para verificar a URL
      final response = await http.get(Uri.parse(url)); // Aguarda a resposta
      if (response.statusCode == 200) {
        print('Imagem baixada com sucesso: $url'); // Log para confirmar o sucesso
        return Uint8List.fromList(response.bodyBytes); // Converte para Uint8List
      } else {
        throw Exception('Erro ao baixar imagem: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao baixar imagem: $e'); // Log para capturar erros
      throw Exception('Erro ao baixar imagem: $e');
    }
  }

  // Cria uma seção de informações formatada em tabela
  pw.Widget _buildTableSection(List<List<String>> data) {
    return pw.Table.fromTextArray(
      headers: ['Item', 'Informação'],
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
      cellAlignment: pw.Alignment.centerLeft,
      columnWidths: {0: pw.FixedColumnWidth(180), 1: pw.FlexColumnWidth()},
      cellHeight: 25,
      cellStyle: pw.TextStyle(fontSize: 12),
    );
  }

  // Gera um arquivo PDF com base nos dados fornecidos
  Future<File> generatePdf({
    required String name,
    required String cpfResp,
    required String serialNumber,
    required String invoiceNumber,
    required String reportDate,
    required String placaCarreta,
    required String equipment,
    required String freight,
    required String plate,
    required String driverID,
    required String nameResp,
    required String invoiceQtty,
    required String invoiceItems,
    required bool hasDamage,
    required String damageDescription,
    required List<File> photosCarga,
    required List<File> photosAcomodacao,
    required List<File> photosCalcamento,
    required List<File> photosAmarracao,
    required List<Map<String, dynamic>> damagesData,
    required File? photoPlaqueta,
    required File? signatureImage,
  }) async {
    final pdf = pw.Document();
    final emissionDateTime = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    try {
      // Carregar a logo e ícones da empresa
      final logoImage = await _loadIcon('assets/logo_cliente.png');
      final emailIcon = await _loadIcon('assets/email_icon.png');
      final locationIcon = await _loadIcon('assets/location_icon.png');
      final phoneIcon = await _loadIcon('assets/phone_icon.png');
      final instagramIcon = await _loadIcon('assets/instagram_icon.png');
      final websiteIcon = await _loadIcon('assets/website_icon.png');

    // Pré-carregar as imagens das URLs dos danos
    final Map<String, List<pw.MemoryImage>> damageImagesMap = {};
      for (var damage in damagesData) {
        final List<pw.MemoryImage> damageImages = [];

        // Verifica se 'photos' existe e converte para List<String>
        if (damage['photos'] != null) {
          try {
            final List<String> photoUrls = List<String>.from(damage['photos']);
            print('Processando dano: ${damage['description']}');
            print('URLs das fotos: $photoUrls');

            for (var url in photoUrls) {
              try {
                print('Baixando imagem da URL: $url');
                final imageBytes = await _downloadImage(url);
                damageImages.add(pw.MemoryImage(imageBytes));
                print('Imagem baixada com sucesso: $url');
              } catch (e) {
                print('Erro ao baixar imagem do dano: $e');
              }
            }
          } catch (e) {
            print('Erro ao converter fotos do dano: $e');
          }
        } else {
          print('Fotos do dano não encontradas ou nulas.');
        }

        damageImagesMap[damage['description'] ?? 'Sem descrição'] = damageImages;
        print('Imagens carregadas para o dano: ${damage['description']} - ${damageImages.length} imagens');
    }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Cabeçalho
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Image(logoImage, width: 60, height: 60),
                      pw.Text('Relatório de Inspeção', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Divider(),
                ],
              ),
              pw.SizedBox(height: 20),

              // Informações Gerais
              pw.Text('Informações do Serviço', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildTableSection([
                ['Data do Relatório', _formatReportDate(reportDate)],
                ['Placa da Carreta', placaCarreta],
                ['Equipamento', equipment],
                ['Transportadora', freight],
                ['Placa do Cavalo', plate],
                ['Nome', name],
                ['CPF', driverID],
                ['Número de Série', serialNumber],
                ['Nota Fiscal', invoiceNumber],
                ['Volumes Totais na NF', invoiceQtty],
                ['Volumes de Partes/Peças', invoiceItems],
              ]),
              pw.SizedBox(height: 20),

              // Fotos
              if (photoPlaqueta != null)
              _buildPhotoSection('Foto da Plaqueta', [pw.MemoryImage(photoPlaqueta.readAsBytesSync())]),
              _buildPhotoSection('Fotos da Carga', photosCarga.map((file) => pw.MemoryImage(file.readAsBytesSync())).toList()),
              _buildPhotoSection('Fotos da Amarração', photosAmarracao.map((file) => pw.MemoryImage(file.readAsBytesSync())).toList()),
              _buildPhotoSection('Fotos da Acomodação', photosAcomodacao.map((file) => pw.MemoryImage(file.readAsBytesSync())).toList()),
              _buildPhotoSection('Fotos do Calçamento', photosCalcamento.map((file) => pw.MemoryImage(file.readAsBytesSync())).toList()),

              // Dados da Aprovação
              pw.Text('Dados da Aprovação do Carregamento', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _buildTableSection([
                ['Nome do Aprovador', nameResp],
                ['CPF do Aprovador', cpfResp],
              ]),
              pw.SizedBox(height: 10),

              if (signatureImage != null)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Assinatura do Aprovador', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    pw.Image(pw.MemoryImage(signatureImage.readAsBytesSync()), width: 200, height: 100),
                  ],
                ),

              // Danos Registrados
              if (hasDamage && damagesData.isNotEmpty)
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: damagesData.map((damage) {
                    print('Exibindo danos no PDF...'); // Log para confirmar a exibição
                    final description = damage['description'] ?? 'Sem descrição';
                    final images = damageImagesMap[description] ?? [];
                    print('Dano: $description - ${images.length} imagens');
                    return _buildPhotoSection('Dano: $description', images);
                  }).toList(),
                ),

              // Rodapé
              pw.Text('Relatório emitido em $emissionDateTime', style: pw.TextStyle(fontSize: 12, fontStyle: pw.FontStyle.italic, color: PdfColors.grey700)),
              pw.SizedBox(height: 20),
              _buildContactCard(emailIcon, locationIcon, phoneIcon, instagramIcon, websiteIcon),
            ];
          },
        ),
      );

      // Salvar o PDF
      final outputDir = await getApplicationDocumentsDirectory();
      final formattedDate = DateFormat('dd-MM-yyyy_HHmm').format(DateTime.now());
      final outputFile = File('${outputDir.path}/IronMaquinas_${serialNumber}_${invoiceNumber}_$formattedDate.pdf');
      await outputFile.writeAsBytes(await pdf.save());

      return outputFile;
    } catch (e) {
      throw Exception('Erro ao gerar PDF: $e');
    }
  }

  // Método para construir o cartão de contato
  pw.Widget _buildContactCard(
    pw.MemoryImage emailIcon,
    pw.MemoryImage locationIcon,
    pw.MemoryImage phoneIcon,
    pw.MemoryImage instagramIcon,
    pw.MemoryImage websiteIcon,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [pw.Image(emailIcon, width: 16), pw.SizedBox(width: 8), pw.Text('contato@ironmaquinas.com.br')]),
        pw.Row(children: [pw.Image(locationIcon, width: 16), pw.SizedBox(width: 8), pw.Text('Av. Augusto Ruschi, 1210. Balneário de Carapebus, Serra - ES, 29164-830')]),
        pw.Row(children: [pw.Image(phoneIcon, width: 16), pw.SizedBox(width: 8), pw.Text('+55 27 90000-0000')]),
        pw.Row(children: [pw.Image(instagramIcon, width: 16), pw.SizedBox(width: 8), pw.Text('@ironmaquinas')]),
        pw.Row(children: [pw.Image(websiteIcon, width: 16), pw.SizedBox(width: 8), pw.Text('ironmaquinas.com.br')]),
      ],
    );
  }
}
