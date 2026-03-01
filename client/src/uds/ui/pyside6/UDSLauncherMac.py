# -*- coding: utf-8 -*-

################################################################################
## Form generated from reading UI file 'UDSLauncherMac.ui'
##
## Created by: Qt User Interface Compiler version 6.10.1
##
## WARNING! All changes made in this file will be lost when recompiling UI file!
################################################################################

from PySide6.QtCore import (QCoreApplication, QDate, QDateTime, QLocale,
    QMetaObject, QObject, QPoint, QRect,
    QSize, QTime, QUrl, Qt)
from PySide6.QtGui import (QBrush, QColor, QConicalGradient, QCursor,
    QFont, QFontDatabase, QGradient, QIcon,
    QImage, QKeySequence, QLinearGradient, QPainter,
    QPalette, QPixmap, QRadialGradient, QTransform)
from PySide6.QtWidgets import (QApplication, QFrame, QLabel, QMainWindow,
    QSizePolicy, QVBoxLayout, QWidget)
from . import UDSResources_rc

class Ui_MacLauncher(object):
    def setupUi(self, MacLauncher):
        if not MacLauncher.objectName():
            MacLauncher.setObjectName(u"MacLauncher")
        MacLauncher.setWindowModality(Qt.NonModal)
        MacLauncher.resize(235, 120)
        MacLauncher.setCursor(QCursor(Qt.CursorShape.ArrowCursor))
        icon = QIcon()
        icon.addFile(u":/images/logo-uds-small", QSize(), QIcon.Mode.Normal, QIcon.State.Off)
        MacLauncher.setWindowIcon(icon)
        MacLauncher.setWindowOpacity(1.000000000000000)
        self.centralwidget = QWidget(MacLauncher)
        self.centralwidget.setObjectName(u"centralwidget")
        self.centralwidget.setAutoFillBackground(True)
        self.verticalLayout_2 = QVBoxLayout(self.centralwidget)
        self.verticalLayout_2.setSpacing(4)
        self.verticalLayout_2.setObjectName(u"verticalLayout_2")
        self.verticalLayout_2.setContentsMargins(4, 4, 4, 4)
        self.frame = QFrame(self.centralwidget)
        self.frame.setObjectName(u"frame")
        self.frame.setFrameShape(QFrame.StyledPanel)
        self.frame.setFrameShadow(QFrame.Raised)
        self.verticalLayout = QVBoxLayout(self.frame)
        self.verticalLayout.setObjectName(u"verticalLayout")
        self.topLabel = QLabel(self.frame)
        self.topLabel.setObjectName(u"topLabel")
        self.topLabel.setTextFormat(Qt.RichText)

        self.verticalLayout.addWidget(self.topLabel)

        self.image = QLabel(self.frame)
        self.image.setObjectName(u"image")
        self.image.setMinimumSize(QSize(0, 32))
        self.image.setAutoFillBackground(True)
        self.image.setText(u"")
        self.image.setPixmap(QPixmap(u":/images/logo-uds-small"))
        self.image.setScaledContents(False)
        self.image.setAlignment(Qt.AlignCenter)

        self.verticalLayout.addWidget(self.image)

        self.label_2 = QLabel(self.frame)
        self.label_2.setObjectName(u"label_2")
        self.label_2.setTextFormat(Qt.RichText)

        self.verticalLayout.addWidget(self.label_2)


        self.verticalLayout_2.addWidget(self.frame)

        MacLauncher.setCentralWidget(self.centralwidget)

        self.retranslateUi(MacLauncher)

        QMetaObject.connectSlotsByName(MacLauncher)
    # setupUi

    def retranslateUi(self, MacLauncher):
        MacLauncher.setWindowTitle(QCoreApplication.translate("MacLauncher", u"UDS Launcher", None))
        self.topLabel.setText(QCoreApplication.translate("MacLauncher", u"<html><head/><body><p align=\"center\"><span style=\" font-size:12pt; font-weight:600;\">UDS Launcher</span></p></body></html>", None))
        self.label_2.setText(QCoreApplication.translate("MacLauncher", u"<html><head/><body><p align=\"center\"><span style=\" font-size:6pt;\">Closing this window will end all UDS tunnels</span></p></body></html>", None))
    # retranslateUi

