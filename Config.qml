pragma Singleton

import Quickshell
import QtQuick

Singleton {
    id: root

    // ---- Geometry ----
    readonly property int iconSize: 35          // icon pixel size
    readonly property int cellPadding: 2        // padding around each icon inside its cell
    readonly property int spacing: 2            // gap between cells
    readonly property int dockPadding: 4        // padding inside the dock background
    readonly property int bottomMargin: 0      // gap between dock and screen edge
    readonly property int radius: 15           // dock background corner radius

    readonly property int cellSize: iconSize + cellPadding * 2

    // ---- Edge corners ----
    // Inverted (concave) corners that flare the dock into the screen edge, so
    // it looks like it grows out of the edge rather than ending in a hard
    // vertical line. Only drawn when the dock is actually flush with the edge,
    // which is what autoHide does; a floating dock has nothing to blend into.
    readonly property bool edgeCorners: true
    readonly property int cornerSize: 10

    // While the dock is only partially shown, the rounded top corner and the
    // edge fillet compete for the same sliver of height. This is the share the
    // fillet may claim; the rounded corner takes the rest. Lower = rounder
    // sliver with a subtler flare, 0 = no flare until it expands. Stops
    // mattering once the dock is fully out and both reach full size.
    readonly property real peekFilletShare: 0.25

    // ---- Source ----
    // "kickoff"     -> the Favorites list in the Application Launcher menu
    // "taskmanager" -> the pinned launchers on the Plasma task manager
    readonly property string source: "kickoff"

    // ---- Auto-hide ----
    // Slide the dock down until only a sliver is left, and bring it back when
    // the pointer reaches the bottom edge.
    readonly property bool autoHide: true
    readonly property int peekHeight: 16         // strip left visible when hidden
    // How solid that strip is. The dock fades to this as it slides away and
    // back to full strength as it returns. 0 makes it invisible while hidden,
    // which stays perfectly usable -- the pointer target doesn't fade with it.
    readonly property real peekOpacity: 0.4
    // Pointer-catching strip along the screen edge. Kept at least as tall as
    // peekHeight so the dock isn't fiddly to summon; it's invisible either way.
    readonly property int triggerHeight: 8
    readonly property int hideDelay: 250        // ms of no pointer before hiding
    // Grace period after revealing during which a momentary "nothing hovered"
    // is ignored. Sliding the plate out from under a stationary pointer briefly
    // looks like the pointer left, which would otherwise bounce the dock.
    readonly property int revealGrace: 300
    readonly property int slideDuration: 100

    // ---- Behaviour ----
    // true  -> dock reserves screen space (windows won't go under it)
    // false -> dock floats above windows without reserving space
    readonly property bool reserveSpace: false

    // Magnify icons on hover, like the macOS dock.
    readonly property bool hoverMagnify: true
    readonly property real hoverScale: 1.22

    // ---- Running apps ----
    // Clicking a running app raises its windows instead of starting a second
    // copy. With several windows open, repeat clicks step through them.
    readonly property bool raiseRunning: true

    // Badge in the icon's top-left corner, one dot per window, for apps that
    // are running. It sits on the icon rather than in a strip of its own, so
    // turning it on doesn't change the dock's size.
    readonly property bool runningIndicator: true
    readonly property int indicatorDotSize: 4
    readonly property int indicatorSpacing: 3
    readonly property int indicatorMaxDots: 3
    // How far the badge sits in from the icon's corner, per axis so it can ride
    // higher without also sliding inwards. Negative overhangs the icon.
    readonly property int indicatorInsetX: 2
    readonly property int indicatorInsetY: 0
    // Padding between the dots and the edge of their backing.
    readonly property int indicatorPadding: 3

    // Small button that floats above a running app's icon and opens another
    // window. Without it a running app's icon has no way to start a new one,
    // since clicking it raises what's already there.
    readonly property bool newInstanceButton: true
    readonly property int newInstanceSize: 20
    readonly property int newInstanceGap: 5     // gap between button and dock plate
    readonly property int newInstanceStroke: 2  // thickness of the "+"
    readonly property string newInstanceLabel: "New window"

    // ---- Appearance ----
    // Background colour and its opacity, kept separate so you can tune
    // translucency without hand-editing hex alpha.
    readonly property color backgroundColor: "#1c1f26"
    readonly property real backgroundOpacity: 0.8   // 0 = invisible, 1 = solid

    readonly property color background: Qt.rgba(
        backgroundColor.r, backgroundColor.g, backgroundColor.b, backgroundOpacity)

    // Hairline outline traced around the whole dock, fillets included.
    readonly property color border: "#33ffffff"
    readonly property real borderWidth: 1
    readonly property color hoverHighlight: "#22ffffff"
    readonly property color dragHighlight: "#33ffffff"
    // The badge lands on the artwork, which can be any colour, so it carries
    // its own backing -- pale dots disappear entirely on a white icon. Set it
    // to "transparent" for bare dots.
    readonly property color indicatorBackground: "#b3000000"
    readonly property color indicatorColor: "#ffa8e6a0"
    readonly property color indicatorActiveColor: "#ff52e05c"
    // Opaque enough to read against whatever window it floats over. The hover
    // state is a lighter version of the same neutral rather than an accent, so
    // the white "+" keeps its contrast.
    readonly property color newInstanceBackground: "#f5343b49"
    readonly property color newInstanceHoverBackground: "#ff4b5570"
    readonly property color newInstanceForeground: "#ffffff"
    readonly property color tooltipBackground: "#f01c1f26"
    readonly property color tooltipText: "#ffffff"
}
