import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// Delta JSON文字列からQuillControllerを生成する。
/// 既存のプレーンテキストにも後方互換で対応。
QuillController controllerFromDescription(String description) {
  if (description.isEmpty) {
    return QuillController.basic();
  }

  // Delta JSON形式かどうか試す
  try {
    final decoded = jsonDecode(description);
    if (decoded is List) {
      final doc = Document.fromJson(decoded);
      return QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  } catch (_) {
    // JSONでなければプレーンテキストとして扱う
  }

  // プレーンテキスト → Delta変換
  final doc = Document()..insert(0, description);
  return QuillController(
    document: doc,
    selection: const TextSelection.collapsed(offset: 0),
  );
}

/// QuillControllerからDelta JSON文字列を取得する。
String descriptionFromController(QuillController controller) {
  final delta = controller.document.toDelta().toJson();
  return jsonEncode(delta);
}

/// Delta JSON文字列からプレーンテキストを抽出する（カードプレビュー用）。
String plainTextFromDescription(String description) {
  if (description.isEmpty) return '';

  try {
    final decoded = jsonDecode(description);
    if (decoded is List) {
      final doc = Document.fromJson(decoded);
      return doc.toPlainText().trim();
    }
  } catch (_) {
    // プレーンテキストならそのまま返す
  }

  return description;
}

/// Delta JSON文字列から読み取り専用のDocumentを取得する。
Document documentFromDescription(String description) {
  if (description.isEmpty) {
    return Document();
  }

  try {
    final decoded = jsonDecode(description);
    if (decoded is List) {
      return Document.fromJson(decoded);
    }
  } catch (_) {
    // プレーンテキスト → Document
  }

  return Document()..insert(0, description);
}
