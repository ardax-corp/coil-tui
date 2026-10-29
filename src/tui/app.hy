// The application: a stack of layers, focus, event routing, timers, and
// drawing through `cli::screen`. No terminal access; `tui::run` drives an
// `App` from a real terminal and `tui::testing` from tests.
use string::format;
use cli::keys::Event;
use cli::keys::Key;
use cli::keys::MouseEvent;
use cli::keys::MouseKind;
use cli::keys::MouseButton;
use cli::keys::is_key;
use cli::screen::Screen;
use cli::screen::Buffer;
use cli::screen::screen;
use cli::screen::buffer;
use cli::color::ColorLevel;
use tui::canvas::Canvas;
use tui::canvas::Frame;
use tui::canvas::frame;
use tui::canvas::canvas;
use tui::geom::Rect;
use tui::geom::rect;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::Timer;
use tui::node::ctx;
use tui::node::set_current;
use tui::theme::Theme;

/// A key binding handled when no component consumed the key.
class Binding {
    pub spec: string,
    pub f: fn(Ctx) -> (),
}

shared class App {
    /// Base layer first; only the top one gets input and focus.
    layers: Vec<Node>,
    /// Focus to give back when the layer above is popped.
    saved: Vec<Option<Node>>,
    pub ctx: Ctx,
    screen: Screen,
    bindings: Vec<Binding>,
    dirty: bool,
    pub running: bool,
    /// The buffer of the last drawn frame.
    pub last: Buffer,
    /// Whether the last frame showed the cursor, and where.
    cursor_on: bool,
    cursor_x: int,
    cursor_y: int,
}

/// An app with `root` as its base layer, drawing with colour `level`.
/// Call `resize` before the first `draw`.
fn app(Node root, ColorLevel level) -> App {
    let layers: Vec<Node> = Vec::new();
    layers.push(root);
    let a = new App(
        layers,
        Vec::new(),
        ctx(),
        screen(0, 0, level),
        Vec::new(),
        true,
        true,
        buffer(0, 0),
        false,
        -1,
        -1,
    );
    return a;
}

/// Focusable nodes under `n`, depth first. Hidden nodes and disabled
/// nodes hide their whole subtree.
fn collect_focus(Node n, Vec<Node> out) {
    if !n.visible || n.disabled {
        return;
    }
    if n.can_focus() {
        out.push(n);
    }
    for k in n.children() {
        collect_focus(k, out);
    }
}

/// The path from `n` down to `target` (both included), into `out`.
fn find_path(Node n, Node target, Vec<Node> out) -> bool {
    out.push(n);
    if n == target {
        return true;
    }
    for k in n.children() {
        if find_path(k, target, out) {
            return true;
        }
    }
    out.pop();
    return false;
}

/// The path to the deepest visible node whose visible area holds
/// (`x`, `y`). Later children are on top, so they are tried first.
fn hit_path(Node n, int x, int y, Vec<Node> out) -> bool {
    if !n.visible || !n.clip.contains(x, y) {
        return false;
    }
    out.push(n);
    let kids = n.children();
    let i = kids.len() - 1;
    while i >= 0 {
        if hit_path(kids[i], x, y, out) {
            return true;
        }
        i--;
    }
    return true;
}

fn find_id(Node n, string id) -> Option<Node> {
    if n.id == id {
        return Option::Some(n);
    }
    for k in n.children() {
        let r = find_id(k, id);
        if r != Option::None {
            return r;
        }
    }
    return Option::None;
}

/// Lay out and paint `n` into `cv` (its own area), then its children.
fn paint(Node n, Canvas cv) {
    n.rect = cv.area;
    n.clip = cv.clip;
    let c = tui::node::current();
    c.current = Option::Some(n);
    n.render(cv);
    let kids = n.children();
    if kids.len() == 0 {
        return;
    }
    let rects = n.arrange(cv.bounds());
    let i = 0;
    while i < kids.len() {
        let k = kids[i];
        if k.visible && i < rects.len() {
            paint(k, cv.sub(rects[i]));
        } else {
            k.rect = rect(cv.area.x, cv.area.y, 0, 0);
            k.clip = k.rect;
        }
        i++;
    }
}

impl App {
    pub fn top() -> Node {
        return self.layers[self.layers.len() - 1];
    }

    pub fn layer_count() -> int {
        return self.layers.len();
    }

    pub fn set_theme(Theme t) {
        self.ctx.theme = t;
        self.dirty = true;
    }

    /// Run `f` when the key `spec` (`"ctrl+q"`, `"f1"`, as
    /// `cli::keys::describe_key` writes it) reaches the app unhandled.
    pub fn bind(string spec, fn(Ctx) -> () f) {
        self.bindings.push(new Binding(spec, f));
    }

    pub fn resize(int cols, int rows) {
        self.screen.resize(cols, rows);
        self.cursor_on = false;
        self.cursor_x = -1;
        self.dirty = true;
    }

    /// Redraw everything on the next `draw` (after the terminal was
    /// cleared by someone else).
    pub fn invalidate() {
        self.screen.invalidate();
        self.cursor_x = -1;
        self.dirty = true;
    }

    pub fn cols() -> int {
        return self.screen.cols();
    }

    pub fn rows() -> int {
        return self.screen.rows();
    }

    /// The first node with this id, in any layer (top first).
    pub fn find(string id) -> Option<Node> {
        let i = self.layers.len() - 1;
        while i >= 0 {
            let r = find_id(self.layers[i], id);
            if r != Option::None {
                return r;
            }
            i--;
        }
        return Option::None;
    }

    pub fn focused() -> Option<Node> {
        return self.ctx.focused;
    }

    /// Id of the focused node ("" when none or unnamed).
    pub fn focused_id() -> string {
        return match self.ctx.focused {
            Option::Some(n) => n.id,
            Option::None => "",
        };
    }

    /// Focusable nodes of the top layer, in Tab order.
    pub fn focus_chain() -> Vec<Node> {
        let out: Vec<Node> = Vec::new();
        collect_focus(self.top(), out);
        return out;
    }

    /// Focus `n` if it is in the top layer's focus chain.
    pub fn focus(Node n) -> bool {
        for f in self.focus_chain() {
            if f == n {
                self.ctx.focused = Option::Some(n);
                self.dirty = true;
                return true;
            }
        }
        return false;
    }

    pub fn focus_id(string id) -> bool {
        return match self.find(id) {
            Option::Some(n) => self.focus(n),
            Option::None => false,
        };
    }

    /// Move focus `step` places along the chain (wrapping).
    pub fn focus_step(int step) {
        let chain = self.focus_chain();
        if chain.len() == 0 {
            self.ctx.focused = Option::None;
            return;
        }
        let at = -1;
        let i = 0;
        while i < chain.len() {
            if self.ctx.is_focused(chain[i]) {
                at = i;
            }
            i++;
        }
        let next = 0;
        if at < 0 {
            if step < 0 {
                next = chain.len() - 1;
            }
        } else {
            next = (at + step + chain.len()) % chain.len();
        }
        self.ctx.focused = Option::Some(chain[next]);
        self.dirty = true;
    }

    /// Keep focus on something focusable in the top layer: when the
    /// focused node left the chain (hidden, disabled, removed), focus
    /// the first one.
    fn settle_focus() {
        let chain = self.focus_chain();
        for f in chain {
            if self.ctx.is_focused(f) {
                return;
            }
        }
        if chain.len() == 0 {
            self.ctx.focused = Option::None;
        } else {
            self.ctx.focused = Option::Some(chain[0]);
        }
    }

    pub fn push_layer(Node n) {
        self.saved.push(self.ctx.focused);
        self.layers.push(n);
        self.ctx.focused = Option::None;
        self.settle_focus();
        self.dirty = true;
    }

    /// Close the top layer (never the base one).
    pub fn pop_layer() {
        if self.layers.len() <= 1 {
            return;
        }
        self.layers.pop();
        self.ctx.focused = self.saved.pop() ?? Option::None;
        self.settle_focus();
        self.dirty = true;
    }

    /// Carry out what handlers asked of the context.
    fn apply_requests() {
        let c = self.ctx;
        while c.pops > 0 {
            c.pops--;
            self.pop_layer();
        }
        let pushes = c.pushes;
        c.pushes = Vec::new();
        for n in pushes {
            self.push_layer(n);
        }
        match c.focus_request {
            Option::Some(n) => {
                self.focus(n);
            },
            Option::None => {},
        }
        c.focus_request = Option::None;
        if c.focus_step != 0 {
            self.focus_step(c.focus_step);
            c.focus_step = 0;
        }
        if c.quit_requested {
            self.running = false;
        }
        if c.redraw_requested {
            self.dirty = true;
            c.redraw_requested = false;
        }
        c.current = Option::None;
    }

    /// Offer `e` to the nodes of `path` from the deepest up.
    fn bubble(Vec<Node> path, Event e) -> bool {
        let i = path.len() - 1;
        while i >= 0 {
            let n = path[i];
            if !n.disabled {
                self.ctx.current = Option::Some(n);
                if n.handle(e) {
                    return true;
                }
            }
            i--;
        }
        return false;
    }

    fn focus_path() -> Vec<Node> {
        let path: Vec<Node> = Vec::new();
        match self.ctx.focused {
            Option::Some(f) => {
                if !find_path(self.top(), f, path) {
                    path = Vec::new();
                    path.push(self.top());
                }
            },
            Option::None => {
                path.push(self.top());
            },
        }
        return path;
    }

    fn keys_fallback(Event e) -> bool {
        for b in self.bindings {
            if is_key(e, b.spec) {
                let f = b.f;
                self.ctx.current = Option::None;
                f(self.ctx);
                return true;
            }
        }
        if is_key(e, "tab") {
            self.focus_step(1);
            return true;
        }
        if is_key(e, "backtab") || is_key(e, "shift+tab") || is_key(e, "shift+backtab") {
            self.focus_step(-1);
            return true;
        }
        if is_key(e, "ctrl+c") {
            self.running = false;
            return true;
        }
        return false;
    }

    /// Mouse events go to the deepest node under the pointer and bubble
    /// up; a left press first focuses the deepest focusable node there.
    fn route_mouse(MouseEvent m, Event e) -> bool {
        let path: Vec<Node> = Vec::new();
        hit_path(self.top(), m.col - 1, m.row - 1, path);
        let press = match m.kind {
            MouseKind::Press => true,
            default => false,
        };
        let left = match m.button {
            MouseButton::Left => true,
            default => false,
        };
        if press && left {
            let i = path.len() - 1;
            while i >= 0 {
                if path[i].can_focus() {
                    self.focus(path[i]);
                    break;
                }
                i--;
            }
        }
        return self.bubble(path, e);
    }

    /// Route one event. Returns whether anything handled it.
    pub fn dispatch(Event e) -> bool {
        set_current(self.ctx);
        self.settle_focus();
        let handled = false;
        match e {
            Event::Resize(c, r) => {
                self.resize(c, r);
                handled = true;
            },
            Event::Mouse(m) => {
                handled = self.route_mouse(m, e);
            },
            Event::Key(_) => {
                handled = self.bubble(self.focus_path(), e) || self.keys_fallback(e);
            },
            default => {
                handled = self.bubble(self.focus_path(), e);
            },
        }
        self.apply_requests();
        self.settle_focus();
        if handled {
            self.dirty = true;
        }
        return handled;
    }

    /// Advance the clock to `now` ms and run the timers that are due.
    pub fn tick(int now) {
        set_current(self.ctx);
        self.ctx.now = now;
        let due: Vec<Timer> = Vec::new();
        let keep: Vec<Timer> = Vec::new();
        for t in self.ctx.timers {
            if t.cancelled {
                continue;
            }
            if t.due <= now {
                due.push(t);
                if t.every > 0 {
                    t.due = t.due + t.every * (1 + (now - t.due) / t.every);
                    keep.push(t);
                }
            } else {
                keep.push(t);
            }
        }
        self.ctx.timers = keep;
        for t in due {
            if !t.cancelled {
                let f = t.f;
                self.ctx.current = Option::None;
                f(self.ctx);
                self.dirty = true;
            }
        }
        self.apply_requests();
        self.settle_focus();
    }

    /// Milliseconds until the next timer from `now` (-1 = none), for a
    /// runner's read timeout.
    pub fn wait_ms(int now) -> int {
        return match self.ctx.next_due() {
            Option::Some(d) => {
                if d <= now {
                    return 0;
                }
                return d - now;
            },
            Option::None => -1,
        };
    }

    /// Whether the next `draw` has anything to do.
    pub fn needs_draw() -> bool {
        return self.dirty;
    }

    /// Lay out and paint every layer, and return the escapes that bring
    /// the terminal up to date ("" when nothing changed).
    pub fn draw() -> string {
        if !self.dirty {
            return "";
        }
        self.dirty = false;
        set_current(self.ctx);
        self.settle_focus();
        let buf = self.screen.frame();
        let f = frame(buf);
        let whole = canvas(f);
        for layer in self.layers {
            paint(layer, whole);
        }
        self.ctx.current = Option::None;
        self.last = buf;
        let out = self.screen.present();
        if f.has_cursor {
            if !self.cursor_on ||
               out != "" ||
               self.cursor_x != f.cursor_x ||
               self.cursor_y != f.cursor_y {
                out = out + format("\e[%i;%iH\e[?25h", f.cursor_y + 1, f.cursor_x + 1);
            }
            self.cursor_on = true;
            self.cursor_x = f.cursor_x;
            self.cursor_y = f.cursor_y;
        } else if self.cursor_on || self.cursor_x == -1 {
            out = out + "\e[?25l";
            self.cursor_on = false;
            self.cursor_x = -2;
        }
        return out;
    }

    /// Where the last frame put the cursor, if it is shown.
    pub fn cursor() -> Option<(int, int)> {
        if self.cursor_on {
            return Option::Some((self.cursor_x, self.cursor_y));
        }
        return Option::None;
    }
}
