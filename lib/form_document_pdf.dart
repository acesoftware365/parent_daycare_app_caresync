import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class FormPdfBuilder {
  static Future<Uint8List> buildContractPdf({
    required String parentName,
    required String parentEmail,
    required String parentPhone,
    required String parentAddress,
    required String signedName,
    required bool signed,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (_) => [
          _header(
            'Daycare Contract',
            signed ? 'Signed contract on file' : 'Pending signature',
          ),
          _detailCard([
            _detail('Parent Name', parentName),
            _detail('Email', parentEmail),
            _detail('Phone', parentPhone),
            _detail('Address', parentAddress),
            _detail('Signed Name', signedName),
            _detail('Status', signed ? 'Signed' : 'Pending'),
            _detail('Signed At', _formatDate(signedAt)),
          ]),
          _bodyCard(
            'This daycare contract confirms that the parent agrees to the daycare handbook, tuition expectations, attendance policy, emergency procedures, approved release rules, and standard communication used by CareSync for family records.',
          ),
          _signatureSection(signaturePoints),
        ],
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildPhotoPermissionPdf({
    required String parentName,
    required String parentEmail,
    required String parentPhone,
    required String parentAddress,
    required String childName,
    required String signedName,
    required bool signed,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (_) => [
          _header(
            'Photo & Media Permission',
            signed
                ? '$childName permission signed'
                : '$childName permission pending',
          ),
          _detailCard([
            _detail('Parent Name', parentName),
            _detail('Email', parentEmail),
            _detail('Phone', parentPhone),
            _detail('Address', parentAddress),
            _detail('Child', childName),
            _detail('Permission', signed ? 'Granted' : 'Pending'),
            _detail('Signed Name', signedName),
            _detail('Signed At', _formatDate(signedAt)),
          ]),
          _bodyCard(
            'I authorize the daycare to capture and share approved photos or classroom updates of my child with the linked parent account in CareSync. I understand this permission is only for parent-facing updates and can be revoked later through the daycare.',
          ),
          _signatureSection(signaturePoints),
        ],
      ),
    );
    return doc.save();
  }

  static pw.PageTheme _theme() => pw.PageTheme(
    margin: const pw.EdgeInsets.all(32),
    theme: pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  static pw.Widget _header(String title, String subtitle) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(18),
        gradient: const pw.LinearGradient(
          colors: [
            PdfColor.fromInt(0xFFF8DDE5),
            PdfColor.fromInt(0xFFD8EBFF),
            PdfColor.fromInt(0xFFDFF5E6),
          ],
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(color: PdfColors.teal800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _detailCard(List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFF8FBFF),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD8E2EC)),
      ),
      child: pw.Column(children: children),
    );
  }

  static pw.Widget _detail(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 96,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromInt(0xFF5F6E7A),
              ),
            ),
          ),
          pw.Expanded(child: pw.Text(value.trim().isEmpty ? '-' : value)),
        ],
      ),
    );
  }

  static pw.Widget _bodyCard(String text) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 16),
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFDF7E8),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromInt(0xFFEADDBB)),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(lineSpacing: 4, color: PdfColors.blueGrey800),
      ),
    );
  }

  static pw.Widget _signatureSection(List<String> encodedPoints) {
    final svg = _signatureSvg(encodedPoints);
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Stored Signature',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (svg != null)
            pw.Container(
              height: 160,
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FBFF),
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD8E2EC)),
              ),
              child: pw.SvgImage(svg: svg),
            )
          else
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFF8FBFF),
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: PdfColor.fromInt(0xFFD8E2EC)),
              ),
              child: pw.Text(
                'No signature has been saved yet.',
                style: const pw.TextStyle(color: PdfColors.blueGrey500),
              ),
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return '-';
    return DateFormat('M/d/y h:mm a').format(value);
  }

  static String? _signatureSvg(List<String> encodedPoints) {
    final points = _decodeSignaturePoints(encodedPoints);
    if (!points.any((point) => point != null)) return null;
    final actual = points.whereType<Offset>().toList();
    final minX = actual.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
    final maxX = actual.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
    final minY = actual.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
    final maxY = actual.map((p) => p.dy).reduce((a, b) => a > b ? a : b);
    const width = 520.0;
    const height = 160.0;
    const pad = 12.0;
    final scaleX =
        (width - (pad * 2)) / ((maxX - minX).abs() < 1 ? 1 : (maxX - minX));
    final scaleY =
        (height - (pad * 2)) / ((maxY - minY).abs() < 1 ? 1 : (maxY - minY));
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final buffer = StringBuffer();
    Offset? previous;
    for (final point in points) {
      if (point == null) {
        previous = null;
        continue;
      }
      final x = pad + ((point.dx - minX) * scale);
      final y = pad + ((point.dy - minY) * scale);
      if (previous == null) {
        buffer.write('M ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ');
      } else {
        buffer.write('L ${x.toStringAsFixed(2)} ${y.toStringAsFixed(2)} ');
      }
      previous = point;
    }
    return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $width $height">
  <rect x="0" y="0" width="$width" height="$height" rx="14" ry="14" fill="#F8FBFF"/>
  <path d="${buffer.toString().trim()}" fill="none" stroke="#2F6F6B" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>
</svg>
''';
  }

  static List<Offset?> _decodeSignaturePoints(List<String> raw) {
    final out = <Offset?>[];
    for (final item in raw) {
      if (item == 'BREAK') {
        out.add(null);
        continue;
      }
      final parts = item.split(',');
      if (parts.length != 2) continue;
      final x = double.tryParse(parts[0]);
      final y = double.tryParse(parts[1]);
      if (x != null && y != null) {
        out.add(Offset(x, y));
      }
    }
    return out;
  }
}
