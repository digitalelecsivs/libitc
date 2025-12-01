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
        """送出 text2 → 串口 (STX + ASCII文字 + ETX)"""
        if not self.serial.isOpen():
            self.ui.text3.append("尚未連線")
            return

        msg = self.ui.text2.toPlainText()
        if msg == "":
            return

        data = b"\x02" + msg.encode("ascii") + b"\x03"

        try:
            print(msg)
        except Exception as e:
            print(data)

        self.serial.write(data)

    def read_data(self):
        """顯示接收到的資料"""
        data = self.serial.readAll().data()
        # text = data.decode("ascii", errors="ignore")
        text = data.decode("latin1")

        # 除了控制字元
        # filtered = "".join(ch for ch in text if ord(ch) >= 32)

        # a-z A-Z
        # filtered = "".join(ch for ch in text if "a" <= ch <= "z" or "A" <= ch <= "Z")

        # a-z
        # filtered = "".join(ch for ch in text if "a" <= ch <= "z")

        # A-Z
        # filtered = "".join(ch for ch in text if "A" <= ch <= "Z")
        
        # A-Z a-z 0-9
        filtered = ''.join(
            ch for ch in text
            if ch.isalnum() and ch.encode('latin1')[0] < 128
        )

        if filtered.strip() != "" and len(filtered) < 9:
            self.ui.text3.append(filtered)
            self.ui.text3.moveCursor(QtGui.QTextCursor.End)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    tool = SerialTool()
    tool.ui.show()
    sys.exit(app.exec())
