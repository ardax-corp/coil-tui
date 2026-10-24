// Components, the nodes the framework works with, and the context
// handlers get.
use cli::keys::{Event, MouseEvent};
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::empty;
use tui::geom::rect;
use tui::layout::Constraint;
use tui::theme::Theme;
use tui::theme::default_theme;

/// What a component is: how it draws, sizes itself, handles input and
/// holds children. Only `render` is required.
///
/// Components are ordinary objects that keep their own state; `mount`
/// turns one into a `Node` for the tree.
trait Component<T> {
    /// Draw into `c`, whose (0, 0) is this component's top-left corner.
    fn render(T c, Canvas cv, Ctx ctx) {}

    /// Preferred size within `max` (used by `Auto` constraints and by
    /// containers that size to content).
    fn measure(T c, Size max) -> Size {
        return max;
    }

    /// Handle an event; true when it was consumed. Unconsumed events
    /// bubble to the parent.
    fn handle(T c, Event e, Ctx ctx) -> bool {
        return false;
    }

    fn focusable(T c) -> bool {
        return false;
    }

    /// Child nodes, in paint and focus order.
    fn children(T c) -> Vec<Node> {
        return Vec::new();
    }

    /// Rects for `children()` inside `area` (local coordinates). The
    /// default gives every child the whole area.
    fn arrange(T c, Rect area) -> Vec<Rect> {
        let out: Vec<Rect> = Vec::new();
        for k in c.children() {
            out.push(area);
        }
        return out;
    }

    /// How a row or column sizes this component unless the node says
    /// otherwise.
    fn constraint(T c) -> Constraint {
        return Constraint::Fill(1);
    }
}

/// A component in the tree. Holds the component behind closures (so
/// nodes of every component type share one class) plus per-node layout
/// state.
class Node {
    //
    // Closures rather than a trait-typed field: a class holding trait-typed
    // values cannot itself be used as one yet (coil-lang issue 1988).

    /// Name for `App.find` and tests ("" = none).
    pub id: string,
    pub constraint: Constraint,
    /// Absolute area from the last draw.
    pub rect: Rect,
    /// The visible part of `rect` (clipped by ancestors).
    pub clip: Rect,
    pub visible: bool,
    pub disabled: bool,
    /// The component's children (the vector it returned from
    /// `children()` at mount; a container that adds to its own vector
    /// later is seen here too).
    pub kids: Vec<Node>,
    render_f: fn(Canvas) -> (),
    measure_f: fn(Size) -> Size,
    handle_f: fn(Event) -> bool,
    focusable_f: fn() -> bool,
    arrange_f: fn(Rect) -> Vec<Rect>,
}

/// Wrap a component in a node.
fn mount<T: Component>(T c) -> Node {
    return new Node(
        "",
        c.constraint(),
        empty(),
        empty(),
        true,
        false,
        c.children(),
        fn (Canvas cv) use (c) {
            c.render(cv, current());
        },
        fn (Size m) use (c) => c.measure(m),
        fn (Event e) use (c) => c.handle(e, current()),
        fn () use (c) => c.focusable(),
        fn (Rect r) use (c) => c.arrange(r),
    );
}

impl Node {
    pub fn render(Canvas cv) {
        let f = self.render_f;
        f(cv);
    }

    pub fn measure(Size max) -> Size {
        let f = self.measure_f;
        return f(max);
    }

    pub fn handle(Event e) -> bool {
        let f = self.handle_f;
        return f(e);
    }

    /// Focusable now: visible, enabled and the component accepts focus.
    pub fn can_focus() -> bool {
        let f = self.focusable_f;
        return self.visible && !self.disabled && f();
    }

    pub fn children() -> Vec<Node> {
        return self.kids;
    }

    pub fn arrange(Rect area) -> Vec<Rect> {
        let f = self.arrange_f;
        return f(area);
    }

    /// Set the id (builder style).
    pub fn named(string id) -> Node {
        self.id = id;
        return self;
    }

    pub fn sized(Constraint c) -> Node {
        self.constraint = c;
        return self;
    }

    pub fn fixed(int n) -> Node {
        return self.sized(Constraint::Fixed(n));
    }

    pub fn percent(int p) -> Node {
        return self.sized(Constraint::Percent(p));
    }

    pub fn fill(int weight) -> Node {
        return self.sized(Constraint::Fill(weight));
    }

    pub fn auto() -> Node {
        return self.sized(Constraint::Auto);
    }

    pub fn min(int n) -> Node {
        return self.sized(Constraint::Min(n));
    }

    pub fn max(int n) -> Node {
        return self.sized(Constraint::Max(n));
    }

    pub fn hidden(bool h) -> Node {
        self.visible = !h;
        return self;
    }

    pub fn enabled(bool on) -> Node {
        self.disabled = !on;
        return self;
    }
}

/// A scheduled callback.
class Timer {
    pub id: int,
    pub due: int,
    /// Repeat interval in ms (0 = once).
    pub every: int,
    pub f: fn(Ctx) -> (),
    pub cancelled: bool,
}

/// What handlers, callbacks and `render` get: the theme, the clock, who
/// has focus, and requests to the app (quit, focus, layers, timers),
/// which the app carries out after the handler returns.
class Ctx {
    pub theme: Theme,
    /// Milliseconds, from the app's clock.
    pub now: int,
    /// The node being rendered or handling an event.
    pub current: Option<Node>,
    pub focused: Option<Node>,
    pub quit_requested: bool,
    pub redraw_requested: bool,
    pub focus_request: Option<Node>,
    /// +1 next, -1 previous, 0 none.
    pub focus_step: int,
    pub pushes: Vec<Node>,
    pub pops: int,
    pub timers: Vec<Timer>,
    next_timer: int,
}

fn ctx() -> Ctx {
    return new Ctx(
        default_theme(),
        0,
        Option::None,
        Option::None,
        false,
        false,
        Option::None,
        0,
        Vec::new(),
        0,
        Vec::new(),
        1,
    );
}

// The context of the app that is running a handler or drawing. The app
// installs its own before every dispatch, tick and draw.
static let installed: Vec<Ctx> = Vec::new();

/// The current context (a fresh one when no app has installed one).
fn current() -> Ctx {
    if installed.len() == 0 {
        installed.push(ctx());
    }
    return installed[0];
}

/// Make `c` the context handlers and `render` get.
fn set_current(Ctx c) {
    if installed.len() == 0 {
        installed.push(c);
    } else {
        installed[0] = c;
    }
}

fn same_node(Option<Node> a, Node b) -> bool {
    return match a {
        Option::Some(n) => n == b,
        Option::None => false,
    };
}

impl Ctx {
    /// Stop the app after this event.
    pub fn quit() {
        self.quit_requested = true;
    }

    /// Redraw even though nothing was handled.
    pub fn redraw() {
        self.redraw_requested = true;
    }

    /// Whether the node being rendered or handling an event has focus.
    pub fn has_focus() -> bool {
        return match self.current {
            Option::Some(n) => same_node(self.focused, n),
            Option::None => false,
        };
    }

    pub fn is_focused(Node n) -> bool {
        return same_node(self.focused, n);
    }

    /// Move focus to `n` (when it can take focus).
    pub fn focus(Node n) {
        self.focus_request = Option::Some(n);
    }

    pub fn focus_next() {
        self.focus_step = 1;
    }

    pub fn focus_prev() {
        self.focus_step = -1;
    }

    /// Open `n` as a layer on top (a dialog or popup). It takes the
    /// keyboard until it is popped.
    pub fn push_layer(Node n) {
        self.pushes.push(n);
    }

    /// Close the top layer and give focus back to where it was.
    pub fn pop_layer() {
        self.pops++;
    }

    fn add_timer(int ms, int every, fn(Ctx) -> () f) -> int {
        let id = self.next_timer;
        self.next_timer++;
        self.timers.push(new Timer(id, self.now + ms, every, f, false));
        return id;
    }

    /// Run `f` once after `ms` milliseconds. Returns an id for `cancel`.
    pub fn after(int ms, fn(Ctx) -> () f) -> int {
        return self.add_timer(ms, 0, f);
    }

    /// Run `f` every `ms` milliseconds (at least 1).
    pub fn every(int ms, fn(Ctx) -> () f) -> int {
        let step = ms;
        if step < 1 {
            step = 1;
        }
        return self.add_timer(step, step, f);
    }

    pub fn cancel(int id) {
        for t in self.timers {
            if t.id == id {
                t.cancelled = true;
            }
        }
    }

    /// The earliest timer deadline, if any (for the runner's read
    /// timeout).
    pub fn next_due() -> Option<int> {
        let best = -1;
        for t in self.timers {
            if !t.cancelled && (best < 0 || t.due < best) {
                best = t.due;
            }
        }
        if best < 0 {
            return Option::None;
        }
        return Option::Some(best);
    }

    /// Mouse position relative to the current node's corner.
    pub fn local(MouseEvent m) -> (int, int) {
        let x = m.col - 1;
        let y = m.row - 1;
        return match self.current {
            Option::Some(n) => (x - n.rect.x, y - n.rect.y),
            Option::None => (x, y),
        };
    }
}
