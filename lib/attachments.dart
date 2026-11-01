import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'blob_store.dart';
import 'models.dart';
import 'web_open_stub.dart' if (dart.library.js_interop) 'web_open_web.dart';

/// บนเว็บ/iPad (PWA) เก็บไฟล์ใน IndexedDB จำกัดไฟล์ละ 25 MB
const _webMaxBytes = 25 * 1024 * 1024;

const _imageExts = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp'};

// ---------------- เพิ่ม / เปิด / ลบ ----------------

class AttachmentService {
  static final _imagePicker = ImagePicker();

  static Future<Attachment?> _store(
      String name, AttachKind kind, Uint8List? bytes, String? srcPath) async {
    final id = newId();
    if (kIsWeb) {
      if (bytes == null) return null;
      if (bytes.length > _webMaxBytes) {
        throw Exception('ไฟล์ใหญ่เกิน 25 MB ใส่เป็นลิงก์ (เช่น Google Drive) แทน');
      }
      await BlobStore.put(id, bytes);
      return Attachment(id: id, kind: kind, name: name, path: 'idb:$id');
    }
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/media');
    await dir.create(recursive: true);
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dest = '${dir.path}/${id}_$safe';
    if (srcPath != null) {
      await File(srcPath).copy(dest);
    } else if (bytes != null) {
      await File(dest).writeAsBytes(bytes);
    } else {
      return null;
    }
    return Attachment(id: id, kind: kind, name: name, path: dest);
  }

  static Future<List<Attachment>> pickImages({required bool camera}) async {
    final out = <Attachment>[];
    final files = camera
        ? [
            await _imagePicker.pickImage(
                source: ImageSource.camera, maxWidth: 2000, imageQuality: 80)
          ].whereType<XFile>().toList()
        : await _imagePicker.pickMultiImage(maxWidth: 2000, imageQuality: 80);
    for (final f in files) {
      final a = await _store(f.name, AttachKind.image,
          kIsWeb ? await f.readAsBytes() : null, kIsWeb ? null : f.path);
      if (a != null) out.add(a);
    }
    return out;
  }

  static Future<List<Attachment>> pickFiles() async {
    final res = await FilePicker.pickFiles(allowMultiple: true, withData: kIsWeb);
    if (res == null) return [];
    final out = <Attachment>[];
    for (final f in res.files) {
      final ext = (f.extension ?? '').toLowerCase();
      final kind = _imageExts.contains(ext) ? AttachKind.image : AttachKind.file;
      final a = await _store(f.name, kind, f.bytes, kIsWeb ? null : f.path);
      if (a != null) out.add(a);
    }
    return out;
  }

  static Attachment link(String url, String name) {
    var u = url.trim();
    if (!u.contains('://')) u = 'https://$u';
    return Attachment(
        id: newId(),
        kind: AttachKind.link,
        name: name.trim().isEmpty ? _niceLinkName(u) : name.trim(),
        url: u);
  }

  static String _niceLinkName(String u) {
    final host = Uri.tryParse(u)?.host ?? u;
    if (host.contains('youtu')) return 'วิดีโอ YouTube';
    if (host.contains('docs.google') || host.contains('drive.google')) {
      return 'Google Drive';
    }
    if (host.contains('canva')) return 'Canva';
    return host.replaceFirst('www.', '');
  }

  static Future<Uint8List?> bytesOf(Attachment a) async {
    if (a.dataB64 != null) return base64Decode(a.dataB64!);
    if (a.path?.startsWith('idb:') ?? false) return BlobStore.get(a.path!.substring(4));
    return null;
  }

  static Future<void> delete(Attachment a) async {
    if (a.path?.startsWith('idb:') ?? false) {
      await BlobStore.delete(a.path!.substring(4));
      return;
    }
    if (!kIsWeb && a.path != null) {
      try {
        await File(a.path!).delete();
      } catch (_) {}
    }
  }

  static Future<void> open(BuildContext context, Attachment a,
      {List<Attachment> gallery = const []}) async {
    switch (a.kind) {
      case AttachKind.link:
        await launchUrl(Uri.parse(a.url!), mode: LaunchMode.externalApplication);
      case AttachKind.image:
        final images = gallery.where((x) => x.kind == AttachKind.image).toList();
        if (images.isEmpty) images.add(a);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ImageViewer(images: images, initial: images.indexOf(a).clamp(0, images.length - 1)),
          ),
        );
      case AttachKind.file:
        if (kIsWeb) {
          final bytes = await bytesOf(a);
          if (bytes != null) await openBytesInBrowser(bytes, _mime(a.ext), a.name);
        } else if (a.path != null) {
          final r = await OpenFilex.open(a.path!);
          if (r.type != ResultType.done && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('เปิดไฟล์ไม่ได้: ${r.message}')));
          }
        }
    }
  }

  static String _mime(String ext) => switch (ext) {
        'pdf' => 'application/pdf',
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'ppt' => 'application/vnd.ms-powerpoint',
        'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'doc' => 'application/msword',
        'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'mov' => 'video/quicktime',
        'm4a' => 'audio/mp4',
        'mp4' => 'video/mp4',
        'mp3' => 'audio/mpeg',
        'txt' => 'text/plain',
        _ => 'application/octet-stream',
      };
}

/// แสดงรูปที่แนบ (ไฟล์ในเครื่อง หรือ IndexedDB บนเว็บ)
class AttachmentImageView extends StatelessWidget {
  final Attachment a;
  final BoxFit? fit;
  final Color errorColor;
  const AttachmentImageView(this.a,
      {super.key, this.fit, this.errorColor = Colors.grey});

  @override
  Widget build(BuildContext context) {
    Widget err(_, __, ___) => Icon(Icons.broken_image, color: errorColor);
    if (!kIsWeb && a.path != null && !a.path!.startsWith('idb:')) {
      return Image.file(File(a.path!), fit: fit, errorBuilder: err);
    }
    final key = a.path?.startsWith('idb:') ?? false ? a.path!.substring(4) : null;
    final ready = a.dataB64 != null
        ? base64Decode(a.dataB64!)
        : (key == null ? null : BlobStore.peek(key));
    if (ready != null) return Image.memory(ready, fit: fit, errorBuilder: err);
    return FutureBuilder<Uint8List?>(
      future: AttachmentService.bytesOf(a),
      builder: (_, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(
              child: SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)));
        }
        final b = snap.data;
        if (b == null) return Icon(Icons.broken_image, color: errorColor);
        return Image.memory(b, fit: fit, errorBuilder: err);
      },
    );
  }
}

({IconData icon, Color color}) _fileLook(Attachment a) {
  if (a.kind == AttachKind.link) {
    final u = a.url ?? '';
    if (u.contains('youtu')) return (icon: Icons.smart_display, color: Colors.red);
    return (icon: Icons.link, color: Colors.blue);
  }
  return switch (a.ext) {
    'pdf' => (icon: Icons.picture_as_pdf, color: Colors.red.shade700),
    'ppt' || 'pptx' || 'key' => (icon: Icons.slideshow, color: Colors.deepOrange),
    'doc' || 'docx' || 'txt' => (icon: Icons.description, color: Colors.blue.shade700),
    'xls' || 'xlsx' || 'csv' => (icon: Icons.table_chart, color: Colors.green.shade700),
    'mp4' || 'mov' || 'avi' || 'mkv' => (icon: Icons.movie, color: Colors.purple),
    'mp3' || 'wav' || 'm4a' => (icon: Icons.audiotrack, color: Colors.teal),
    _ => (icon: Icons.insert_drive_file, color: Colors.blueGrey),
  };
}

// ---------------- แถบไฟล์แนบ ----------------

/// แสดงไฟล์แนบเป็นแถวเลื่อนได้ แตะเพื่อเปิด กดค้างเพื่อลบ (ถ้า [onRemove] ไม่ว่าง)
class AttachmentStrip extends StatelessWidget {
  final List<Attachment> items;
  final ValueChanged<List<Attachment>>? onAdd;
  final ValueChanged<Attachment>? onRemove;
  final double size;
  final String addLabel;

  const AttachmentStrip({
    super.key,
    required this.items,
    this.onAdd,
    this.onRemove,
    this.size = 64,
    this.addLabel = 'แนบ',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: size + 18,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final a in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Tile(
                a: a,
                size: size,
                onTap: () => AttachmentService.open(context, a, gallery: items),
                onLongPress: onRemove == null
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            content: Text('ลบ "${a.name}"?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('ยกเลิก')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('ลบ')),
                            ],
                          ),
                        );
                        if (ok == true) onRemove!(a);
                      },
              ),
            ),
          if (onAdd != null)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () async {
                final added = await showAddAttachmentSheet(context);
                if (added.isNotEmpty) onAdd!(added);
              },
              child: Column(children: [
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    border: Border.all(color: cs.outlineVariant, width: 1.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.add_photo_alternate_outlined, color: cs.primary),
                ),
                const SizedBox(height: 2),
                Text(addLabel, style: TextStyle(fontSize: 11, color: cs.primary)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Attachment a;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const _Tile(
      {required this.a, required this.size, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final look = _fileLook(a);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        child: Column(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: size,
              height: size,
              color: cs.surfaceContainerHighest,
              child: a.kind == AttachKind.image
                  ? AttachmentImageView(a, fit: BoxFit.cover)
                  : Icon(look.icon, color: look.color, size: size * 0.45),
            ),
          ),
          const SizedBox(height: 2),
          Text(a.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11)),
        ]),
      ),
    );
  }
}

/// เมนูเลือกว่าจะแนบอะไร: ถ่ายรูป / รูปในเครื่อง / ไฟล์ / ลิงก์
Future<List<Attachment>> showAddAttachmentSheet(BuildContext context) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (!kIsWeb)
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('ถ่ายรูป'),
            subtitle: const Text('เช่น กระดาน ใบงาน ผลงานนักเรียน'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('เลือกรูปจากเครื่อง'),
          onTap: () => Navigator.pop(ctx, 'gallery'),
        ),
        ListTile(
          leading: const Icon(Icons.attach_file),
          title: const Text('เลือกไฟล์'),
          subtitle: const Text('PDF, สไลด์, ใบงาน, วิดีโอ, เสียง'),
          onTap: () => Navigator.pop(ctx, 'file'),
        ),
        ListTile(
          leading: const Icon(Icons.link),
          title: const Text('ใส่ลิงก์'),
          subtitle: const Text('YouTube, Google Slides, Canva, เว็บไซต์'),
          onTap: () => Navigator.pop(ctx, 'link'),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return [];
  try {
    switch (choice) {
      case 'camera':
        return await AttachmentService.pickImages(camera: true);
      case 'gallery':
        return await AttachmentService.pickImages(camera: false);
      case 'file':
        return await AttachmentService.pickFiles();
      case 'link':
        final a = await _askLink(context);
        return a == null ? [] : [a];
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }
  return [];
}

Future<Attachment?> _askLink(BuildContext context) {
  final url = TextEditingController();
  final name = TextEditingController();
  return showDialog<Attachment>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('ใส่ลิงก์'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: url,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
              labelText: 'ลิงก์', hintText: 'https://youtu.be/...'),
        ),
        TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'ชื่อ (ไม่ใส่ก็ได้)'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () => Navigator.pop(
              ctx,
              url.text.trim().isEmpty
                  ? null
                  : AttachmentService.link(url.text, name.text)),
          child: const Text('เพิ่ม'),
        ),
      ],
    ),
  );
}

// ---------------- ดูรูปเต็มจอ ----------------

class ImageViewer extends StatefulWidget {
  final List<Attachment> images;
  final int initial;
  const ImageViewer({super.key, required this.images, this.initial = 0});

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  late int _i = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1}/${widget.images.length}  ${widget.images[_i].name}',
            style: const TextStyle(fontSize: 14)),
      ),
      body: PageView.builder(
        controller: PageController(initialPage: widget.initial),
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _i = i),
        itemBuilder: (_, i) {
          return InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: AttachmentImageView(widget.images[i], errorColor: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
