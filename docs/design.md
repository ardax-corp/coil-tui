# coil-tui design

coil-tui is a component framework for terminal user interfaces in Coil:
build an application out of reusable components, lay them out in rows and
columns, and let the framework handle drawing, focus and input. Package
name: `tui`. It is pure Coil and sits on top of the `cli` package
(coil-cli), which provides the terminal, decoded input events and a cell
buffer that renders by diffing frames.

## Goals

- Components that own their state and compose: a form is a column of
  inputs and buttons, a dialog is a block around a form.
- A layout engine that sizes children from simple constraints
  (fixed, percent, fill, min/max, content size).
- Focus and keyboard navigation for free: Tab/Shift-Tab, mouse clicks,
  modal layers that trap focus.
- Fast enough redraws without per-widget dirty tracking: every redraw
  paints a fresh frame and `cli::screen` writes only the changed cells.
- Everything testable without a terminal: an `App` takes events and
  returns escape strings, and a test harness types keys and reads the
  screen as text.

Non-goals for the first version: CSS-like styling, animation, a text
editor widget with syntax highlighting, inline (non full-screen) mode.
The last one is a likely follow-up.

## What coil-cli provides

| `cli` module | Used for |
|---|---|
| `cli::screen` | `Buffer` (cells of text + style), `Screen` (double buffer, `present()` diff) |
| `cli::keys` | `Event` (key, mouse, paste, focus, resize), `Key`, modifier bits, `is_key(e, "ctrl+c")` |
| `cli::style`, `cli::color` | `Style`, `Color`, colour level detection |
| `cli::width` | display width, truncate, pad, wrap |
| `cli::line` | line editor model (used by `TextInput`) |
| `cli::term`, `cli::events` | raw mode, size, timed event reads (the runner only; not merged yet) |
| `cli::ansi` | alt screen, cursor show/hide/move, mouse and paste modes |

Only the runner (`tui::run`) needs `cli::term`/`cli::events`. Everything
else works on buffers and events and is built and tested first.

## Component model

Components are retained objects: a `TextInput` is created once, keeps its
text and cursor between frames, and is updated by events. That fits Coil,
where objects are shared references, and keeps widget state where the
widget is instead of threading it through the application.

The alternative, an Elm-style `update(model, msg)` / `view(model)` that
rebuilds a description of the screen every frame, is simple for small
apps, but every stateful widget (scroll offsets, cursors, selections)
then has to keep its state in the application model and be reconciled
by key. It can be added later as a component (`View` that rebuilds its
children from a model) without changing the core.

### `Component` and `Node`

Authors implement the `Component` trait; the framework works with
`Node`, a concrete type-erased handle:

```coil
trait Component<T> {
    /// Draw into `c`, whose (0, 0) is this component's top-left corner.
    fn render(T self_, Canvas c, Ctx ctx);

    /// Preferred size within `max` (for `Auto` constraints).
    fn measure(T self_, Size max) -> Size { return max; }

    /// Handle an event; return true when it was consumed.
    fn handle(T self_, Event e, Ctx ctx) -> bool { return false; }

    fn focusable(T self_) -> bool { return false; }

    /// Child nodes, in focus and paint order.
    fn children(T self_) -> Vec<Node> { return Vec::new(); }

    /// Rects for the children inside `area` (local coordinates).
    /// The default stacks every child over the whole area.
    fn arrange(T self_, Rect area) -> Vec<Rect> { ... }
}

fn mount<T: Component>(T c) -> Node
```

`mount` wraps the component in closures (`fn(Canvas, Ctx)`, ...), so a
`Node` is one concrete class whatever the component type. Containers hold
`Vec<Node>`. This is a workaround for coil-lang issue 1988: a class that holds
trait-typed values cannot itself be used as a trait-typed value yet, so
`Vec<Component>` children do not compile. With `mount` the author-facing
API is the trait either way; if that issue is fixed, `Node` can become a
thin wrapper without changing components.

A `Node` also carries what the framework needs per instance:

- `constraint`: how a parent row/column sizes it (see Layout),
- `rect`: absolute area from the last layout pass,
- `visible`, `disabled`,
- an optional `id` string for lookups (`app.find("name")`) and tests.

Builder methods set these: `mount(btn).fixed(10).id("ok")`.

### State and callbacks

Widgets expose callbacks as function fields: `Button.on_press: fn(Ctx)`,
`TextInput.on_submit: fn(string, Ctx)`, `List.on_select: fn(int, Ctx)`.
Application state lives in the application's own objects, captured by the
callbacks (`use (model)`); `cell::Ref` covers plain values. A callback
changes state and the framework redraws after every handled event, so
there is no explicit "set state" step.

## Layout

A `Rect` is `x, y, w, h` in cells. Layout runs top-down before each
redraw: the root gets the screen, each node's `arrange` gives its
children their rects, recursively.

`Row` and `Column` divide their main axis by each child's `Constraint`:

| Constraint | Size on the main axis |
|---|---|
| `Fixed(n)` | `n` cells |
| `Percent(p)` | `p`% of the container |
| `Auto` | the child's `measure` |
| `Fill(weight)` | a share of what is left, by weight (default `Fill(1)`) |
| `Min(n)`, `Max(n)` | `Fill(1)` clamped |

Fixed, percent and auto sizes are taken first (shrunk proportionally when
they do not fit), then the rest is split among fills by weight, with
rounding remainders going to the first fills so the sizes always add up
to the available space. Rows and columns also take a `gap` and an
`align` for the cross axis (stretch by default). The solver is a pure
function (`tui::layout::split`) with its own tests.

Other layout components: `Stack` (children on top of each other),
`Block` (border, title, padding around one child), `Pad`, `Center`,
`Spacer`, and `Scroll` (renders a taller child through an offset).

## Rendering

`Canvas` is a view onto the frame's `cli::screen::Buffer`: an origin and
a clip rect. Components draw in local coordinates with `put`, `fill`,
`hline`, `draw_box`; anything outside the clip is dropped, so a
component cannot paint over its siblings. `sub(rect)` gives a child its
own canvas.

A redraw is: layout, then paint the tree depth-first into
`screen.frame()`, then `screen.present()`, which emits only the cells
that changed since the last frame. There is no per-widget dirty
tracking; the app redraws after any handled event, timer or resize, and
skips the redraw when nothing happened. A full 200 x 60 repaint is 12 000
cells, which is cheap next to the terminal write that the diff avoids.

The focused component may ask for the hardware cursor
(`c.cursor(x, y)`, used by text inputs); after `present()` the app shows
it there, or hides it.

Layers: the app has a stack of root nodes. The base layer is the
application; `ctx.push_layer(node)` opens a dialog or popup drawn on top
(`Dialog`, `Menu`). Only the top layer gets keyboard input and focus.

## Events and focus

Input comes in as `cli::keys::Event`.

- Key and paste events go to the focused node, then bubble to its
  ancestors until one returns `true`. Unhandled keys reach the app's key
  bindings (`app.bind("ctrl+q", fn(Ctx))`), and then the defaults: Tab /
  Shift-Tab move focus, Ctrl-C quits.
- Mouse events go to the deepest node under the pointer in the top
  layer, and bubble the same way. A press on a focusable node focuses it
  first.
- Resize resizes the screen and relayouts.
- Focus order is the depth-first order of visible, enabled, focusable
  nodes in the top layer. `ctx.focus(node)` and `app.focus_id("name")`
  move it directly.

`Ctx` is what handlers and callbacks get: `quit()`, `redraw()`,
`focus(node)`, `focused()`, `push_layer`/`pop_layer`, `after(ms, f)` and
`every(ms, f)` timers, and the theme. The runner uses the next timer
deadline as its read timeout, so spinners and clocks tick without busy
waiting.

## Theme

A `Theme` holds named styles (`text`, `muted`, `accent`, `border`,
`border_focused`, `selection`, `selection_unfocused`, `error`,
`button`, `button_focused`, `input`, `title`). Widgets read their styles
from `ctx.theme()` unless given their own. The default theme uses only
the 16 basic colours plus bold/reverse, so it looks right in any
terminal; `cli::style` downgrades RGB themes for 256- and 16-colour
terminals.

## App and runner

`App` is the whole framework minus the terminal:

```coil
let app = tui::app(root_node);
app.resize(80, 24);
app.dispatch(event);      // routes, runs handlers, marks for redraw
app.tick(now_ms);         // fires due timers
let out = app.draw();     // "" when nothing changed
```

`tui::run(app)` is the terminal loop: alternate screen, raw mode, hidden
cursor, mouse and bracketed paste on; read events with a timeout from
`cli::events`; dispatch; tick; write `draw()`; restore everything on
exit (also on panic, via `defer` and the runtime's raw-mode restore).

`tui::testing` drives an `App` headlessly:

```coil
let h = harness(app, 40, 10);
h.keys("tab tab enter");
h.type("hello");
h.click(3, 4);
assert!(h.row(2) == "│ hello              │");
```

## Widgets

First set, in the order they are planned:

| Group | Widgets |
|---|---|
| Layout | `Row`, `Column`, `Stack`, `Block`, `Pad`, `Center`, `Spacer`, `Scroll` |
| Display | `Text` (styled spans, wrap, alignment), `Rule`, `Gauge`, `Spinner`, `KeyHints` |
| Input | `Button`, `Checkbox`, `RadioGroup`, `TextInput`, `List` (select, scroll), `Table`, `Tabs` |
| Layers | `Dialog` (alert / confirm), `Menu` |

Each widget is a class implementing `Component`, plus a constructor
function that returns the class (so callers can keep a typed reference)
and the usual `mount`.

## Package and modules

| Module | Contents |
|---|---|
| `tui::geom` | `Rect`, `Size`, `Align` |
| `tui::canvas` | `Canvas` (clipped, offset drawing onto a `Buffer`) |
| `tui::layout` | `Constraint`, `split`, row/column arrangement |
| `tui::node` | `Component`, `Node`, `mount` |
| `tui::theme` | `Theme`, `default_theme` |
| `tui::app` | `App`, `Ctx`, focus, layers, timers, key bindings |
| `tui::testing` | headless harness |
| `tui::run` | terminal runner (needs `cli::term`) |
| `tui::widgets::*` | one module per widget family |

Dependencies: `cli` (coil-cli) and coil-stdlib. Like coil-cli, coil-tui
ships no native code and needs no `--allow-dload`.

## Plan

Each step is one PR into `main`, merged when CI is green.

1. Scaffolding, CI, this doc.
2. `geom`, `canvas`, `layout` (constraint solver).
3. `node`, `theme`, `app` (layout and paint pass, dispatch, focus,
   layers, timers) and `testing`.
4. Layout and display widgets: `Row`, `Column`, `Stack`, `Block`, `Pad`,
   `Center`, `Spacer`, `Text`, `Rule`.
5. `Button`, `Checkbox`, `RadioGroup`, `TextInput`.
6. `List`, `Scroll`, `Table`, `Tabs`.
7. `Gauge`, `Spinner`, `KeyHints`, `Dialog`, `Menu`.
8. `tui::run` and examples (todo list, file picker, dashboard), once
   `cli::term` and `cli::events` are merged in coil-cli.

Compiler or stdlib bugs found along the way are filed in coil-lang /
coil-stdlib with a repro and worked around in the smallest way, with a
comment pointing at the issue.
