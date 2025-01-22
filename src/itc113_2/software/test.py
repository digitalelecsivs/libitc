import serial
import threading


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


def main():
    # 配置串口
    ser = serial.Serial(
        port="COM14",  # 替換為你的串口名稱
        baudrate=115200,  # 波特率
        timeout=0.1,  # 超時（秒）
    )

    if ser.is_open:
        print(f"串口 {ser.name} 已打開")

    # 創建一個線程來處理讀取
    reader_thread = threading.Thread(target=read_from_serial, args=(ser,))
    reader_thread.daemon = True  # 設置為守護線程，主程序結束時自動退出
    reader_thread.start()

    try:
        while True:
            # 主線程可以執行其他任務，例如發送數據
            send_data = input("輸入要發送的數據: ")
            if send_data.lower() == "exit":
                print("退出程序")
                break
            ser.write(send_data.encode("utf-8"))  # 發送數據
    except KeyboardInterrupt:
        print("退出程序")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
