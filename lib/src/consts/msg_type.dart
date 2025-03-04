class MsgType {
  static const int NOSTR_GET_PUBLIC_KEY = 1;
  static const int NOSTR_SIGN_EVENT = 2;
  static const int NOSTR_GET_RELAYS = 3;
  static const int NOSTR_NIP04_ENCRYPT = 4;
  static const int NOSTR_NIP04_DECRYPT = 5;
  static const int NOSTR_NIP44_ENCRYPT = 6;
  static const int NOSTR_NIP44_DECRYPT = 7;

  static const int PING = 0;
  static const int ECHO = 11;
  static const int UPDATE_KEY = 12;
  static const int REMOVE_KEY = 13;
}
