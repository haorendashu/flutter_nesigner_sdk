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

// 定义一个函数来生成 MD5 哈希值
String genMd5(String input) {
  // 首先将输入的字符串转换为 UTF-8 编码的字节列表
  var bytes = utf8.encode(input);
  // 使用 crypto 包中的 md5.convert 方法计算字节列表的 MD5 哈希值
  var digest = md5.convert(bytes);
  // 将计算得到的 MD5 哈希值转换为十六进制字符串
  return digest.toString();
}

// 定义一个函数来生成 MD5 哈希值
List<int> genMd5ForBytes(String input) {
  var bytes = utf8.encode(input);
  var digest = md5.convert(bytes);
  return digest.bytes;
}
