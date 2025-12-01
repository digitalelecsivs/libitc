import sys  # 匯入 sys 模組，才能使用 sys.stdin

print("請貼上您的字串 (可包含多行):")
print("--- (貼上後，請按 Ctrl+Z + Enter (Win) 或 Ctrl+D (Mac/Linux) 結束輸入) ---")

# 1. 使用 sys.stdin.read() 讀取「所有」輸入
#    這會讀取包含 \n 換行符號在內的所有文字
input_string = sys.stdin.read()

# 2. 清理字串：移除所有 \r 和 \n 字元
#    這和我們上一個版本做的事情一樣
cleaned_string = input_string.replace("\r", "").replace("\n", "")

print("--- 輸出結果 ---")

# 3. 遍歷 "清理過" 的字串
#    這樣索引就會是連續的
for index, char in enumerate(cleaned_string):

    # 4. 依照您要的格式印出結果
    print(f"{index} : {char} ;")
