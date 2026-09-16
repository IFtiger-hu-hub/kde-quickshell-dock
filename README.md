# kde-quickshell-dock

A Quickshell dock that shows your Plasma favourites and lets you drag them into
whatever order you like.

![the dock](docs/dock.png)

## What it does

- Reads the **Favorites** list out of Plasma's Application Launcher (Kickoff) —
  from the KActivities database Plasma actually keeps it in, not the stale copy
  in `appletsrc` (see [Where favourites live](#where-favourites-live)).
- Resolves `preferred://browser`, `preferred://filemanager`, `preferred://mailer`
  and `preferred://terminal` the same way Plasma does, via `kdeglobals` and
  `mimeapps.list`.
- Skips favourites whose application isn't installed, instead of showing a
  broken icon.
- **Drag to reorder.** Neighbours slide aside as you drag; the order is saved and
  restored on next launch.
- **Auto-hide** that never disappears completely — the dock slides down to a
  thin sliver at the screen edge and comes back when the pointer touches it.
- Click to launch, hover for the application name.
- **Knows what's running**: running apps carry a corner badge with a dot per
  open window, clicking one raises its windows instead of starting a second
  copy, and a **+** button above the icon opens another window when you do want
  one (see [Running applications](#running-applications)).
- Picks up favourite changes live — favourite something in Kickoff and it
  appears without a restart.
- Resolves icons through a fallback chain, so absolute-path and
  oddly-named icons still render (see [Icons](#icons)).
- Drawn as a single stroked path, so it blends into the screen edge with
  inverted corners (see [The dock outline](#the-dock-outline)).

## Requirements

- Quickshell (developed against 0.3.1)
- A compositor supporting `wlr-layer-shell` (KWin on Plasma 6 does)
- Plasma's `org.kde.taskmanager` QML module, from `plasma-workspace`, for the
  running-application features
- One extra install step to let KWin tell the dock what's running — see
  [Running applications](#running-applications). Without it everything else
  still works; the dock just behaves as a plain launcher.

## Running

```sh
qs -p ./shell.qml
```

For the running-application features, also install the permission file once:

```sh
install -Dm644 org.quickshell.dock.desktop \
  ~/.local/share/applications/org.quickshell.dock.desktop
kbuildsycoca6
```

To autostart it with your session:

```sh
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/quickshell-dock.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Quickshell Dock
Exec=qs -p $PWD/shell.qml
EOF
```

(`X-KDE-Wayland-Interfaces` does nothing in an autostart file — KWin only reads
it from the installed-applications index. See
[The KWin permission](#the-kwin-permission).)

## Configuration

Everything tunable lives in [Config.qml](Config.qml) — sizes, colours, hover
magnification, and:

| Property | Meaning |
| --- | --- |
| `source` | `"kickoff"` for launcher favourites, `"taskmanager"` for the task manager's pinned launchers |
| `autoHide` | Slide away when unused, leaving `peekHeight` px showing |
| `peekHeight` | How much of the dock stays visible while hidden |
| `peekOpacity` | How solid that sliver is; the dock fades to this as it slides away |
| `triggerHeight` | Invisible pointer-catching strip along the screen edge |
| `hideDelay` | How long the pointer must be away before it hides |
| `edgeCorners` | Inverted corners flaring the dock into the screen edge |
| `border` / `borderWidth` | Hairline traced around the whole outline, fillets included |
| `cornerSize` | Radius of those corners |
| `peekFilletShare` | Height split between rounded corner and flare while peeking; lower = rounder |
| `backgroundColor` / `backgroundOpacity` | Dock background tint and translucency, kept separate from hex alpha |
| `reserveSpace` | `true` makes windows avoid the dock; `false` floats it on top |
| `hoverMagnify` | macOS-style icon zoom on hover |
| `raiseRunning` | Clicking a running app raises its windows instead of launching another copy |
| `runningIndicator` | Draw the corner badge on running apps |
| `indicatorMaxDots` | Cap on the dots, so a browser with ten windows can't run the badge across the icon |
| `indicatorInsetX` / `indicatorInsetY` | Badge distance from the icon's corner, per axis; negative overhangs |
| `indicatorPadding` | Padding between the dots and the edge of their backing |
| `indicatorColor` / `indicatorActiveColor` | Dot colour, and the accent used for the focused app |
| `indicatorBackground` | The badge's backing; `"transparent"` gives bare dots |
| `newInstanceButton` | Show the **+** button above a running app's icon |
| `newInstanceSize` / `newInstanceGap` | Button diameter, and its distance from the dock plate |

Quickshell hot-reloads on save, so edits apply immediately.

## Auto-hide

With `autoHide` on, the dock gives up its floating gap and sits flush against
the screen edge — it has to touch the edge to be reachable by the pointer.
Hidden, only `peekHeight` px of its top remain visible.

The window itself stays full height the whole time; only the plate slides. What
moves with it is the input region (`mask`), so while the dock is hidden
everything except that thin sliver clicks straight through to the window
underneath. The dock also fades to `peekOpacity` on the way out, driven off how
far the plate has actually travelled rather than off `revealed`, so the fade
rides the slide instead of needing an animation of its own to keep in step with.
The mask doesn't fade with it, so even `peekOpacity: 0` leaves the dock exactly
as easy to summon — just invisible until you do. `triggerHeight` widens that strip a little beyond the visible
sliver, so the dock isn't fiddly to summon. It also won't slide away mid-drag.

Two details make revealing under a **stationary** pointer behave, both of which
took real debugging:

- The hover target is the fixed-position `body` container, not the plate. Qt only
  re-evaluates hover when a pointer event arrives, so a target that slid with the
  plate would move out from under a motionless pointer and report nothing
  hovered.
- That handler has to be an *ancestor* of the icons rather than a sibling,
  because the icons' `MouseArea`s consume hover events. As a sibling it saw
  nothing whenever the pointer was over an icon, and the dock revealed and then
  immediately hid again.

`revealGrace` is belt-and-braces on top: a brief window after revealing in which
a momentary "nothing hovered" is ignored rather than starting the hide timer.

## Running applications

Three things hang off knowing what's open: the badge in an icon's top-left
corner (one dot per window, capped at `indicatorMaxDots`, accent-coloured while
that app has focus), click-to-raise, and the **+** button.

The badge sits **on** the icon rather than in a strip of its own, so switching
it on doesn't change the dock's size. That does mean it lands on artwork of any
colour, which is why it carries its own dark backing — pale dots vanish outright
on a white icon. `indicatorBackground: "transparent"` gives bare dots back if
your icons are uniform enough to take them.

**Clicking a running app raises it** rather than starting a second copy. When it
owns several windows each click steps to the next one, so repeated clicks cycle
the group instead of arguing over which single window counts as "the" window. A
minimized window is unminimized first — `requestActivate` on its own leaves it
minimized.

That leaves no way to *deliberately* open another window, which is what the **+**
button above the icon is for. It appears on hover over a running app and calls
`requestNewInstance`, which runs the launcher afresh.

### Why not `ToplevelManager`

Quickshell ships `ToplevelManager`, which speaks
`wlr-foreign-toplevel-management`. On a Plasma session it is permanently empty,
and not because of a permission: **KWin implements no foreign-toplevel protocol
at all** — neither the wlr one nor `ext-foreign-toplevel-list-v1`. Dumping the
Wayland registry on KWin 6.6 turns up neither.

What KWin does have is its own `org_kde_plasma_window_management`, which is what
Plasma's task manager runs on. So the dock reads Plasma's **libtaskmanager**
(`org.kde.taskmanager`) instead. That also hands us the genuinely hard part for
free: mapping a window back to the `.desktop` file it was launched from, which
is exactly the key the dock is indexed by. Doing that from raw toplevel app-ids
means reimplementing a pile of per-application special cases.

### The KWin permission

`org_kde_plasma_window_management` is a **restricted interface**. KWin resolves a
connecting client to its executable, finds that executable's `.desktop` file,
and only advertises the interface if the file lists it under
`X-KDE-Wayland-Interfaces`. Otherwise you get this in the log and an empty model:

```
org.kde.plasma.libtaskmanager: The PlasmaWindowManagement protocol hasn't
activated in time. The client possibly got denied by kwin? Check kwin output.
```

Quickshell's own `org.quickshell.desktop` carries no `Exec=` line, so KWin can't
match a process to it. Hence [org.quickshell.dock.desktop](org.quickshell.dock.desktop),
which names the binary and asks for the interface. It has to point at the
**quickshell executable**, not at `shell.qml` — KWin is identifying a process,
not a config. An autostart entry in `~/.config/autostart` won't do, either; KWin
looks the client up through the installed-applications index, which autostart
files aren't part of.

`qs` being a symlink to `quickshell` doesn't matter: the lookup resolves to the
real binary, so one file covers both.

When the grant is missing, `Tasks` simply reports that nothing is running. Every
app then looks not-running, so clicks launch, no dots are drawn and the **+**
button never appears — the dock as it was before.

### Reaching the button

The dock's input region (`mask`) normally covers only the visible part of the
plate, so everything above it clicks straight through. The **+** button lives up
there in the headroom, which means it has to add itself back into the mask while
it's shown.

Getting the pointer to it needs two more details:

- The button's item is **taller than the button it draws**, reaching down to the
  icon's top edge, so the trip up from the icon crosses no dead space.
- It still passes over the plate's padding, where neither the icon nor the button
  is hovered, so a short grace period keeps it up rather than letting it blink
  out from under the pointer on the way.

Hovering the button also counts as hovering the dock, or auto-hide would slide
the whole thing away the moment you left the icon.

## The dock outline

The whole dock is drawn as **one continuous path** — rounded top corners, sides,
and either the edge fillets or rounded bottom corners — built as SVG path data in
`Dock.silhouettePath` and rendered by a single `Shape`/`ShapePath`. Convex corners
sweep one way (SVG flag `1`), the concave fillets the other (`0`).

The **edge fillets** are inverted rounded corners — a square with a
quarter-circle bitten out — tucked against the screen edge either side of the
dock, so it looks like it grows out of the edge instead of ending in a hard
vertical line. Same trick GNOME Shell's "panel corners" use. `Rectangle.radius`
can't do it; that only rounds convex corners.

They're only drawn when the dock is genuinely flush with the edge, which is what
`autoHide` does — a floating dock has nothing to blend into, so it gets rounded
bottom corners instead. Either way the outline stays welded to the screen edge
while the dock peeks and expands, so the fillets don't slide off with the plate.

### Why one path

It started as a `Rectangle` plus two separate corner items. That works for fill,
but it can't be outlined: `Rectangle.border` applies to all four edges at once,
so the hairline ran down the plate's sides and straight across the join with the
fillets — precisely the seam the fillets exist to hide. The border had to be
switched off, which meant `Config.border` did nothing on the panel.

A single path strokes cleanly all the way round, fillets included, so
`border`/`borderWidth` work at every slide position. It also sidesteps
double-blending, which would otherwise show as a darker seam anywhere two
translucent shapes overlapped.

### Sharing the height

A continuous outline can't have the corner arc and the fillet arc overlap
vertically — the path would double back on itself. What peeks above the edge is
the plate's *top* edge, so on a thin sliver they're competing for the same few
pixels.

The **radius gets first claim** on the visible height, and the fillet takes
whatever is left, further capped by `peekFilletShare`. A very thin sliver is
therefore a pure rounded cap with no flare, and the flare grows in as the dock
expands past the radius. Prioritising the radius is deliberate: the alternative
leaves a thin sliver looking like a flat-ended box.

If you want a pronounced flare *while peeking* as well, the lever is a taller
`peekHeight` — there's simply no room for both in 8px.

All of it is driven off how much of the plate is showing, so it animates for free
along with `plate.y`.

Tune with `edgeCorners`, `cornerSize`, `peekFilletShare`, `radius`, `border` and
`borderWidth`.

## Icons

A single icon-theme lookup isn't enough in practice, so each entry gets a list
of candidates tried in order, falling through on load failure:

- `Icon=` is often an **absolute path** — DBeaver ships
  `Icon=/usr/share/dbeaver-ce/dbeaver.png` — which isn't a theme name at all and
  has to be loaded as a `file://` URL.
- Icon themes are inconsistent about naming. With `QT_QPA_PLATFORMTHEME=gtk3`,
  Qt resolves icons against the **GTK** icon theme, not Plasma's. Ant-Dark, for
  instance, ships `dbeaver.svg` but no `dbeaver-ce.svg`, and carries both
  `tilix.svg` and `com.gexperts.Tilix.svg`.

So `com.gexperts.Tilix` also tries `tilix`, `dbeaver-ce` also tries `dbeaver`,
and `code`/`vscode` also tries `visual-studio-code`, before finally falling back
to a generic executable icon.

Note that a correctly-resolved icon can still be hard to see: Tilix's own icon
is mid-grey, which reads as washed out against a dark dock. That's the
application's artwork, not a lookup failure.

## Where favourites live

This one is a trap. Kickoff has two places it can keep favourites, and the
obvious one is usually wrong.

Since Plasma 5.16 Kickoff stores favourites as **linked resources in the
KActivities statistics database**:

```
~/.local/share/kactivitymanagerd/resources/database
```

When it migrated it set `favoritesPortedToKAstats=true` in its applet config —
and left the old plain-text `favorites=` key behind, never updating it again. So
reading `appletsrc` gives you a snapshot from whenever the migration happened.
On the machine this was written against, the two disagreed completely: the stale
key still listed Discover, LibreOffice and Konsole, while the live favourites
were Tilix, DBeaver, a Chrome web app and Spotify.

So `PlasmaFavorites` reads the database whenever the applet reports the
migration, and only falls back to the `favorites=` key otherwise. The task
manager never migrated, so `source: "taskmanager"` always reads `appletsrc`.

Two practical notes:

- There's **no D-Bus method to enumerate** linked resources — the
  `ResourcesLinking` interface only offers `Is`/`Link`/`Unlink` — so the database
  really is the only source. It's read strictly read-only, via `sqlite3` or
  `python3`'s bundled engine, whichever is present. `kactivitymanagerd` holds it
  open in WAL mode, which permits concurrent readers.
- Favouriting something *does* emit D-Bus signals, so the dock subscribes to
  `ResourceLinkedToActivity`/`ResourceUnlinkedFromActivity` via `gdbus monitor`
  and re-queries, rather than polling.

`ResourceLink` has no ordering column, so favourites come back in link order
(`rowid`) — which is what Kickoff shows. Your own drag order takes over from
there anyway.

## How ordering works

Plasma owns *which* apps are favourites; this dock owns *the order*.

Dragging writes only to the dock's own state file
(`~/.local/state/quickshell/by-shell/<id>/dock-order.json`) and never touches
Plasma's config — plasmashell keeps that file in memory and would overwrite an
external edit anyway. Plasma's Favorites menu therefore keeps its own order.

On startup the two are merged: remembered positions first, then anything newly
favourited appended to the end. Un-favouriting an app drops it from the dock,
and its remembered position is discarded.

## Layout

| File | Role |
| --- | --- |
| [shell.qml](shell.qml) | Entry point; one dock per screen |
| [Dock.qml](Dock.qml) | The panel: layer-shell window, list, drag-reorder wiring, auto-hide, tooltip |
| [DockIcon.qml](DockIcon.qml) | One cell's visuals — highlight, icon, hover zoom, running dots |
| [Tasks.qml](Tasks.qml) | What's running, via Plasma's libtaskmanager; raise and new-instance |
| [org.quickshell.dock.desktop](org.quickshell.dock.desktop) | Asks KWin for the restricted window-management interface |
| [IconResolver.qml](IconResolver.qml) | Builds the icon fallback chain |
| [PlasmaFavorites.qml](PlasmaFavorites.qml) | Picks the favourites source and resolves entries |
| [KAstatsFavorites.qml](KAstatsFavorites.qml) | Reads favourites from the KActivities database |
| [DockOrder.qml](DockOrder.qml) | Persists and merges the drag order |
| [Ini.qml](Ini.qml) | Small KConfig/INI reader |
| [Config.qml](Config.qml) | All the knobs |

## Notes

- `DesktopEntries` populates asynchronously and is empty on the frame you first
  touch it, so the favourite list is a reactive binding rather than a one-shot
  read.
- Applet ids in `appletsrc` are per-machine, so the Kickoff applet is found by
  scanning for the right `plugin=` with a non-empty list rather than a fixed id.
- `TasksModel` emits `dataChanged` for things the dock doesn't care about —
  window titles, most of all — so rebuilds are coalesced to once per event loop
  turn and skipped entirely when the result is identical. Otherwise typing in an
  editor re-evaluates every icon's bindings.
- Window-to-launcher matching is normalised on both sides (strip
  `applications:`, strip any path, drop `.desktop`, lowercase). The lowercasing
  earns its keep on Chrome web apps, which Plasma lists as
  `chrome-…-Default.desktop` but reports running as `chrome-…-default`.
