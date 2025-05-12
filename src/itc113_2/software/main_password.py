#!/usr/bin/env python

import sys
import threading

import serial
import serial.tools.list_ports
from PyQt5 import QtWidgets
from PyQt5.QtWidgets import QMainWindow
from ui2 import Ui_MainWindow

ser = serial.Serial()

ser.baudrate = 115200
ser.port = "COM14"
ser.open()
ser.timeout = 1


def read_from_serial(ser):
    """從串口讀取數據的函數，作為線程運行"""
    while True:
        try:
            data = ser.readline()  # 讀取一行數據
            if data:
                print(f"接收到數據: {data.decode('utf-8').strip()}")
        except Exception as e:
            print(f"讀取錯誤: {e}")
            break


class Main(QMainWindow, Ui_MainWindow):
    reader_thread = threading.Thread(target=read_from_serial, args=(ser,))
    reader_thread.daemon = True  # 設置為守護線程，主程序結束時自動退出
    reader_thread.start()

    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.value = ""

        for n in range(10):
            getattr(self, f"pushButton_{n}").clicked.connect(
                lambda checked, x=n: self.onNumberClick(x)
            )

        for c in ["send", "clear", "back"]:
            getattr(self, f"pushButton_{c}").clicked.connect(
                lambda checked, x=c: self.onButtonClick(x)
            )

    def onNumberClick(self, num: int):
        print(f"Clicked {num}")
        self.value += str(num)
        self.label_inputnumber.setText("輸入蛋價")
        self.label_output.setText(self.value)

    def onButtonClick(self, cmd: str):
        if cmd == "clear":
            self.value = ""
            self.label_output.setText(self.value)
            self.label_inputnumber.setText("輸入蛋價")

        if cmd == "send" and self.value != "":
            self.value += "\r"
            ser.write(self.value.encode(encoding="utf-8"))
            print((self.value.encode(encoding="utf-8")))
            self.value = ""
            self.label_output.setText(self.value)
        if cmd == "back":
            self.value = self.value[:-1]
            self.label_inputnumber.setText("輸入蛋價")
            self.label_output.setText(self.value)
        print(f"Clicked {cmd}")


port = list(serial.tools.list_ports.comports())


app = QtWidgets.QApplication(sys.argv)
window = Main()
window.show()

sys.exit(app.exec())
