import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_nesigner_sdk/flutter_nesigner_sdk.dart';

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
  static const String aesKey = "0123456789ABCDEF";
  int _counter = 0;

  Future<void> _incrementCounter() async {
    var availablePorts = EspService.availablePorts;
    for (var availablePort in availablePorts) {
      print("availablePort $availablePort");
    }

    if (availablePorts.isEmpty) {
      return;
    }

    SerialPort serialPort = BaseSerialPort(availablePorts.first);
    var espService = EspService(serialPort);

    espService.start();
    espService.onMsg = (receivedMessage) {
      print(receivedMessage.pubkey);
      print(receivedMessage.encryptedData);
    };
    espService.startListening();

    var messageId = espService.randomMessageId();

    espService.sendMessage(
        aesKey: aesKey,
        messageType: MsgType.NOSTR_GET_RELAYS,
        messageId: messageId,
        pubkey:
            "76a9e845c5431c2e3d339e60bbdafe2ef2f08984f9b20a9bf8d2844e3e0b968e",
        data: utf8.encode("hello"));

    await Future.delayed(Duration(minutes: 1));

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
