// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> openPdfInNewTab(Uint8List bytes, String fileName) async {
  final blob = html.Blob(<dynamic>[bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final link = html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener noreferrer';
  link.click();
  return true;
}
