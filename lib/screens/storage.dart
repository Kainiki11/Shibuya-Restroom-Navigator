import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class FileUpload {
  final FirebaseStorage storage = FirebaseStorage.instance;
  
  // 画像を選択してアップロードし、そのURLを取得
  Future<void> uploadFile() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      File file = File(pickedFile.path);

      try {
        // Cloud Storageにファイルをアップロード
        await storage.ref('uploads/${pickedFile.name}').putFile(file);
        print("ファイルが正常にアップロードされました。");

        // アップロード後にURLを取得
        String fileUrl = await getFileUrl(pickedFile.name);
        print("アップロードしたファイルのURL: $fileUrl");

      } on FirebaseException catch (e) {
        print("アップロードエラー: $e");
      }
    }
  }

  // アップロードしたファイルのURLを取得
  Future<String> getFileUrl(String fileName) async {
    try {
      String fileUrl = await storage.ref('uploads/$fileName').getDownloadURL();
      return fileUrl;
    } catch (e) {
      print("URL取得エラー: $e");
      return "";
    }
  }
}
