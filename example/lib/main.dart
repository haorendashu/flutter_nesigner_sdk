import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:hex/hex.dart';
import 'package:ndk/domain_layer/entities/nip_01_event.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  Future<void> test() async {
    logText = "";

    late List<SerialPort> nesignerPorts;
    if (Platform.isAndroid) {
      nesignerPorts = await AndroidSerialPort.getNesignerPorts();
    } else {
      nesignerPorts = BaseSerialPort.getNesignerPorts();
      // nesignerPorts = IsolateSerialPort.getNesignerPorts();
    }

    if (nesignerPorts.isEmpty) {
      printLog("No nesigner ports found");
      return;
    }
    SerialPort serialPort = nesignerPorts.first;
    printLog("Using nesigner port: ${serialPort.name}");
    var espService = EspService(serialPort);

    // var usbTransport = UsbIsolateTransport();
    // var espService = EspService(usbTransport);

    await espService.start();
    // await Future.delayed(const Duration(seconds: 10));

    String pin = "12345678";
    final aesKey = Uint8List.fromList(genMd5ForBytes(pin));
    printLog("aesKey hex ${HEX.encode(aesKey)}");

    String testPrivateKey =
        "d29ec99c3cc9f8bb0e4a47a32c13d170c286a245a4946ef84453dee14d5ece4b";

    // var iv_hex = "47221dadca56ba6849c0350626092d03";
    // var encrypted_hex =
    //     "ea6e903250b2b118aee5c2d4c444a088eecb8a40743fe0c961c31de476b6cdddd752eba6281af76a1524892c2303e026";

    // var source = espService.aesDecrypt(
    //     aesKey,
    //     Uint8List.fromList(HEX.decode(encrypted_hex)),
    //     Uint8List.fromList(HEX.decode(iv_hex)));
    // printLog(String.fromCharCodes(source));

    // var updateResult = await espService.updateKey(pin, testPrivateKey);
    // printLog("updateResult $updateResult");

    // var result = await espService.removeKey(aesKey);
    // printLog("result $result");

    var result =
        await espService.echo(aesKey, "Hello, this is a message from nesigner");
    printLog("echo result $result");

    var espSigner = EspSigner(pin, espService);
    var pubkey = await espSigner.getPublicKey();
    printLog("pubkey $pubkey");

    var theirPubkey =
        "1456e77bf02c6fe604879f61e6c7f772ceec3f9f0116aef3828377d447c5c291";

    var event = Map<String, dynamic>();
    event["created_at"] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // event["created_at"] = 1743790056;
    event["kind"] = 1;
    event["tags"] = [];
    event["content"] = "Hello nostr!";
    var eventResult = await espSigner.signEvent(event);
    printLog(jsonEncode(eventResult));

    if (eventResult != null) {
      var nip01Event = Nip01Event.fromJson(eventResult);
      printLog("nip01Event.isIdValid ${nip01Event.isIdValid}");
      var validSig =
          Bip340.verify(nip01Event.id, nip01Event.sig, nip01Event.pubKey);
      printLog("nip01Event.isValidSign $validSig");

      nip01Event.sign(testPrivateKey);
      printLog(jsonEncode(nip01Event.toJson()));
      validSig =
          Bip340.verify(nip01Event.id, nip01Event.sig, nip01Event.pubKey);
      printLog("nip01Event.isValidSign $validSig");
    }

    var TEST_TEXT =
        "Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.Hello, Nostr! This is a test message.";
    var encryptedText = await espSigner.encrypt(theirPubkey, TEST_TEXT);
    printLog("encryptedText $encryptedText");

    var sourceText = await espSigner.decrypt(theirPubkey, encryptedText!);
    printLog("sourceText $sourceText");

    encryptedText = await espSigner.nip44Encrypt(theirPubkey, TEST_TEXT);
    printLog("encryptedText $encryptedText");

    sourceText = await espSigner.nip44Decrypt(theirPubkey, encryptedText!);
    printLog("sourceText $sourceText");

    // var messageId = espService.randomMessageId();

    // espService.sendMessage(
    //     callback: (reMsg) {
    //       printLog(reMsg.pubkey);
    //       printLog(reMsg.encryptedData);
    //     },
    //     aesKey: aesKey,
    //     messageType: MsgType.ECHO,
    //     messageId: messageId,
    //     pubkey:
    //         "76a9e845c5431c2e3d339e60bbdafe2ef2f08984f9b20a9bf8d2844e3e0b968e",
    //     data: utf8.encode("hello"));

    // await Future.delayed(Duration(seconds: 30));

    espService.stop();
  }

  String logText = "";

  void printLog(String text) {
    setState(() {
      logText += text + "\n";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                logText,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: test,
        tooltip: 'Test',
        child: const Icon(Icons.add),
      ),
    );
  }
}
