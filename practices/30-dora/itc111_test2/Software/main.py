import sys

import serial
import serial.tools.list_ports
from PyQt5 import QtWidgets
from PyQt5.QtWidgets import QMainWindow
from ui import Ui_MainWindow


class Main(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)
        self.value = ""
        for n in range(10):
            getattr(self, f'pushButton_{n}').clicked.connect(
                lambda checked, x=n: self.onNumberClick(x))

        for c in ["send", "clear", "back"]:
            getattr(self, f'pushButton_{c}').clicked.connect(
                lambda checked, x=c: self.onButtonClick(x))


    def onNumberClick(self, num: int):
        print(f"Clicked {num}")
        self.value += str(num)
        self.label_output.setText(self.value)
        
    def onButtonClick(self, cmd: str):
        if cmd == "clear":
            self.value = ""
            self.label_output.setText(self.value)
        if cmd == "send":
            self.value += '\r'
            ser.write(self.value.encode(encoding="utf-8"))
            print((self.value.encode(encoding="utf-8")))
            self.value = ""
            self.label_output.setText(self.value)
            a = 1
            while a:
                data = ser.read()
                print(data)
                if data == b'\x00':
                    self.label_output.setText("FAIL")
                    a=0
                if data == b'\x01':
                    self.label_output.setText("TRUE")
                    a=0
            
        if(cmd == "back"):
            self.value = self.value[:-1]
            self.label_output.setText(self.value)
        print(f"Clicked {cmd}")


port = list(serial.tools.list_ports.comports(include_links=False))
for p in port:
    print(p)
port = "COM5"
ser = serial.Serial(port, 9600, timeout=1)
app = QtWidgets.QApplication(sys.argv)
window = Main()
window.show()

sys.exit(app.exec())


    


