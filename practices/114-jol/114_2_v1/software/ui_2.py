import sys

from PySide6 import QtGui
from PySide6.QtCore import QIODevice
from PySide6.QtSerialPort import QSerialPort, QSerialPortInfo
from PySide6.QtUiTools import QUiLoader
from PySide6.QtWidgets import QApplication, QMessageBox


class SerialTool:

    def __init__(self):
        # 引入.ui
        self.ui = QUiLoader().load("practices/114-jol/114_2_v1/software/ui.ui")

        self.serial = QSerialPort()
        self.serial.setPortName("COM4")
        self.serial.setBaudRate(115200)
        self.serial.setDataBits(QSerialPort.Data8)
        self.serial.setParity(QSerialPort.NoParity)
        self.serial.setStopBits(QSerialPort.OneStop)

        self.serial.readyRead.connect(self.read_data)

        numbers = {
            self.ui.btn_n0: "0",
            self.ui.btn_n1: "1",
            self.ui.btn_n2: "2",
            self.ui.btn_n3: "3",
            self.ui.btn_n4: "4",
            self.ui.btn_n5: "5",
            self.ui.btn_n6: "6",
            self.ui.btn_n7: "7",
            self.ui.btn_n8: "8",
            self.ui.btn_n9: "9",
        }

        for btn, num in numbers.items():
            btn.clicked.connect(lambda _, n=num: self.add_text(n))
        # 清除按鈕
        self.ui.btn_cls.clicked.connect(self.clear_text)

        # 返回鍵 (刪除一格)
        self.ui.btn_return.clicked.connect(self.backspace)

        # 連線
        self.ui.btn_link.clicked.connect(self.connect_serial)

        # 送出
        self.ui.btn_send.clicked.connect(self.send_data)

        # 關閉程式
        self.ui.btn_close.clicked.connect(self.ui.close)

    def add_text(self, s):
        """數字按下 → 填入 text2"""
        self.ui.text2.insertPlainText(s)

    def clear_text(self):
        """清除傳送框"""
        self.ui.text2.clear()

    def backspace(self):
        """刪除最後一個字"""
        text = self.ui.text2.toPlainText()
        self.ui.text2.setPlainText(text[:-1])

    def connect_serial(self):
        if not self.serial.isOpen():
            if self.serial.open(QIODevice.ReadWrite):
                self.ui.btn_link.setText("已連線")
                self.ui.btn_link.setStyleSheet("background-color: lightgreen;")
                msg = b"\x02" + "connect".encode("ascii") + b"\x03"
                self.serial.write(msg)
            else:
                self.ui.btn_link.setText("連線失敗")
        else:
            self.serial.close()
            self.ui.btn_link.setText("連線")
            self.ui.btn_link.setStyleSheet("")

    def send_data(self):
        """【修改】送出 text2 內容，將其視為 Hex 字串"""
        if not self.serial.isOpen():
            self.ui.text3.append("尚未連線")
            return

        msg = self.ui.text2.toPlainText()
        if msg == "":
            return

        # 1. 去除空白 (允許使用者輸入 "AA BB" 這種格式)
        clean_msg = msg.replace(" ", "").replace("\n", "")

        try:
            # 2. 將 Hex 字串轉換為 bytes (例如 "3132" -> b'\x31\x32')
            # bytes.fromhex() 很嚴格，如果輸入 "GG" 或奇數個字元會報錯
            data = b"\x02" + bytes.fromhex(clean_msg) + b"\x03"

            # 3. 直接發送原始 bytes (不再包 STX/ETX)
            self.serial.write(data)

            # (選用) 在 console 印出確認
            print(f"Sent Hex: {data.hex().upper()}")

        except ValueError:
            err_msg = "請輸入有效的 16 進位數值 (0-9, A-F)且為偶數長度"

            # 1. 彈出警告視窗
            # QMessageBox.warning(self.ui, "格式錯誤", err_msg)

            # 2. 【新增】顯示在接收資料框 (text3)
            # 這裡使用 HTML 語法 <font color='red'> 讓錯誤訊息變成紅色，更直觀
            self.ui.text3.append(f"<font color='black'>錯誤：{err_msg}</font>")

            # 確保捲軸滾動到底部
            self.ui.text3.moveCursor(QtGui.QTextCursor.End)

            return

    def read_data(self):
        """【修改】顯示接收到的資料為 Hex 格式"""
        # 1. 讀取所有資料並轉為 Python bytes
        data = bytes(self.serial.readAll())

        if not data:
            return

        # 2. 將 bytes 轉為 Hex 字串，並用空格分隔 (例如 b'\x01\xff' -> "01 FF")
        # .upper() 是為了讓 a-f 變成 A-F，比較美觀
        hex_string = data.hex(" ").upper()

        # 3. 直接顯示在視窗上
        self.ui.text3.append(hex_string)
        self.ui.text3.moveCursor(QtGui.QTextCursor.End)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    tool = SerialTool()
    tool.ui.show()
    sys.exit(app.exec())
