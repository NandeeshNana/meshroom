import QtQuick 2.9
import QtQuick.Controls 2.3
import QtQuick.Layouts 1.3
import QtGraphicalEffects 1.0

import Utils 1.0
import MaterialIcons 2.2


/**
 * Visual representation of a Graph Node.
 */
Item {
    id: root

    /// The underlying Node object
    property variant node
    /// Whether the node can be modified
    property bool readOnly: node.locked
    /// Whether the node is in compatibility mode
    readonly property bool isCompatibilityNode: node.hasOwnProperty("compatibilityIssue")
    /// Mouse related states
    property bool selected: false
    property bool hovered: false
    /// Styling
    property color shadowColor: "#cc000000"
    readonly property color defaultColor: isCompatibilityNode ? "#444" : activePalette.base
    property color baseColor: defaultColor

    // Mouse interaction related signals
    signal pressed(var mouse)
    signal doubleClicked(var mouse)
    signal moved(var position)
    signal entered()
    signal exited()

    /// Emitted when child attribute pins are created
    signal attributePinCreated(var attribute, var pin)
    /// Emitted when child attribute pins are deleted
    signal attributePinDeleted(var attribute, var pin)

    // use node name as object name to simplify debugging
    objectName: node.name

    // initialize position with node coordinates
    x: root.node.x
    y: root.node.y

    implicitHeight: childrenRect.height

    SystemPalette { id: activePalette }

    Connections {
        target: root.node
        // update x,y when node position changes
        onPositionChanged: {
            root.x = root.node.x
            root.y = root.node.y
        }
    }

    // Whether an attribute can be displayed as an attribute pin on the node
    function isDisplayableAsPin(attribute) {
        // ATM, only File attributes are meant to be connected
        // TODO: review this if we want to connect something else
        return attribute.type == "File"
               || (attribute.type == "ListAttribute" && attribute.desc.elementDesc.type == "File")
    }


    // Main Layout
    MouseArea {
        width: parent.width
        height: body.height
        drag.target: root
        // small drag threshold to avoid moving the node by mistake
        drag.threshold: 2
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.pressed(mouse)
        onDoubleClicked: root.doubleClicked(mouse)
        onEntered: root.entered()
        onExited: root.exited()
        drag.onActiveChanged: {
            if(!drag.active)
            {
                root.moved(Qt.point(root.x, root.y));
            }
        }

        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor

        // Selection border
        Rectangle {
            anchors.fill: parent
            anchors.margins: -border.width
            visible: root.selected || root.hovered
            border.width: 2.5
            border.color: root.selected ? activePalette.highlight : Qt.darker(activePalette.highlight, 1.5)
            opacity: 0.9
            radius: background.radius
            color: "transparent"
        }

        // Background
        Rectangle {
            id: background
            anchors.fill: parent
            color: Qt.lighter(activePalette.base, 1.4)
            layer.enabled: true
            layer.effect: DropShadow { radius: 3; color: shadowColor }
            radius: 3
            opacity: 0.7
        }

        // Data Layout
        Column {
            id: body
            width: parent.width

            // Header
            Rectangle {
                id: header
                width: parent.width
                height: headerLayout.height
                color: root.selected ? activePalette.highlight : root.baseColor
                radius: background.radius

                // Fill header's bottom radius
                Rectangle {
                    width: parent.width
                    height: parent.radius
                    anchors.bottom: parent.bottom
                    color: parent.color
                    z: -1
                }

                // Header Layout
                RowLayout {
                    id: headerLayout
                    width: parent.width
                    spacing: 0

                    // Node Name
                    Label {
                        Layout.fillWidth: true
                        text: node.label
                        padding: 4
                        color: root.selected ? "white" : activePalette.text
                        elide: Text.ElideMiddle
                        font.pointSize: 8
                    }

                    // Node State icons
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 2
                        spacing: 2

                        // Data sharing indicator
                        MaterialToolButton {
                            visible: node.chunks.count > 0 && node.globalStatus !== "NONE" && node.chunks.at(0).statusNodeName !== node.name
                            text: MaterialIcons.layers
                            font.pointSize: 7
                            padding: 2
                            palette.text: Colors.sysPalette.text
                            ToolTip.text: visible ? "Data has been computed by <b>" + node.nameToLabel(node.chunks.at(0).statusNodeName) + "</b>" : ""
                        }

                        // Submitted externally indicator
                        MaterialLabel {
                            visible: ["SUBMITTED", "RUNNING"].includes(node.globalStatus) && node.chunks.count > 0 && node.chunks.at(0).execModeName === "EXTERN"
                            text: MaterialIcons.cloud
                            padding: 2
                            font.pointSize: 7
                            palette.text: Colors.sysPalette.text
                            ToolTip.text: "Computed Externally"
                        }

                        // Lock indicator
                        MaterialLabel {
                            visible: root.readOnly
                            text: MaterialIcons.lock
                            padding: 2
                            font.pointSize: 7
                            palette.text: "red"
                            ToolTip.text: "Locked"
                        }
                    }
                }
            }

            // Node Chunks
           NodeChunks {
               defaultColor: Colors.sysPalette.mid
               implicitHeight: 3
               width: parent.width
               model: node.chunks

               Rectangle {
                   anchors.fill: parent
                   color: Colors.sysPalette.mid
                   z: -1
               }
           }

            // Vertical Spacer
            Item { width: parent.width; height: 2 }

            // Input/Output Attributes
            Item {
                id: nodeAttributes
                width: parent.width - 2
                height: childrenRect.height
                anchors.horizontalCenter: parent.horizontalCenter

                enabled: !root.readOnly && !root.isCompatibilityNode

                Column {
                    width: parent.width
                    spacing: 5
                    bottomPadding: 2

                    Column {
                        id: outputs
                        width: parent.width
                        spacing: 3
                        Repeater {
                            model: node.attributes

                            delegate: Loader {
                                id: outputLoader
                                active: object.isOutput && isDisplayableAsPin(object)
                                anchors.right: parent.right
                                width: outputs.width

                                sourceComponent: AttributePin {
                                    id: outPin
                                    nodeItem: root
                                    attribute: object

                                    readOnly: root.readOnly
                                    onPressed: root.pressed(mouse)
                                    Component.onCompleted: attributePinCreated(object, outPin)
                                    Component.onDestruction: attributePinDeleted(attribute, outPin)
                                }
                            }
                        }
                    }

                    Column {
                        id: inputs
                        width: parent.width
                        spacing: 3
                        Repeater {
                            model: node.attributes
                            delegate: Loader {
                                active: !object.isOutput && isDisplayableAsPin(object)
                                width: inputs.width

                                sourceComponent: AttributePin {
                                    id: inPin
                                    nodeItem: root
                                    attribute: object
                                    readOnly: root.readOnly
                                    Component.onCompleted: attributePinCreated(attribute, inPin)
                                    Component.onDestruction: attributePinDeleted(attribute, inPin)
                                    onPressed: root.pressed(mouse)
                                    onChildPinCreated: attributePinCreated(childAttribute, inPin)
                                    onChildPinDeleted: attributePinDeleted(childAttribute, inPin)
                                }
                            }
                        }
                    }
                }
            }
        }

        // CompatibilityBadge icon for CompatibilityNodes
        Loader {
            active: root.isCompatibilityNode
            anchors {
                right: parent.right
                top: parent.top
                margins: -4
            }
            sourceComponent: CompatibilityBadge {
                sourceComponent: iconDelegate
                canUpgrade: root.node.canUpgrade
                issueDetails: root.node.issueDetails
            }
        }
    }
}

