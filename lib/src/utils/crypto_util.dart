import 'dart:convert';
import 'package:crypto/crypto.dart';

/// 计算字符串的 SHA-256 哈希值
String calculateSHA256(List<int> input) {
  // 使用 sha256 算法计算哈希值
  final digest = sha256.convert(input);

  // 将哈希值转换为十六进制字符串
  return digest.toString();
}

/// 计算字符串的 SHA-256 哈希值
String calculateSHA256FromText(String input) {
  // 将输入字符串转换为 UTF-8 编码的字节列表
  final bytes = utf8.encode(input);

  return calculateSHA256(bytes);
}
