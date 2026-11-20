import sys

import serial
from PyQt5 import uic  # 使用 uic 動態載入
from PyQt5.QtCore import QThread, pyqtSignal
from PyQt5.QtWidgets import QApplication, QLineEdit, QMainWindow

# 直接載入 .ui 檔案
Ui_MainWindow, QtBaseClass = uic.loadUiType("ui.ui")


class SerialWorker(QThread):
    result_signal = pyqtSignal(bool, str)

    def __init__(self, port, request_cmd, baudrate=9600, timeout=2.0):
        super().__init__()
        self.port = port
        self.request_cmd = request_cmd
        self.baudrate = baudrate
        self.timeout = timeout

    def run(self):
        ser = None
        try:
            ser = serial.Serial(self.port, self.baudrate, timeout=self.timeout)
            print(f"[UART] 開啟 {self.port} 成功，發送: {repr(self.request_cmd)}")

            # 1. 發送封包 (純 STX + 指令 + ETX)
            ser.write(self.request_cmd.encode("ascii"))

            # 2. 精準讀取回應 (以 \x03 ETX 作為結束標記)
            response_bytes = bytearray()
            while True:
                b = ser.read(1)
                if not b:  # Timeout 沒收到資料
                    break
                response_bytes.extend(b)
                if b == b"\x03":  # 收到 ETX 結束標記，完成接收
                    break

            response = response_bytes.decode("ascii", errors="ignore").strip()

            if response:
                print(f"[UART] 收到回應: {repr(response)}")
                self.result_signal.emit(True, response)
            else:
                print("[UART] 接收逾時，未收到回應")
                self.result_signal.emit(False, "TIMEOUT")

        except Exception as e:
            print(f"[UART] 通訊例外: {e}")
            self.result_signal.emit(False, str(e))
        finally:
            if ser and ser.is_open:
                ser.close()


class MainWindow(QMainWindow, Ui_MainWindow):
    def __init__(self):
        super().__init__()
        self.setupUi(self)

        # ------------------------------------------------------------------
        # 1. 綁定數字按鈕 (0 ~ 9)
        # ------------------------------------------------------------------
        for i in range(10):
            btn = getattr(self, f"pushButton_{i}", None)
            if btn is not None:
                btn.clicked.connect(lambda checked, n=str(i): self.on_num_click(n))

        if hasattr(self, "pushButton_back"):
            self.pushButton_back.clicked.connect(self.on_backspace_click)
        if hasattr(self, "pushButton_clear"):
            self.pushButton_clear.clicked.connect(self.on_clear_click)

        # ------------------------------------------------------------------
        # 2. 綁定連線與查詢功能按鈕
        # ------------------------------------------------------------------
        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.clicked.connect(self.on_connect_click)
        if hasattr(self, "pushButton_query"):
            self.pushButton_query.clicked.connect(self.on_query_click)

    # ----------------------------------------------------------------------
    # UI 文字框與鍵盤輔助邏輯
    # ----------------------------------------------------------------------
    def get_first_line_edit(self):
        """獲取第一欄位 (輸入框) 的元件物件"""
        return (
            getattr(self, "line_res_id", None)
            or getattr(self, "line_order_id", None)
            or getattr(self, "lineEdit", None)
        )

    def on_num_click(self, num_str):
        """點擊 0~9 按鈕追加數字"""
        target_input = self.get_first_line_edit()
        if target_input:
            current_text = target_input.text().strip()
            if len(current_text) < 4:
                target_input.setText(current_text + num_str)

    def on_backspace_click(self):
        """退格刪除一個數字"""
        target_input = self.get_first_line_edit()
        if target_input:
            target_input.setText(target_input.text().strip()[:-1])

    def on_clear_click(self):
        """點擊「清除」：清空所有 LineEdit 欄位內容"""
        target_id = self.get_first_line_edit()
        target_oq = getattr(self, "line_res_oq", None) or getattr(
            self, "lineEdit_2", None
        )
        target_sq = getattr(self, "line_res_sq", None) or getattr(
            self, "lineEdit_3", None
        )

        if target_id:
            target_id.clear()
        if target_oq:
            target_oq.clear()
        if target_sq:
            target_sq.clear()

        print("[UI] 已清空所有欄位內容")

    # ----------------------------------------------------------------------
    # 連線邏輯 (Mode 3: 動態讀取硬體回傳之 OQ)
    # ----------------------------------------------------------------------
    def on_connect_click(self):
        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.setEnabled(False)

        target_port = "COM6"  # 請依裝置管理員實際 COM 號碼修改
        request_cmd = "\x02CONNECT\x03"
        print(f"\n[UI] 發送連線請求: {repr(request_cmd)}")

        self.worker = SerialWorker(
            port=target_port, request_cmd=request_cmd, timeout=2.0
        )
        self.worker.result_signal.connect(self.handle_connect_result)
        self.worker.start()

    def handle_connect_result(self, success, response):
        if hasattr(self, "pushButton_connect"):
            self.pushButton_connect.setEnabled(True)

        target_id = self.get_first_line_edit()
        target_oq = getattr(self, "line_res_oq", None) or getattr(
            self, "lineEdit_2", None
        )
        target_sq = getattr(self, "line_res_sq", None) or getattr(
            self, "lineEdit_3", None
        )

        if success:
            # 去除 STX / ETX 標籤
            clean_resp = response.replace("\x02", "").replace("\x03", "").strip()
            print(f"[UI] 解析連線回應: {clean_resp}")

            try:
                # 假設回傳格式為: ID0102OQ00650040
                order_ids = clean_resp[2:6]  # 擷取 "0102"
                oq_data = clean_resp[8:]  # 動態擷取硬體回傳的 OQ 數量 (如 "00650040")

                if target_id:
                    target_id.setText(order_ids)
                if target_oq:
                    target_oq.setText(oq_data)
                if target_sq:
                    target_sq.setText("0000")
            except Exception as e:
                print(f"[UI Error] 連線封包解析失敗: {e}")
                # 備援預設值
                if target_id:
                    target_id.setText("0102")
                if target_oq:
                    target_oq.setText("00650040")
                if target_sq:
                    target_sq.setText("0000")
        else:
            print("[UI] 連線失敗/逾時！第三欄位顯示 9999")
            if target_sq:
                target_sq.setText("9999")

    # ----------------------------------------------------------------------
    # 查詢邏輯 (Mode 4: 濾除 "SQ" 前綴)
    # ----------------------------------------------------------------------
    def on_query_click(self):
        target_id_widget = self.get_first_line_edit()
        query_id = target_id_widget.text().strip() if target_id_widget else ""

        if not query_id:
            return

        if hasattr(self, "pushButton_query"):
            self.pushButton_query.setEnabled(False)

        target_port = "COM6"
        request_cmd = f"\x02{query_id}\x03"
        print(f"\n[UI] 發送查詢請求: {repr(request_cmd)}")

        self.worker = SerialWorker(
            port=target_port, request_cmd=request_cmd, timeout=2.0
        )
        self.worker.result_signal.connect(self.handle_query_result)
        self.worker.start()

    def handle_query_result(self, success, response):
        if hasattr(self, "pushButton_query"):
            self.pushButton_query.setEnabled(True)

        target_id = self.get_first_line_edit()
        target_oq = getattr(self, "line_res_oq", None) or getattr(
            self, "lineEdit_2", None
        )
        target_sq = getattr(self, "line_res_sq", None) or getattr(
            self, "lineEdit_3", None
        )

        if success:
            # 濾掉封包的 STX/ETX
            clean_resp = response.replace("\x02", "").replace("\x03", "").strip()
            print(f"[UI] 解析硬體回應: {clean_resp}")

            try:
                # 格式: ID9901OQ00650070SQ#30$2100
                order_id = clean_resp[2:6]
                oq_data = clean_resp[8:16]

                # 擷取 SQ 後方的字串 (去頭去尾只留 "#30$2100")
                sq_raw = clean_resp[16:]
                if sq_raw.startswith("SQ"):
                    sq_display = sq_raw[2:]  # 移除 "SQ"
                else:
                    sq_display = sq_raw

                if target_id:
                    target_id.setText(order_id)
                if target_oq:
                    target_oq.setText(oq_data)
                if target_sq:
                    target_sq.setText(sq_display)  # 顯示 "#30$2100" 或 "#65$4550"
            except Exception as e:
                print(f"[UI Error] 欄位解析失敗: {e}")
        else:
            print("[UI Error] 查詢失敗或逾時")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())
