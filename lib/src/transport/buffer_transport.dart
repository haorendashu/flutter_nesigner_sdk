import 'dart:typed_data';

import 'package:flutter_nesigner_sdk/src/transport/transport.dart';

abstract class BufferTransport extends Transport {
  Uint8List _receiveBuffer = Uint8List(0); // 接收缓冲区

  void receiveData(void onData(Uint8List event),
      {Function? onError, void onDone()?, bool? cancelOnError});

  @override
  void listen(void onData(Uint8List event),
      {Function? onError, void onDone()?, bool? cancelOnError}) {
    receiveData(
      (data) {
        _receiveBuffer = Uint8List.fromList([..._receiveBuffer, ...data]);

        while (true) {
          // 检查最小包头长度
          if (_receiveBuffer.length < PREFIX_LENGTH) return;

          print("receive data");
          print(_receiveBuffer);

          // 解析长度头（最后4字节的包头）
          final headerBytes =
              _receiveBuffer.sublist(PREFIX_LENGTH - 4, PREFIX_LENGTH);
          final totalLen =
              ByteData.sublistView(headerBytes).getUint32(0, Endian.big);

          // 计算完整帧长度
          final fullFrameLength = PREFIX_LENGTH + totalLen;

          // 检查是否收到完整帧
          if (_receiveBuffer.length < fullFrameLength) return;

          // 提取完整帧数据
          final frameData = _receiveBuffer.sublist(0, fullFrameLength);
          _receiveBuffer = _receiveBuffer.sublist(fullFrameLength);

          // 处理单个数据帧
          onData(frameData);
        }
      },
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  void clearBuffer() {
    _receiveBuffer.clear();
  }
}
