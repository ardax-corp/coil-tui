// Dialogs and popup menus, opened as layers.
use cli::keys::Event;
use cli::keys::describe_key;
use cli::screen::rounded_box;
use cli::width::width;
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::Align;
use tui::geom::rect;
use tui::geom::size;
use tui::geom::imax;
use tui::geom::imin;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::widgets::layout::Block;
use tui::widgets::layout::Flex;
use tui::widgets::layout::row;
use tui::widgets::layout::column;
use tui::widgets::layout::spacer;
use tui::widgets::text::text;
use tui::widgets::input::button;
use tui::widgets::list::List;

/// A box drawn on top of the layers below: its area is cleared, it is
/// centred (or placed at `x`, `y` when `at` is set) at its measured
/// size, and Esc closes it.
class Popup {
    pub child: Node,
    pub kids: Vec<Node>,
    pub at: bool,
    pub x: int,
    pub y: int,
    pub on_close: fn(Ctx) -> (),
}

impl Popup {
    pub static fn new(Node child) -> Popup {
        let kids: Vec<Node> = Vec::new();
        kids.push(child);
        return new Popup(child, kids, false, 0, 0, fn (Ctx c) {});
    }

    pub fn place(Rect area) -> Rect {
        let m = self.child.measure(area.size());
        if self.at {
            let x = imax(0, imin(self.x, area.w - m.w));
            let y = imax(0, imin(self.y, area.h - m.h));
            return rect(x, y, m.w, m.h);
        }
        return area.place(m.w, m.h, Align::Center, Align::Center);
    }
}

impl Component for Popup {
    fn render(Popup p, Canvas cv, Ctx ctx) {
        let r = p.place(cv.bounds());
        cv.fill(r.x, r.y, r.w, r.h, " ", ctx.theme.text);
    }

    fn children(Popup p) -> Vec<Node> {
        return p.kids;
    }

    fn arrange(Popup p, Rect area) -> Vec<Rect> {
        let out: Vec<Rect> = Vec::new();
        out.push(p.place(area));
        return out;
    }

    fn handle(Popup p, Event e, Ctx ctx) -> bool {
        return match e {
            Event::Key(k) => {
                if describe_key(k) == "esc" {
                    ctx.pop_layer();
                    let f = p.on_close;
                    f(ctx);
                    return true;
                }
                return false;
            },
            // Clicks outside the box land here: swallow them.
            Event::Mouse(_) => true,
            default => false,
        };
    }
}

/// A titled, bordered dialog: `body` above a row of `buttons` (right
/// aligned). Open it with `ctx.push_layer(...)`; buttons usually call
/// `ctx.pop_layer()`.
fn dialog(string title, Node body, Vec<Node> buttons) -> Node {
    let bar: Vec<Node> = Vec::new();
    bar.push(spacer());
    for b in buttons {
        bar.push(b);
    }
    let f = Flex::new(true, bar);
    f.gap = 1;
    let inner = column([body, mount(f).fixed(1)]);
    let b = Block::new(title, inner).padded(1);
    b.chars = rounded_box();
    return mount(Popup::new(mount(b)));
}

/// Open a message box with an OK button.
fn alert(Ctx ctx, string title, string message) {
    ctx.push_layer(
        dialog(
            title,
            text(message),
            [button("OK", fn (Ctx c) {
                c.pop_layer();
            })],
        ),
    );
}

/// Ask a yes/no question; `answer` gets true for Yes, false for No or
/// Esc.
fn confirm(Ctx ctx, string title, string message, fn(bool, Ctx) -> () answer) {
    let d = dialog(
        title,
        text(message),
        [
            button(
                "Yes",
                fn (Ctx c) use (answer) {
                    c.pop_layer();
                    answer(true, c);
                },
            ),
            button(
                "No",
                fn (Ctx c) use (answer) {
                    c.pop_layer();
                    answer(false, c);
                },
            ),
        ],
    );
    ctx.push_layer(d);
}

/// Open a popup menu at (`x`, `y`): Enter or a click on an item closes
/// it and calls `pick` with the item's index; Esc closes it.
fn menu(Ctx ctx, int x, int y, Vec<string> items, fn(int, Ctx) -> () pick) {
    let l = List::new(items);
    l.on_activate(fn (int i, Ctx c) use (pick) {
        c.pop_layer();
        pick(i, c);
    });
    let b = Block::new("", mount(l));
    let p = Popup::new(mount(b));
    p.at = true;
    p.x = x;
    p.y = y;
    ctx.push_layer(mount(p));
}
