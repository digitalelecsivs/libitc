#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import time

import serial
import serial.tools.list_ports
from PyQt5 import QtWidgets, uic
from PyQt5.QtCore import QThread, pyqtSignal
from PyQt5.QtWidgets import QMainWindow, QMessageBox


class SerialWorker(QThread):
    """通訊處理執行緒"""

    result_signal = pyqtSignal(object)

    def __init__(self, port="COM8", baudrate=9600, timeout=5.0):
        super().__init__()
        self.port = port
        self.baudrate = baudrate
        self.timeout = timeout

    def run(self):
        print(f"\n[DEBUG] 嘗試開啟通訊埠: {self.port} (Baudrate: {self.baudrate})...")
        try:
            with serial.Serial(self.port, self.baudrate, timeout=self.timeout) as ser:
                print(f"[DEBUG] ✅ 成功開啟 {self.port}！準備發送封包...")

                # 發送測試封包
                request_packet = b"CONNECT\r\n"
                ser.write(request_packet)
                print(f"[DEBUG] 📤 已成功發送封包至 {self.port}: {request_packet}")
                print(
                    f"[DEBUG] ⏳ 等待 {self.port} 接收硬體端回傳 (最長等待 {self.timeout} 秒)..."
                )

                # 讀取回傳資料
                response = ser.readline().decode("utf-8", errors="ignore").strip()

                if response and len(response) > 0:
                    print(f"[DEBUG] 📥 收到回傳資料: '{response}'")
                    self.result_signal.emit(response)
                else:
                    print(f"[DEBUG] ⚠️ 等待超時！未收到任何資料。")
                    self.result_signal.emit(None)

        except Exception as e:
            print(f"[DEBUG] ❌ 連線失敗/開啟 Port 異常: {e}")
            self.result_signal.emit(None)


class MainWindow(QMainWindow):

    def __init__(self):
        super().__init__()
        uic.loadUi("ui.ui", self)

        self.line_order_id = getattr(self, "lineEdit_order_id", None) or getattr(
            self, "lineEdit_1", None
        )
        self.line_amount = getattr(self, "lineEdit_amount", None) or getattr(
            self, "lineEdit_2", None
        )
        self.line_total = getattr(self, "lineEdit_total", None) or getattr(
            self, "lineEdit_3", None
        )

        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.clicked.connect(self.on_connect_click)
        if hasattr(self, "pushButton_clear"):
            self.pushButton_clear.clicked.connect(self.on_clear_click)

    def on_connect_click(self):
        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.setEnabled(False)

        # 這裡指定使用 COM8 進行通訊
        target_port = "COM8"
        print(f"\n[UI] 按下「連線鍵」，啟動 Background Thread 測試 {target_port}...")

        # 超時時間拉長為 5 秒，方便手動在 CoolTerm 輸入字串測試
        self.worker = SerialWorker(port=target_port, timeout=5.0)
        self.worker.result_signal.connect(self.handle_serial_result)
        self.worker.start()

    def handle_serial_result(self, response):
        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.setEnabled(True)

        if response is not None:
            print("[UI] 顯示 (a) 連線成功畫面")
            if self.line_order_id:
                self.line_order_id.setText("0102")
            if self.line_amount:
                self.line_amount.setText("00650040")
            if self.line_total:
                self.line_total.setText("0000")
        else:
            print("[UI] 顯示 (b) 連線失敗 / 錯誤碼 9999 畫面")
            if self.line_order_id:
                self.line_order_id.clear()
            if self.line_amount:
                self.line_amount.clear()
            if self.line_total:
                self.line_total.setText("9999")

    def on_clear_click(self):
        print("[UI] 按下「清除鍵」")
        if self.line_order_id:
            self.line_order_id.clear()
        if self.line_amount:
            self.line_amount.clear()
        if self.line_total:
            self.line_total.clear()


if __name__ == "__main__":
    app = QtWidgets.QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
