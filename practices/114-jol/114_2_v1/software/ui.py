import sys

from PySide6 import QtGui
from PySide6.QtCore import QIODevice, Qt
from PySide6.QtSerialPort import QSerialPort
from PySide6.QtUiTools import QUiLoader
from PySide6.QtWidgets import QApplication


class SerialTool:

    def __init__(self):
        # 引入.ui
        self.ui = QUiLoader().load("practices/114-jol/114_2_v1/software/ui.ui")

        # --- Serial Port ---
        self.serial = QSerialPort()
        self.serial.setPortName("COM4")
        self.serial.setBaudRate(115200)
        self.serial.setDataBits(QSerialPort.Data8)
        self.serial.setParity(QSerialPort.NoParity)
        self.serial.setStopBits(QSerialPort.OneStop)
        self.serial.readyRead.connect(self.read_data)

        # --- 數字鍵 ---
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
            btn.setFocusPolicy(Qt.NoFocus)
            btn.clicked.connect(lambda _, n=num: self.add_text(n))

        self.ui.btn_cls.setFocusPolicy(Qt.NoFocus)
        self.ui.btn_cls.clicked.connect(self.clear_text)
        self.ui.btn_return.setFocusPolicy(Qt.NoFocus)
        self.ui.btn_return.clicked.connect(self.backspace)
        self.ui.btn_link.setFocusPolicy(Qt.NoFocus)
        self.ui.btn_link.clicked.connect(self.connect_serial)
        self.ui.btn_send.setFocusPolicy(Qt.NoFocus)
        self.ui.btn_send.clicked.connect(self.send_data)
        self.ui.btn_close.setFocusPolicy(Qt.NoFocus)
        self.ui.btn_close.clicked.connect(self.ui.close)

    # --- 數字鍵輸入 ---
    def add_text(self, s):
        focused = QApplication.focusWidget()
        if focused in (self.ui.text1, self.ui.text2):
            focused.insertPlainText(s)
        else:
            self.ui.text2.insertPlainText(s)
            self.ui.text2.setFocus()

    def clear_text(self):
        focused = QApplication.focusWidget()
        if focused in (self.ui.text1, self.ui.text2):
            focused.clear()

    def backspace(self):
        focused = QApplication.focusWidget()
        if focused in (self.ui.text1, self.ui.text2):
            text = focused.toPlainText()
            focused.setPlainText(text[:-1])

    # --- 串口連線 ---
    def connect_serial(self):
        if not self.serial.isOpen():
            if self.serial.open(QIODevice.ReadWrite):
                self.ui.btn_link.setText("已連線")
                self.ui.btn_link.setStyleSheet("background-color: lightgreen;")
                msg = b"\x02connect\x03"
                self.serial.write(msg)
            else:
                self.ui.btn_link.setText("連線失敗")
        else:
            self.serial.close()
            self.ui.btn_link.setText("連線")
            self.ui.btn_link.setStyleSheet("")

    # --- 傳送資料 ---
    def send_data(self):
        if not self.serial.isOpen():
            self.ui.text3.append("尚未連線")
            return

        # 取得筆數
        num_text = self.ui.text1.toPlainText().strip()
        if not num_text.isdigit():
            self.ui.text3.append("❌ 筆數錯誤")
            return
        count = int(num_text)

        # 取得傳送訊息
        msg_text = self.ui.text2.toPlainText().strip()
        # 用空白分割
        parts = msg_text.replace(",", " ").split()
        # 過濾成兩位數字字串
        filtered = [p for p in parts if len(p) == 2 and p.isdigit()]

        if len(filtered) != count:
            self.ui.text3.append(
                f"❌ 資料筆數與輸入筆數不符\n輸入筆數：{count}, 實際資料：{filtered}"
            )
            return

        # 組成 ASCII 字串封包
        packet_str = f"{count} " + " ".join(filtered)
        packet_bytes = b"\x02" + packet_str.encode("ascii") + b"\x03"

        self.ui.text3.append(f"✔ 傳送封包 (ASCII)：{packet_bytes}")
        self.serial.write(packet_bytes)

    # --- 接收資料 ---
    def read_data(self):
        data = self.serial.readAll().data()
        try:
            text = data.decode("latin1")
        except:
            text = str(data)

        filtered = "".join(ch for ch in text if ch.isalnum() or ch.isspace())

        if filtered.strip() != "":
            self.ui.text3.append(filtered)
            self.ui.text3.moveCursor(QtGui.QTextCursor.End)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    tool = SerialTool()
    tool.ui.show()
    sys.exit(app.exec())
