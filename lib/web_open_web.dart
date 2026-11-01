import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// เปิดไฟล์ในแท็บใหม่ผ่าน Blob URL (Safari บน iPad ไม่ยอมเปิด data: URL)
Future<void> openBytesInBrowser(Uint8List bytes, String mime, String name) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
}
