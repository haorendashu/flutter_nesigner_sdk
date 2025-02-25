class CRCUtil {
  // CRC16计算
  static int crc16Calculate(List<int> data) {
    int crc = 0xFFFF;
    for (int byte in data) {
      crc ^= (byte << 8) & 0xFFFF; // 将字节移至高位并异或
      for (int j = 0; j < 8; j++) {
        bool msb = (crc & 0x8000) != 0;
        crc = (crc << 1) & 0xFFFF; // 左移并保持16位
        if (msb) {
          crc ^= 0x1021;
          crc &= 0xFFFF; // 确保结果仍为16位
        }
      }
    }
    return crc;
  }
}
