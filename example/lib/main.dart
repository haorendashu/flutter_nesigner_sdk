import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';
import 'package:hex/hex.dart';
import 'package:ndk/domain_layer/entities/nip_01_event.dart';

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

  Future<void> _incrementCounter() async {
    var availablePorts = EspService.availablePorts;
    for (var availablePort in availablePorts) {
      print("availablePort $availablePort");
    }

    if (availablePorts.isEmpty) {
      return;
    }

    // SerialPort serialPort = BaseSerialPort(availablePorts.first);
    SerialPort serialPort = BaseSerialPort("COM4");
    var espService = EspService(serialPort);

    espService.start();
    espService.startListening();

    String pin = "12345678";
    final aesKey = Uint8List.fromList(genMd5ForBytes(pin));
    print("aesKey hex ${HEX.encode(aesKey)}");

    String testPrivateKey =
        "d29ec99c3cc9f8bb0e4a47a32c13d170c286a245a4946ef84453dee14d5ece4b";

    // var iv_hex = "47221dadca56ba6849c0350626092d03";
    // var encrypted_hex =
    //     "ea6e903250b2b118aee5c2d4c444a088eecb8a40743fe0c961c31de476b6cdddd752eba6281af76a1524892c2303e026";

    // var source = espService.aesDecrypt(
    //     aesKey,
    //     Uint8List.fromList(HEX.decode(encrypted_hex)),
    //     Uint8List.fromList(HEX.decode(iv_hex)));
    // print(String.fromCharCodes(source));

    // var result =
    //     await espService.echo(aesKey, "Hello, this is a message from nesigner");
    // print(result);

    var result = await espService.updateKey(aesKey, testPrivateKey);
    print("result $result");

    // var espSigner = EspSigner(aesKey, espService);
    // var pubkey = await espSigner.getPublicKey();
    // print("pubkey $pubkey");

    // var result = await espService.removeKey(aesKey);
    // print("result $result");

    var theirPubkey =
        "1456e77bf02c6fe604879f61e6c7f772ceec3f9f0116aef3828377d447c5c291";

    // var event = Map();
    // event["created_at"] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // event["kind"] = 1;
    // event["tags"] = [];
    // event["content"] = "Hello nostr!";
    // var eventResult = await espSigner.signEvent(event);
    // print(eventResult);

    // if (eventResult != null) {
    //   var nip01Event = Nip01Event.fromJson(eventResult);
    //   print("nip01Event.isIdValid ${nip01Event.isIdValid}");
    // }

    // var TEST_TEXT = "Hello, Nostr! This is a test message.";
    // var encryptedText = await espSigner.encrypt(theirPubkey, TEST_TEXT);
    // print("encryptedText $encryptedText");

    // var sourceText = await espSigner.decrypt(theirPubkey, encryptedText!);
    // print("sourceText $sourceText");

    // encryptedText = await espSigner.nip44Encrypt(theirPubkey, TEST_TEXT);
    // print("encryptedText $encryptedText");

    // sourceText = await espSigner.nip44Decrypt(theirPubkey, encryptedText!);
    // print("sourceText $sourceText");

    // var messageId = espService.randomMessageId();

    // espService.sendMessage(
    //     callback: (reMsg) {
    //       print(reMsg.pubkey);
    //       print(reMsg.encryptedData);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
