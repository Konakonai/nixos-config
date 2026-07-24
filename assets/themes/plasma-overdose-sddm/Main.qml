import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts

Item {
    id: root

    width: 1600
    height: 900

    readonly property color accent: config.accent
    readonly property color accentSoft: config.accentSoft
    readonly property color surface: config.surface
    readonly property color surfaceAlt: config.surfaceAlt
    readonly property color textColor: config.textColor
    readonly property color mutedText: config.mutedText
    readonly property color outline: config.outline
    readonly property color shadowColor: config.shadowColor
    readonly property string uiFont: config.fontFamily

    property bool authenticating: false
    property string statusMessage: ""
    property date now: new Date()

    function attemptLogin() {
        if (usernameField.text.length === 0 || authenticating) {
            return
        }

        authenticating = true
        statusMessage = "正在验证…"
        sddm.login(usernameField.text, passwordField.text, sessionSelector.currentIndex)
    }

    component ClassicButton: FocusScope {
        id: button

        property string text: ""
        property bool primary: false
        signal clicked()

        implicitWidth: 116
        implicitHeight: 42
        activeFocusOnTab: enabled
        opacity: enabled ? 1 : 0.48

        Rectangle {
            anchors.fill: parent
            color: button.primary
                ? (buttonMouse.pressed ? root.accentSoft : root.accent)
                : (buttonMouse.pressed ? root.accentSoft : root.surfaceAlt)
            border.width: 2
            border.color: root.accent
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 3
                topMargin: 3
            }
            width: parent.width - 6
            height: 1
            color: button.primary ? "#80ffffff" : "#ffffff"
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 3
                topMargin: 3
            }
            width: 1
            height: parent.height - 6
            color: button.primary ? "#80ffffff" : "#ffffff"
        }

        Rectangle {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 3
                bottomMargin: 3
            }
            width: parent.width - 6
            height: 1
            color: root.shadowColor
        }

        Rectangle {
            anchors {
                right: parent.right
                bottom: parent.bottom
                rightMargin: 3
                bottomMargin: 3
            }
            width: 1
            height: parent.height - 6
            color: root.shadowColor
        }

        Text {
            anchors.centerIn: parent
            text: button.text
            color: button.primary ? "#ffffff" : root.textColor
            font.family: root.uiFont
            font.pixelSize: 15
            font.bold: button.primary
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: 5
            color: "transparent"
            border.width: button.activeFocus ? 1 : 0
            border.color: button.primary ? "#ffffff" : root.accent
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            enabled: button.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                button.forceActiveFocus()
                button.clicked()
            }
        }

        Keys.onSpacePressed: if (enabled) clicked()
        Keys.onEnterPressed: if (enabled) clicked()
        Keys.onReturnPressed: if (enabled) clicked()
    }

    component ClassicField: FocusScope {
        id: field

        property alias text: input.text
        property string placeholderText: ""
        property bool passwordMode: false
        signal accepted()

        implicitHeight: 44
        activeFocusOnTab: true

        function activate() {
            input.forceActiveFocus()
        }

        function selectAll() {
            input.selectAll()
        }

        Rectangle {
            anchors.fill: parent
            color: "#ffffff"
            border.width: 2
            border.color: field.activeFocus ? root.accent : root.outline
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 3
                topMargin: 3
            }
            width: parent.width - 6
            height: 1
            color: root.shadowColor
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                leftMargin: 3
                topMargin: 3
            }
            width: 1
            height: parent.height - 6
            color: root.shadowColor
        }

        Text {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 13
                rightMargin: 13
            }
            visible: input.text.length === 0
            text: field.placeholderText
            color: root.mutedText
            font.family: root.uiFont
            font.pixelSize: 15
            elide: Text.ElideRight
        }

        TextInput {
            id: input
            anchors {
                fill: parent
                leftMargin: 13
                rightMargin: 13
            }
            verticalAlignment: TextInput.AlignVCenter
            color: root.textColor
            selectionColor: root.accent
            selectedTextColor: "#ffffff"
            font.family: root.uiFont
            font.pixelSize: 16
            echoMode: field.passwordMode ? TextInput.Password : TextInput.Normal
            passwordCharacter: "●"
            passwordMaskDelay: 450
            clip: true
            onAccepted: field.accepted()
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Repeater {
        model: screenModel

        Item {
            x: geometry.x
            y: geometry.y
            width: geometry.width
            height: geometry.height

            Rectangle {
                anchors.fill: parent
                color: config.backgroundColor
            }

            Image {
                anchors.fill: parent
                source: config.background
                sourceSize.width: width
                sourceSize.height: height
                fillMode: Image.PreserveAspectCrop
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#18f6e0f8"
            }
        }
    }

    Rectangle {
        id: cardShadow
        width: loginCard.width
        height: loginCard.height
        x: loginCard.x + 7
        y: loginCard.y + 7
        color: "#704d21cb"
    }

    Rectangle {
        id: loginCard
        width: Math.min(530, root.width - 48)
        height: 510
        anchors.centerIn: parent
        color: root.surface
        border.width: 2
        border.color: root.accent

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                right: parent.right
                margins: 4
            }
            height: 1
            color: "#ffffff"
        }

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                margins: 4
            }
            width: 1
            color: "#ffffff"
        }

        Rectangle {
            id: titleBar
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 7
            }
            height: 42
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "#4d21cb" }
                GradientStop { position: 1; color: "#8c4dff" }
            }

            Text {
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 13
                }
                text: "PLASMA OVERDOSE // LOGIN"
                color: "#ffffff"
                font.family: root.uiFont
                font.pixelSize: 15
                font.bold: true
            }

            Text {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 13
                }
                text: Qt.formatTime(root.now, "HH:mm")
                color: "#ffffff"
                font.family: root.uiFont
                font.pixelSize: 16
                font.bold: true
            }
        }

        ColumnLayout {
            anchors {
                left: parent.left
                right: parent.right
                top: titleBar.bottom
                bottom: parent.bottom
                leftMargin: 34
                rightMargin: 34
                topMargin: 24
                bottomMargin: 24
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: "欢迎回来，" + (usernameField.text.length > 0 ? usernameField.text : "USER")
                        color: root.textColor
                        font.family: root.uiFont
                        font.pixelSize: 23
                        font.bold: true
                    }

                    Text {
                        text: Qt.formatDate(root.now, "yyyy / MM / dd  dddd")
                        color: root.mutedText
                        font.family: root.uiFont
                        font.pixelSize: 13
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 42
                    height: 42
                    color: root.accentSoft
                    border.width: 2
                    border.color: root.accent

                    Text {
                        anchors.centerIn: parent
                        text: "◆"
                        color: root.accent
                        font.pixelSize: 20
                    }
                }
            }

            Text {
                text: "用户名"
                color: root.textColor
                font.family: root.uiFont
                font.pixelSize: 13
                font.bold: true
            }

            ClassicField {
                id: usernameField
                Layout.fillWidth: true
                text: userModel.lastUser
                placeholderText: "输入用户名"
                enabled: !root.authenticating
                onAccepted: passwordField.activate()
            }

            Text {
                text: "密码"
                color: root.textColor
                font.family: root.uiFont
                font.pixelSize: 13
                font.bold: true
            }

            ClassicField {
                id: passwordField
                Layout.fillWidth: true
                passwordMode: true
                placeholderText: "输入密码"
                enabled: !root.authenticating
                onAccepted: root.attemptLogin()
            }

            Text {
                text: "桌面会话"
                color: root.textColor
                font.family: root.uiFont
                font.pixelSize: 13
                font.bold: true
            }

            Controls.ComboBox {
                id: sessionSelector
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                model: sessionModel
                textRole: "name"
                currentIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
                enabled: !root.authenticating

                contentItem: Text {
                    leftPadding: 13
                    rightPadding: 38
                    text: sessionSelector.displayText
                    color: root.textColor
                    font.family: root.uiFont
                    font.pixelSize: 15
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                indicator: Text {
                    x: sessionSelector.width - width - 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▼"
                    color: root.accent
                    font.pixelSize: 13
                }

                background: Rectangle {
                    color: "#ffffff"
                    border.width: 2
                    border.color: sessionSelector.activeFocus ? root.accent : root.outline
                }

                delegate: Controls.ItemDelegate {
                    required property var model
                    required property int index

                    width: sessionSelector.width
                    height: 38
                    highlighted: sessionSelector.highlightedIndex === index

                    contentItem: Text {
                        text: model.name
                        color: root.textColor
                        font.family: root.uiFont
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: highlighted ? root.accentSoft : root.surface
                        border.width: 1
                        border.color: root.outline
                    }
                }

                popup: Controls.Popup {
                    y: sessionSelector.height - 2
                    width: sessionSelector.width
                    implicitHeight: contentItem.implicitHeight + 4
                    padding: 2

                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: sessionSelector.popup.visible ? sessionSelector.delegateModel : null
                        currentIndex: sessionSelector.highlightedIndex
                    }

                    background: Rectangle {
                        color: root.surface
                        border.width: 2
                        border.color: root.accent
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
                text: root.statusMessage
                color: root.statusMessage === "登录失败" ? "#b00020" : root.mutedText
                font.family: root.uiFont
                font.pixelSize: 13
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            ClassicButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                text: root.authenticating ? "请稍候…" : "登录"
                primary: true
                enabled: !root.authenticating
                onClicked: root.attemptLogin()
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ClassicButton {
                    Layout.fillWidth: true
                    text: "睡眠"
                    enabled: sddm.canSuspend && !root.authenticating
                    onClicked: sddm.suspend()
                }

                ClassicButton {
                    Layout.fillWidth: true
                    text: "重启"
                    enabled: sddm.canReboot && !root.authenticating
                    onClicked: sddm.reboot()
                }

                ClassicButton {
                    Layout.fillWidth: true
                    text: "关机"
                    enabled: sddm.canPowerOff && !root.authenticating
                    onClicked: sddm.powerOff()
                }
            }
        }
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root.authenticating = false
            root.statusMessage = "登录失败"
            passwordField.selectAll()
            passwordField.activate()
        }

        function onLoginSucceeded() {
            root.statusMessage = "登录成功"
        }
    }

    Component.onCompleted: {
        if (usernameField.text.length > 0) {
            passwordField.activate()
        } else {
            usernameField.activate()
        }
    }
}
