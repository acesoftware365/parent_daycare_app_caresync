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
    required String languageCode,
    required String daycareName,
    required String daycareAddress,
    required String daycarePhone,
    required String childName,
    required String childDateOfBirthText,
    required String parentGuardianName,
    required bool internalCommunicationApproved,
    required bool publicWebsiteApproved,
    required String signedName,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) async {
    final isSpanish = languageCode == 'es';
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageTheme: _theme(),
        build: (_) => _photoPermissionTemplate(
          isSpanish: isSpanish,
          daycareName: daycareName,
          daycareAddress: daycareAddress,
          daycarePhone: daycarePhone,
          childName: childName,
          childDateOfBirthText: childDateOfBirthText,
          parentGuardianName: parentGuardianName,
          internalCommunicationApproved: internalCommunicationApproved,
          publicWebsiteApproved: publicWebsiteApproved,
          signedName: signedName,
          signedAt: signedAt,
          signaturePoints: signaturePoints,
        ),
      ),
    );
    return doc.save();
  }

  static Future<Uint8List> buildEnrollmentFormPdf({
    required String languageCode,
    required String daycareName,
    required String dateOfApplicationText,
    required String dateOfEnrollmentText,
    required String lastDayOfEnrollmentText,
    required String childName,
    required String childDateOfBirthText,
    required String childGender,
    required String childStreetAddress,
    required String childCity,
    required String childState,
    required String childZipCode,
    required String parent1Name,
    required String parent1Address,
    required String parent1City,
    required String parent1ZipCode,
    required String parent1HomePhone,
    required String parent1CellPhone,
    required String parent1EmergencyPhone,
    required String parent1Email,
    required String parent1Employer,
    required String parent1EmployerWorkPhone,
    required String parent1EmployerAddress,
    required String parent1EmployerCity,
    required String parent1EmployerZipCode,
    required String parent2Name,
    required String parent2Address,
    required String parent2City,
    required String parent2ZipCode,
    required String parent2HomePhone,
    required String parent2CellPhone,
    required String parent2EmergencyPhone,
    required String parent2Email,
    required String parent2Employer,
    required String parent2EmployerWorkPhone,
    required String parent2EmployerAddress,
    required String parent2EmployerCity,
    required String parent2EmployerZipCode,
    required String primaryLanguage,
    required String contact1Name,
    required String contact1Relationship,
    required String contact1Phone,
    required String contact2Name,
    required String contact2Relationship,
    required String contact2Phone,
    required String restrictedPickupNotes,
    required String pediatricianName,
    required String pediatricianPhone,
    required String preferredHospital,
    required String allergyNotes,
    required String medicationNotes,
    required String signedName,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageTheme: _theme(),
        build: (_) => _enrollmentTemplate(
          daycareName: daycareName,
          dateOfApplicationText: dateOfApplicationText,
          dateOfEnrollmentText: dateOfEnrollmentText,
          lastDayOfEnrollmentText: lastDayOfEnrollmentText,
          childName: childName,
          childDateOfBirthText: childDateOfBirthText,
          childGender: childGender,
          childStreetAddress: childStreetAddress,
          childCity: childCity,
          childState: childState,
          childZipCode: childZipCode,
          parent1Name: parent1Name,
          parent1Address: parent1Address,
          parent1City: parent1City,
          parent1ZipCode: parent1ZipCode,
          parent1HomePhone: parent1HomePhone,
          parent1CellPhone: parent1CellPhone,
          parent1EmergencyPhone: parent1EmergencyPhone,
          parent1Email: parent1Email,
          parent1Employer: parent1Employer,
          parent1EmployerWorkPhone: parent1EmployerWorkPhone,
          parent1EmployerAddress: parent1EmployerAddress,
          parent1EmployerCity: parent1EmployerCity,
          parent1EmployerZipCode: parent1EmployerZipCode,
          parent2Name: parent2Name,
          parent2Address: parent2Address,
          parent2City: parent2City,
          parent2ZipCode: parent2ZipCode,
          parent2HomePhone: parent2HomePhone,
          parent2CellPhone: parent2CellPhone,
          parent2EmergencyPhone: parent2EmergencyPhone,
          parent2Email: parent2Email,
          parent2Employer: parent2Employer,
          parent2EmployerWorkPhone: parent2EmployerWorkPhone,
          parent2EmployerAddress: parent2EmployerAddress,
          parent2EmployerCity: parent2EmployerCity,
          parent2EmployerZipCode: parent2EmployerZipCode,
          primaryLanguage: primaryLanguage,
          contact1Name: contact1Name,
          contact1Relationship: contact1Relationship,
          contact1Phone: contact1Phone,
          contact2Name: contact2Name,
          contact2Relationship: contact2Relationship,
          contact2Phone: contact2Phone,
          restrictedPickupNotes: restrictedPickupNotes,
          pediatricianName: pediatricianName,
          pediatricianPhone: pediatricianPhone,
          preferredHospital: preferredHospital,
          allergyNotes: allergyNotes,
          medicationNotes: medicationNotes,
          signedName: signedName,
          signedAt: signedAt,
          signaturePoints: signaturePoints,
        ),
      ),
    );
    return doc.save();
  }

  static pw.PageTheme _theme() => pw.PageTheme(
    pageFormat: PdfPageFormat.letter,
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

  static pw.Widget _photoPermissionTemplate({
    required bool isSpanish,
    required String daycareName,
    required String daycareAddress,
    required String daycarePhone,
    required String childName,
    required String childDateOfBirthText,
    required String parentGuardianName,
    required bool internalCommunicationApproved,
    required bool publicWebsiteApproved,
    required String signedName,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          isSpanish
              ? 'FORMULARIO DE CONSENTIMIENTO DE FOTOS Y MEDIOS'
              : 'DAYCARE PHOTO & MEDIA CONSENT FORM',
          style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _detail(isSpanish ? 'Nombre del Daycare' : 'Daycare Name', daycareName),
        _detail(isSpanish ? 'Dirección' : 'Address', daycareAddress),
        _detail(isSpanish ? 'Teléfono' : 'Phone', daycarePhone),
        pw.SizedBox(height: 8),
        _sectionHeading(
          isSpanish
              ? 'SECCIÓN 1: INFORMACIÓN DEL NIÑO(A)'
              : 'SECTION 1: CHILD INFORMATION',
        ),
        pw.SizedBox(height: 5),
        _detail(
          isSpanish ? 'Nombre Completo del Niño(a)' : 'Child\'s Full Name',
          childName,
        ),
        _detail(
          isSpanish ? 'Fecha de Nacimiento' : 'Date of Birth',
          childDateOfBirthText,
        ),
        _detail(
          isSpanish ? 'Nombre del Padre/Tutor' : 'Parent/Guardian Name',
          parentGuardianName,
        ),
        pw.SizedBox(height: 8),
        _sectionHeading(
          isSpanish
              ? 'SECCIÓN 2: DECLARACIÓN DE CONSENTIMIENTO'
              : 'SECTION 2: STATEMENT OF CONSENT',
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          isSpanish
              ? 'En cumplimiento con las pautas establecidas por la Oficina de Primera Infancia de Connecticut (OEC), ${daycareName.isEmpty ? 'el daycare' : daycareName} requiere el consentimiento explícito por escrito de un padre o tutor legal para tomar y utilizar fotografías o videos de su hijo/a.'
              : 'In compliance with the guidelines set forth by the Connecticut Office of Early Childhood (OEC), ${daycareName.isEmpty ? 'the daycare' : daycareName} requires explicit written consent from a parent or legal guardian to take and use photographs or videos of your child.',
          style: const pw.TextStyle(fontSize: 9.2, lineSpacing: 2),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          isSpanish
              ? 'Nos encanta compartir con usted los logros y actividades diarias de su hijo/a, y también nos gusta celebrar nuestra comunidad en línea. Por favor, revise las opciones a continuación e indique sus preferencias. Puede actualizar este permiso en cualquier momento solicitando un nuevo formulario.'
              : 'We love sharing your child\'s milestones and daily activities with you, and we also like to celebrate our daycare community online. Please review the options below and indicate your preferences. You may update this consent at any time by requesting a new form.',
          style: const pw.TextStyle(fontSize: 9.2, lineSpacing: 2),
        ),
        pw.SizedBox(height: 8),
        _sectionHeading(
          isSpanish
              ? 'SECCIÓN 3: OPCIONES DE PERMISO'
              : 'SECTION 3: PERMISSION OPTIONS',
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          isSpanish
              ? '(Por favor marque "SÍ" o "NO" en cada opción)'
              : '(Please check "YES" or "NO" for each item)',
          style: const pw.TextStyle(fontSize: 9.2),
        ),
        pw.SizedBox(height: 5),
        _permissionOption(
          title: isSpanish
              ? '1. Comunicación Interna (Actualizaciones para los padres)'
              : '1. Internal Communication (Updates to Parents)',
          body: isSpanish
              ? 'Doy permiso para que se tomen fotos/videos de mi hijo/a durante las actividades diarias y se compartan directamente conmigo y otros padres del programa (ej. a través de una aplicación segura del daycare, correo electrónico directo o manualidades impresas en el aula).'
              : 'I give permission for my child\'s photo/video to be taken during daily activities and shared directly with me and other parents within the program (e.g., via a secure daycare app, direct email, or printed classroom crafts).',
          approved: internalCommunicationApproved,
          isSpanish: isSpanish,
        ),
        pw.SizedBox(height: 6),
        _permissionOption(
          title: isSpanish
              ? '2. Redes Sociales y Página Web Pública'
              : '2. Social Media & Public Website',
          body: isSpanish
              ? 'Doy permiso para que la foto/video de mi hijo/a se utilice en las páginas oficiales de redes sociales del daycare (Facebook, Instagram, etc.) y en la página web pública con fines promocionales y comunitarios. (Nota de privacidad: NUNCA se publicarán los nombres completos de los niños en internet).'
              : 'I give permission for my child\'s photo/video to be used on the daycare\'s official social media pages (Facebook, Instagram, etc.) and public website for promotional and community purposes. (Privacy Note: Children\'s full names will NEVER be posted publicly).',
          approved: publicWebsiteApproved,
          isSpanish: isSpanish,
        ),
        pw.SizedBox(height: 8),
        _sectionHeading(
          isSpanish ? 'SECCIÓN 4: FIRMA' : 'SECTION 4: SIGNATURE',
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          isSpanish
              ? 'Al firmar a continuación, confirmo que soy el padre o tutor legal del niño/a nombrado anteriormente y que he elegido los permisos marcados. Entiendo que este formulario se mantendrá en el archivo oficial de mi hijo/a.'
              : 'By signing below, I confirm that I am the legal parent or guardian of the child named above and that I have chosen the permissions as marked. I understand that this form will be kept on file in my child\'s official records.',
          style: const pw.TextStyle(fontSize: 9.2, lineSpacing: 2),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          isSpanish ? 'Firma del Padre o Tutor:' : 'Parent/Guardian Signature:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        _signatureSection(signaturePoints),
        pw.SizedBox(height: 4),
        pw.Text(
          signedName.trim().isEmpty ? '-' : signedName,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _detail(isSpanish ? 'Fecha' : 'Date', _formatDate(signedAt)),
      ],
    );
  }

  static List<pw.Widget> _enrollmentTemplate({
    required String daycareName,
    required String dateOfApplicationText,
    required String dateOfEnrollmentText,
    required String lastDayOfEnrollmentText,
    required String childName,
    required String childDateOfBirthText,
    required String childGender,
    required String childStreetAddress,
    required String childCity,
    required String childState,
    required String childZipCode,
    required String parent1Name,
    required String parent1Address,
    required String parent1City,
    required String parent1ZipCode,
    required String parent1HomePhone,
    required String parent1CellPhone,
    required String parent1EmergencyPhone,
    required String parent1Email,
    required String parent1Employer,
    required String parent1EmployerWorkPhone,
    required String parent1EmployerAddress,
    required String parent1EmployerCity,
    required String parent1EmployerZipCode,
    required String parent2Name,
    required String parent2Address,
    required String parent2City,
    required String parent2ZipCode,
    required String parent2HomePhone,
    required String parent2CellPhone,
    required String parent2EmergencyPhone,
    required String parent2Email,
    required String parent2Employer,
    required String parent2EmployerWorkPhone,
    required String parent2EmployerAddress,
    required String parent2EmployerCity,
    required String parent2EmployerZipCode,
    required String primaryLanguage,
    required String contact1Name,
    required String contact1Relationship,
    required String contact1Phone,
    required String contact2Name,
    required String contact2Relationship,
    required String contact2Phone,
    required String restrictedPickupNotes,
    required String pediatricianName,
    required String pediatricianPhone,
    required String preferredHospital,
    required String allergyNotes,
    required String medicationNotes,
    required String signedName,
    required DateTime? signedAt,
    required List<String> signaturePoints,
  }) {
    return [
      pw.Text(
        'CHILD ENROLLMENT FORM',
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      _detail('Date of Application', dateOfApplicationText),
      _detail('Date of Enrollment', dateOfEnrollmentText),
      _detail('Last Day of Enrollment', lastDayOfEnrollmentText),
      pw.SizedBox(height: 12),
      _detail(
        'Attention Provider',
        'This information must be kept current at all times and shall be kept file for one year after the child ceases to be enrolled in the family child care home.',
      ),
      pw.SizedBox(height: 8),
      _detail('Daycare Name', daycareName),
      pw.SizedBox(height: 10),
      _sectionHeading('CHILD INFORMATION'),
      pw.SizedBox(height: 6),
      _detail('Child’s Name', childName),
      _detail('Child’s Date of Birth', childDateOfBirthText),
      _detail('Gender', childGender),
      _detail('Child’s Address', childStreetAddress),
      _detail('City', childCity),
      _detail('State', childState),
      _detail('Zip Code', childZipCode),
      _detail('Primary Language Spoken at Home', primaryLanguage),
      pw.SizedBox(height: 10),
      _sectionHeading('PARENT / GUARDIAN INFORMATION'),
      pw.SizedBox(height: 6),
      _detail('Parent/Guardian Name', parent1Name),
      _detail('Address', parent1Address),
      _detail('City', parent1City),
      _detail('Zip Code', parent1ZipCode),
      _detail('Home Telephone #', parent1HomePhone),
      _detail('Cell #', parent1CellPhone),
      _detail('Emergency Contact #', parent1EmergencyPhone),
      _detail('e-mail Address', parent1Email),
      _detail('Employer', parent1Employer),
      _detail('Work #', parent1EmployerWorkPhone),
      _detail('Employer’s Address', parent1EmployerAddress),
      _detail('City', parent1EmployerCity),
      _detail('Zip Code', parent1EmployerZipCode),
      pw.SizedBox(height: 8),
      _detail('Parent/Guardian Name', parent2Name),
      _detail('Address', parent2Address),
      _detail('City', parent2City),
      _detail('Zip Code', parent2ZipCode),
      _detail('Home Telephone #', parent2HomePhone),
      _detail('Cell #', parent2CellPhone),
      _detail('Emergency Contact #', parent2EmergencyPhone),
      _detail('e-mail Address', parent2Email),
      _detail('Employer', parent2Employer),
      _detail('Work #', parent2EmployerWorkPhone),
      _detail('Employer’s Address', parent2EmployerAddress),
      _detail('City', parent2EmployerCity),
      _detail('Zip Code', parent2EmployerZipCode),
      pw.SizedBox(height: 10),
      _sectionHeading('EMERGENCY CONTACTS & AUTHORIZED PICK-UP'),
      pw.SizedBox(height: 4),
      pw.SizedBox(height: 6),
      _detail('Contact 1 Name', contact1Name),
      _detail('Relationship', contact1Relationship),
      _detail('Phone Number', contact1Phone),
      pw.SizedBox(height: 6),
      _detail('Contact 2 Name', contact2Name),
      _detail('Relationship', contact2Relationship),
      _detail('Phone Number', contact2Phone),
      pw.SizedBox(height: 6),
      _detail('Not Allowed Pickup', restrictedPickupNotes),
      pw.SizedBox(height: 10),
      _sectionHeading('MEDICAL INFORMATION'),
      pw.SizedBox(height: 6),
      _detail('Pediatrician’s Name', pediatricianName),
      _detail('Phone', pediatricianPhone),
      _detail('Preferred Hospital', preferredHospital),
      _detail('Allergies', allergyNotes),
      _detail('Daily medications or chronic conditions', medicationNotes),
      pw.SizedBox(height: 8),
      _bodyCard(
        'Signature of Parent or Guardian: ${signedName.trim().isEmpty ? '-' : signedName}\nDate: ${_formatDate(signedAt)}',
      ),
      pw.SizedBox(height: 10),
      pw.Text(
        'Saved Signature',
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 6),
      _signatureSection(signaturePoints),
    ];
  }

  static pw.Widget _sectionHeading(String text) {
    return pw.Text(
      text,
      style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _permissionOption({
    required String title,
    required String body,
    required bool approved,
    required bool isSpanish,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(body, style: const pw.TextStyle(fontSize: 9.2, lineSpacing: 2)),
        pw.SizedBox(height: 4),
        pw.Row(
          children: [
            _checkBox(approved),
            pw.SizedBox(width: 6),
            pw.Text(isSpanish ? 'SÍ' : 'YES'),
            pw.SizedBox(width: 18),
            _checkBox(!approved),
            pw.SizedBox(width: 6),
            pw.Text('NO'),
          ],
        ),
      ],
    );
  }

  static pw.Widget _checkBox(bool checked) {
    return pw.Container(
      width: 12,
      height: 12,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black),
      ),
      child: checked
          ? pw.Text('X', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))
          : null,
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
              height: 76,
              width: double.infinity,
              padding: const pw.EdgeInsets.all(6),
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
              padding: const pw.EdgeInsets.all(10),
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
