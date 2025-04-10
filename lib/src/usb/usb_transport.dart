import 'dart:ffi';
import 'dart:io';

import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:libusb/libusb64.dart';

import '../../flutter_nesigner_sdk.dart';

// class UsbTransport extends BufferTransport {
class UsbTransport {
  static const int VID = 0x2323;

  static const int PID = 0x3434;

  static const int CONFIG_NUM = 1;

  static const int INTERFACE_NUM = 1;

  static const int OUT_ENDPOINT = 2;

  static const int IN_ENDPOINT = 130;

  static String? _libPath;

  static bool? macosArchIsArm;

  static void setLibrary(String libPath) {
    _libPath = libPath;
  }

  static void setMacOSArchIsArm(bool isArm) {
    macosArchIsArm = isArm;
  }

  static DynamicLibrary loadLibrary() {
    if (_libPath != null) {
      return DynamicLibrary.open(_libPath!);
    }

    if (Platform.isWindows) {
      final executablePath = Platform.resolvedExecutable;
      var paths = executablePath.split("\\");
      var currentPath = [...paths.sublist(0, paths.length - 1)].join("\\");
      return DynamicLibrary.open('$currentPath/libusb-1.0.dll');
    }
    if (Platform.isMacOS) {
      if (macosArchIsArm != null && !macosArchIsArm!) {
        var filePath = _getMacOSLibraryPath("libusb-1.0.dylib");
        return DynamicLibrary.open(filePath);
      }
      var filePath = _getMacOSLibraryPath("libusb-1.0_arm64.dylib");
      return DynamicLibrary.open(filePath);
    } else if (Platform.isLinux) {
      final executablePath = Platform.resolvedExecutable;
      var paths = executablePath.split("/");
      var currentPath = [...paths.sublist(0, paths.length - 1)].join("/");
      return DynamicLibrary.open('$currentPath/libusb-1.0.so');
    }
    throw 'libusb dynamic library not found';
  }

  static String _getMacOSLibraryPath(String name) {
    if (Platform.isMacOS) {
      // 获取应用 Frameworks 目录路径
      final executablePath = Platform.resolvedExecutable;
      print("executablePath $executablePath");
      var paths = executablePath.split("/");
      paths = [...paths.sublist(0, paths.length - 2), "Frameworks"];
      return "${paths.join("/")}/$name";
    }
    throw UnsupportedError("Unsupported platform");
  }

  static bool existNesigner() {
    try {
      var libusb = Libusb(UsbTransport.loadLibrary());
      print("libusb load success!");
      var initResult = libusb.libusb_init(nullptr);
      print("libusb init success! $initResult");
      if (initResult < 0) {
        return false;
      }

      var deviceListPtr = calloc<Pointer<Pointer<libusb_device>>>();
      var count = libusb.libusb_get_device_list(nullptr, deviceListPtr);
      print("libusb_get_device_list success! $count");
      if (count < 0) {
        calloc.free(deviceListPtr);
        return false;
      }

      var descPtr = calloc<libusb_device_descriptor>();
      var deviceList = deviceListPtr.value;
      for (var i = 0; deviceList[i] != nullptr; i++) {
        var dev = deviceList[i];
        print(dev);
        var result = libusb.libusb_get_device_descriptor(dev, descPtr);
        if (result < 0) continue;

        var desc = descPtr.ref;
        var idVendor = desc.idVendor.toRadixString(16).padLeft(4, '0');
        var idProduct = desc.idProduct.toRadixString(16).padLeft(4, '0');
        print(
            '$idVendor:$idProduct vid:${desc.idVendor} pid:${desc.idProduct}');

        if (desc.idVendor == VID && desc.idProduct == PID) {
          calloc.free(deviceListPtr);
          calloc.free(descPtr);
          return true;
        }
      }

      calloc.free(deviceListPtr);
      calloc.free(descPtr);
      return false;
    } catch (e) {
      print("existNesigner exception! $e");
    }
    return false;
  }

  // Libusb? libusb;

  // Pointer<libusb_device_handle>? deviceHandlePtr;

  // @override
  // Future<bool> close() async {
  //   if (libusb != null && deviceHandlePtr != null) {
  //     libusb!.libusb_release_interface(deviceHandlePtr!, INTERFACE_NUM);
  //     libusb!.libusb_close(deviceHandlePtr!);

  //     libusb = null;
  //     deviceHandlePtr = null;
  //     _running = false;

  //     return true;
  //   }

  //   return false;
  // }

  // @override
  // bool get isOpen {
  //   if (libusb != null && deviceHandlePtr != null) {
  //     return true;
  //   }
  //   return false;
  // }

  // bool _running = false;

  // @override
  // void receiveData(void Function(Uint8List event) onData,
  //     {Function? onError, void Function()? onDone, bool? cancelOnError}) {
  //   if (libusb != null && deviceHandlePtr != null) {
  //     _doListen(onData,
  //         onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  //   }
  // }

  // @override
  // Future<void> _doListen(void Function(Uint8List event) onData,
  //     {Function? onError, void Function()? onDone, bool? cancelOnError}) async {
  //   var bufferLength = 1024 * 4;
  //   var buffer = calloc<UnsignedChar>(1024 * 4);
  //   var actualLength = calloc<Int>(8);

  //   for (; _running;) {
  //     // print("begin to receive data");
  //     var readResult = libusb!.libusb_bulk_transfer(deviceHandlePtr!,
  //         IN_ENDPOINT, buffer, bufferLength, actualLength, 10);
  //     if (readResult == libusb_error.LIBUSB_SUCCESS) {
  //       // read success!
  //       var readedLength = actualLength.value;
  //       var data = convertPointerToUint8List(buffer, readedLength);
  //       onData(data);
  //       // var readedLength = actualLength.value;
  //       // if (readedLength > PREFIX_LENGTH) {
  //       //   var data = convertPointerToUint8List(buffer, readedLength);
  //       //   final headerBytes = data.sublist(PREFIX_LENGTH - 4, PREFIX_LENGTH);
  //       //   final totalLen =
  //       //       ByteData.sublistView(headerBytes).getUint32(0, Endian.big);
  //       //   if (PREFIX_LENGTH + totalLen >= readedLength) {
  //       //     onData(data);
  //       //   }
  //       // }
  //     } else {
  //       await Future.delayed(const Duration(milliseconds: 30));
  //     }
  //   }

  //   malloc.free(buffer);
  //   malloc.free(actualLength);
  // }

  // @override
  // Future<bool> open() async {
  //   libusb = Libusb(loadLibrary());
  //   var initResult = libusb!.libusb_init(nullptr);
  //   if (initResult < 0) {
  //     return false;
  //   }

  //   var deviceListPtr = calloc<Pointer<Pointer<libusb_device>>>();
  //   calloc.free(deviceListPtr);

  //   deviceHandlePtr =
  //       libusb!.libusb_open_device_with_vid_pid(nullptr, VID, PID);
  //   if (deviceHandlePtr!.address <= 0) {
  //     print("libusb_open_device_with_vid_pid fail");
  //     return false;
  //   }

  //   var result =
  //       libusb!.libusb_claim_interface(deviceHandlePtr!, INTERFACE_NUM);
  //   if (result != libusb_error.LIBUSB_SUCCESS) {
  //     print("libusb_claim_interface error $result");
  //     return false;
  //   }

  //   _running = true;

  //   return true;
  // }

  // @override
  // int write(Uint8List bytes) {
  //   if (libusb != null && deviceHandlePtr != null) {
  //     var data = convertUint8ListToPointer(bytes);
  //     var actualLength = calloc<Int>(8);
  //     var sendResult = libusb!.libusb_bulk_transfer(deviceHandlePtr!,
  //         OUT_ENDPOINT, data, bytes.length, actualLength, 1000);
  //     print("sendResult $sendResult");
  //     return actualLength.value;
  //   }

  //   return 0;
  // }

  // 将 Uint8List 转换为 Pointer<UnsignedChar>
  static Pointer<UnsignedChar> convertUint8ListToPointer(Uint8List data) {
    // 分配内存
    final ptr = malloc<UnsignedChar>(data.length);
    // 转换为 Uint8 的指针视图
    final nativeList = ptr.cast<Uint8>().asTypedList(data.length);
    // 复制数据到 native 内存
    nativeList.setAll(0, data);
    return ptr;
  }

  // 假设 data 是 ffi.Pointer<pkg_ffi.UnsignedChar>，length 是数据长度
  static Uint8List convertPointerToUint8List(
      Pointer<UnsignedChar> data, int length) {
    // 将指针转换为 Uint8 类型的指针
    final pointerUint8 = data.cast<Uint8>();
    // 创建 Uint8List 视图
    final uint8List = pointerUint8.asTypedList(length);

    // 如果需要复制数据（避免后续指针被释放）
    // final copiedList = Uint8List.fromList(uint8List);
    // return copiedList;

    return uint8List;
  }
}
