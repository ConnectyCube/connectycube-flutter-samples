import 'dart:async';
import 'dart:convert';

import 'package:connectycube_sdk/connectycube_sdk.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class E2EEncryptionManager {
  static E2EEncryptionManager? _instance;

  StreamSubscription<CubeMessage>? systemMessagesSubscription;

  E2EEncryptionManager._();

  static E2EEncryptionManager get instance =>
      _instance ??= E2EEncryptionManager._();

  final _secureStorage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  final keyAlgorithm = X25519();

  init() {
    _initCubeChat();
  }

  Future<void> initKeyExchangeForUserDialog(String dialogId, int userId) async {
    final keyPair = await keyAlgorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();

    var publicKeyString = base64Encode(publicKey.bytes);

    saveKeyPairForUserDialog(dialogId, userId, keyPair);

    var systemMessage = CubeMessage()
      ..recipientId = userId
      ..properties = {
        'exchangeType': 'request',
        'publicKey': publicKeyString,
        'secretDialogId': dialogId
      };

    CubeChatConnection.instance.systemMessagesManager
        ?.sendSystemMessage(systemMessage);
  }

  void _initCubeChat() {
    if (CubeChatConnection.instance.isAuthenticated()) {
      _initChatListeners();
    } else {
      CubeChatConnection.instance.connectionStateStream.listen((state) {
        if (CubeChatConnectionState.Ready == state) {
          _initChatListeners();
        }
      });
    }
  }

  _initChatListeners() {
    systemMessagesSubscription = CubeChatConnection
        .instance.systemMessagesManager?.systemMessagesStream
        .listen(onSystemMessageReceived);
  }

  Future<Map<String, String>> encrypt(SecretKey secretKey, String text) async {
    final algorithm = AesCtr.with256bits(
      macAlgorithm: Hmac.sha256(),
    );

    final secretBox = await algorithm.encrypt(
      utf8.encode(text),
      secretKey: secretKey,
    );

    return {
      'nonce': base64Encode(secretBox.nonce),
      'content': base64Encode(secretBox.cipherText),
      'mac': base64Encode(secretBox.mac.bytes)
    };
  }

  Future<String> decrypt(
      SecretKey secretKey, Map<String, String> secretBox) async {
    final algorithm = AesCtr.with256bits(
      macAlgorithm: Hmac.sha256(),
    );

    var incomingSecretBox = SecretBox(
      base64Decode(secretBox['content']!),
      nonce: base64Decode(secretBox['nonce']!),
      mac: Mac(
        base64Decode(secretBox['mac']!),
      ),
    );

    return algorithm
        .decrypt(
      incomingSecretBox,
      secretKey: secretKey,
    )
        .then((raw) {
      return utf8.decode(raw);
    });
  }

  Future<void> onSystemMessageReceived(CubeMessage systemMessage) async {
    var senderId = systemMessage.senderId;
    var secretDialogId = systemMessage.properties['secretDialogId'];
    var publicKeyString = systemMessage.properties['publicKey'];

    if ((secretDialogId?.isEmpty ?? true) ||
        (publicKeyString?.isEmpty ?? true)) {
      return;
    }

    var exchangeType = systemMessage.properties['exchangeType'];
    var publicKey = SimplePublicKey(base64Decode(publicKeyString!),
        type: KeyPairType.x25519);

    if (exchangeType == 'request') {
      final keyPair = await keyAlgorithm.newKeyPair();

      final secretKey = await keyAlgorithm.sharedSecretKey(
        keyPair: keyPair,
        remotePublicKey: publicKey,
      );

      saveSecretKeyForUserDialog(secretKey, secretDialogId!, senderId!);
      // save the same key for the current user to allow decryption of own messages if needed
      // in this sample used for decryption of own messages received through API request
      // it can be ignored in a real app if messages aren't stored on the backend
      saveSecretKeyForUserDialog(secretKey, secretDialogId,
          CubeChatConnection.instance.currentUser!.id!);

      final responsePublicKey = await keyPair.extractPublicKey();

      var responseSystemMessage = CubeMessage()
        ..recipientId = senderId
        ..properties = {
          'exchangeType': 'response',
          'publicKey': base64Encode(responsePublicKey.bytes),
          'secretDialogId': secretDialogId
        };

      CubeChatConnection.instance.systemMessagesManager
          ?.sendSystemMessage(responseSystemMessage);
    } else if (exchangeType == 'response') {
      var keyPairForUserDialog =
          await getKeyPairForUserDialog(secretDialogId!, senderId!);

      if (keyPairForUserDialog != null) {
        final secretKey = await keyAlgorithm.sharedSecretKey(
          keyPair: keyPairForUserDialog,
          remotePublicKey: publicKey,
        );

        saveSecretKeyForUserDialog(secretKey, secretDialogId, senderId);
        // save the same key for the current user to allow decryption of own messages if needed
        // in this sample used for decryption of own messages received through API request
        // it can be ignored in a real app if messages aren't stored on the backend
        saveSecretKeyForUserDialog(secretKey, secretDialogId,
            CubeChatConnection.instance.currentUser!.id!);
      }
    }
  }

  Future<void> saveSecretKeyForUserDialog(
      SecretKey secretKeyData, String dialogId, int userId) async {
    final secretKeyBytes = await secretKeyData.extractBytes();
    await _secureStorage.write(
        key: '${userId}_${dialogId}_secretKey',
        value: base64Encode(secretKeyBytes));
  }

  Future<SecretKeyData?> getSecretKeyForUserDialog(
      String dialogId, int userId) async {
    final secretKeyBase64 =
        await _secureStorage.read(key: '${userId}_${dialogId}_secretKey');

    if (secretKeyBase64 == null) {
      return null;
    }

    final secretKeyBytes = base64Decode(secretKeyBase64);
    return SecretKeyData(secretKeyBytes);
  }

  Future<void> saveKeyPairForUserDialog(
      String dialogId, int userId, SimpleKeyPair keyPair) async {
    final privateKeyBytes = await keyPair.extractPrivateKeyBytes();
    final publicKeyBytes = (await keyPair.extractPublicKey()).bytes;

    await _secureStorage.write(
        key: '${userId}_${dialogId}_privateKey',
        value: base64Encode(privateKeyBytes));
    await _secureStorage.write(
        key: '${userId}_${dialogId}_publicKey',
        value: base64Encode(publicKeyBytes));
  }

  Future<SimpleKeyPair?> getKeyPairForUserDialog(
      String dialogId, int userId) async {
    final privateKeyBase64 =
        await _secureStorage.read(key: '${userId}_${dialogId}_privateKey');
    final publicKeyBase64 =
        await _secureStorage.read(key: '${userId}_${dialogId}_publicKey');

    if (privateKeyBase64 == null || publicKeyBase64 == null) {
      return null;
    }

    final privateKeyBytes = base64Decode(privateKeyBase64);
    final publicKeyBytes = base64Decode(publicKeyBase64);

    final publicKey = SimplePublicKey(publicKeyBytes, type: KeyPairType.x25519);

    return SimpleKeyPairData(privateKeyBytes,
        publicKey: publicKey, type: KeyPairType.x25519);
  }

  void destroy() {
    systemMessagesSubscription?.cancel();

    _secureStorage.deleteAll(
        aOptions: const AndroidOptions(encryptedSharedPreferences: true));
  }

  Future<CubeMessage> encryptMessage(
      CubeMessage originalMessage, String dialogId, int userId) async {
    var userDialogSecretKey = await getSecretKeyForUserDialog(dialogId, userId);

    if (userDialogSecretKey == null) return originalMessage;

    return encrypt(userDialogSecretKey, originalMessage.body!)
        .then((encryptionData) {
      var encryptedMessage = CubeMessage()
        ..messageId = originalMessage.messageId
        ..dialogId = originalMessage.dialogId
        ..body = 'Encrypted message'
        ..properties = {...originalMessage.properties, ...encryptionData}
        ..attachments = originalMessage.attachments
        ..dateSent = originalMessage.dateSent
        ..readIds = originalMessage.readIds
        ..deliveredIds = originalMessage.deliveredIds
        ..viewsCount = originalMessage.viewsCount
        ..recipientId = originalMessage.recipientId
        ..senderId = originalMessage.senderId
        ..markable = originalMessage.markable
        ..delayed = originalMessage.delayed
        ..saveToHistory = originalMessage.saveToHistory
        ..destroyAfter = originalMessage.destroyAfter
        ..isRead = originalMessage.isRead
        ..reactions = originalMessage.reactions;

      return encryptedMessage;
    });
  }

  Future<CubeMessage> decryptMessage(CubeMessage originalMessage) async {
    var userDialogSecretKey = await getSecretKeyForUserDialog(
        originalMessage.dialogId!, originalMessage.senderId!);

    if (userDialogSecretKey == null) return originalMessage;

    return decrypt(userDialogSecretKey, originalMessage.properties)
        .then((decryptedBody) {
      originalMessage.body = decryptedBody;
      return originalMessage;
    });
  }

  Future<List<CubeMessage>> decryptMessages(
      List<CubeMessage> originalMessages) {
    return Future.wait(originalMessages
        .map((originalMessage) => decryptMessage(originalMessage))
        .toList());
  }
}
