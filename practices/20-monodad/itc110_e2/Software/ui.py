# -*- coding: utf-8 -*-

# Form implementation generated from reading ui file 'main.ui'
#
# Created by: PyQt5 UI code generator 5.5.1
#
# WARNING! All changes made in this file will be lost!

from PyQt5 import QtCore, QtGui, QtWidgets


class Ui_MainWindow(object):
    def setupUi(self, MainWindow):
        MainWindow.setObjectName("MainWindow")
        MainWindow.resize(620, 287)
        MainWindow.setStyleSheet("")
        self.centralwidget = QtWidgets.QWidget(MainWindow)
        self.centralwidget.setObjectName("centralwidget")
        self.background = QtWidgets.QLabel(self.centralwidget)
        self.background.setGeometry(QtCore.QRect(50, 80, 201, 131))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(15)
        self.background.setFont(font)
        self.background.setLayoutDirection(QtCore.Qt.LeftToRight)
        self.background.setAutoFillBackground(False)
        self.background.setStyleSheet(" background-color : #70DFF6;border : 1px solid black;")
        self.background.setText("")
        self.background.setObjectName("background")
        self.inpu_label = QtWidgets.QLabel(self.centralwidget)
        self.inpu_label.setGeometry(QtCore.QRect(60, 90, 91, 41))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(16)
        self.inpu_label.setFont(font)
        self.inpu_label.setLayoutDirection(QtCore.Qt.LeftToRight)
        self.inpu_label.setObjectName("inpu_label")
        self.textEdit = QtWidgets.QTextEdit(self.centralwidget)
        self.textEdit.setGeometry(QtCore.QRect(80, 140, 131, 41))
        self.textEdit.setReadOnly(True)
        self.textEdit.setObjectName("textEdit")
        self.bottom7 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom7.setGeometry(QtCore.QRect(300, 30, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom7.setFont(font)
        self.bottom7.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom7.setObjectName("bottom7")
        self.bottom8 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom8.setGeometry(QtCore.QRect(360, 30, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom8.setFont(font)
        self.bottom8.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom8.setObjectName("bottom8")
        self.bottom9 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom9.setGeometry(QtCore.QRect(420, 30, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom9.setFont(font)
        self.bottom9.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom9.setObjectName("bottom9")
        self.bottom4 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom4.setGeometry(QtCore.QRect(300, 90, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom4.setFont(font)
        self.bottom4.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom4.setObjectName("bottom4")
        self.bottom5 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom5.setGeometry(QtCore.QRect(360, 90, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom5.setFont(font)
        self.bottom5.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom5.setObjectName("bottom5")
        self.bottom6 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom6.setGeometry(QtCore.QRect(420, 90, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom6.setFont(font)
        self.bottom6.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom6.setObjectName("bottom6")
        self.bottom1 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom1.setGeometry(QtCore.QRect(300, 150, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom1.setFont(font)
        self.bottom1.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom1.setObjectName("bottom1")
        self.bottom2 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom2.setGeometry(QtCore.QRect(360, 150, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom2.setFont(font)
        self.bottom2.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom2.setObjectName("bottom2")
        self.bottom3 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom3.setGeometry(QtCore.QRect(420, 150, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom3.setFont(font)
        self.bottom3.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom3.setObjectName("bottom3")
        self.bottom0 = QtWidgets.QPushButton(self.centralwidget)
        self.bottom0.setGeometry(QtCore.QRect(360, 210, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom0.setFont(font)
        self.bottom0.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom0.setObjectName("bottom0")
        self.bottom7_null = QtWidgets.QPushButton(self.centralwidget)
        self.bottom7_null.setGeometry(QtCore.QRect(300, 210, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom7_null.setFont(font)
        self.bottom7_null.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom7_null.setText("")
        self.bottom7_null.setObjectName("bottom7_null")
        self.bottom_null = QtWidgets.QPushButton(self.centralwidget)
        self.bottom_null.setGeometry(QtCore.QRect(420, 210, 51, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom_null.setFont(font)
        self.bottom_null.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom_null.setText("")
        self.bottom_null.setObjectName("bottom_null")
        self.bottom_clear = QtWidgets.QPushButton(self.centralwidget)
        self.bottom_clear.setGeometry(QtCore.QRect(490, 30, 91, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom_clear.setFont(font)
        self.bottom_clear.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom_clear.setObjectName("bottom_clear")
        self.bottom_back = QtWidgets.QPushButton(self.centralwidget)
        self.bottom_back.setGeometry(QtCore.QRect(490, 90, 91, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom_back.setFont(font)
        self.bottom_back.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom_back.setObjectName("bottom_back")
        self.bottom_send = QtWidgets.QPushButton(self.centralwidget)
        self.bottom_send.setGeometry(QtCore.QRect(490, 150, 91, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottom_send.setFont(font)
        self.bottom_send.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottom_send.setObjectName("bottom_send")
        self.bottomNULL = QtWidgets.QPushButton(self.centralwidget)
        self.bottomNULL.setGeometry(QtCore.QRect(490, 210, 91, 51))
        font = QtGui.QFont()
        font.setFamily("微軟正黑體")
        font.setPointSize(20)
        self.bottomNULL.setFont(font)
        self.bottomNULL.setStyleSheet("background-color:#E5DADB; border : 1px solid ;border-radius : 8px;")
        self.bottomNULL.setText("")
        self.bottomNULL.setObjectName("bottomNULL")
        self.widget = QtWidgets.QWidget(self.centralwidget)
        self.widget.setGeometry(QtCore.QRect(290, 19, 301, 251))
        self.widget.setStyleSheet("border : 3px solid;")
        self.widget.setObjectName("widget")
        MainWindow.setCentralWidget(self.centralwidget)

        self.retranslateUi(MainWindow)
        QtCore.QMetaObject.connectSlotsByName(MainWindow)

    def retranslateUi(self, MainWindow):
        _translate = QtCore.QCoreApplication.translate
        MainWindow.setWindowTitle(_translate("MainWindow", "MainWindow"))
        self.inpu_label.setText(_translate("MainWindow", "輸入數字"))
        self.bottom7.setText(_translate("MainWindow", "7"))
        self.bottom8.setText(_translate("MainWindow", "8"))
        self.bottom9.setText(_translate("MainWindow", "9"))
        self.bottom4.setText(_translate("MainWindow", "4"))
        self.bottom5.setText(_translate("MainWindow", "5"))
        self.bottom6.setText(_translate("MainWindow", "6"))
        self.bottom1.setText(_translate("MainWindow", "1"))
        self.bottom2.setText(_translate("MainWindow", "2"))
        self.bottom3.setText(_translate("MainWindow", "3"))
        self.bottom0.setText(_translate("MainWindow", "0"))
        self.bottom_clear.setText(_translate("MainWindow", "清除"))
        self.bottom_back.setText(_translate("MainWindow", "返回"))
        self.bottom_send.setText(_translate("MainWindow", "送出"))


if __name__ == "__main__":
    import sys
    app = QtWidgets.QApplication(sys.argv)
    MainWindow = QtWidgets.QMainWindow()
    ui = Ui_MainWindow()
    ui.setupUi(MainWindow)
    MainWindow.show()
    sys.exit(app.exec_())

