import QtQuick
import QtQuick.Shapes
import "../theme"

Shape {
    id: root

    property string edge: "bottom"
    property real notchWidth: 0.001
    property real notchDepth: 0.001
    property real radius: Theme.cornerRadius
    property real flare: Theme.cornerRadius
    property color color: Theme.ground

    width: notchWidth + 2 * flare
    height: notchDepth

    readonly property real fr: Math.min(flare, notchDepth)
    readonly property real r:  Math.min(radius, notchDepth)
    readonly property real x0: flare
    readonly property real x1: flare + notchWidth

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.color
        strokeColor: "transparent"
        strokeWidth: 0

        startX: root.x0 - root.fr; startY: root.height
        PathArc { x: root.x0; y: root.height - root.fr; radiusX: root.fr; radiusY: root.fr; direction: PathArc.Counterclockwise }
        PathLine { x: root.x0; y: root.r }
        PathArc { x: root.x0 + root.r; y: 0; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
        PathLine { x: root.x1 - root.r; y: 0 }
        PathArc { x: root.x1; y: root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Clockwise }
        PathLine { x: root.x1; y: root.height - root.fr }
        PathArc { x: root.x1 + root.fr; y: root.height; radiusX: root.fr; radiusY: root.fr; direction: PathArc.Counterclockwise }
        PathLine { x: root.x0 - root.fr; y: root.height }
    }

    transform: Scale {
        origin.y: root.height / 2
        yScale: root.edge === "top" ? -1 : 1
    }
}
