use tests::assert;
use cell::Ref;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::canvas::Canvas;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::rect;
use tui::layout::Constraint;
use tui::layout::split;
use tui::layout::stack_rects;
use tui::testing::Harness;
use tui::testing::harness;
use tui::testing::parse_key;
use tui::geom::Align;
use cli::keys::Event;
use cli::keys::Key;
use cli::keys::describe;
use cli::style::plain;
use cli::width::width;

// A focusable box that shows its name and counts keys it takes.
class Field {
    pub name: string,
    pub keys: int,
    pub cursor: bool,
}

impl Component for Field {
    fn render(Field f, Canvas cv, Ctx ctx) {
        let mark = " ";
        if ctx.has_focus() {
            mark = ">";
        }
        cv.put(0, 0, mark + f.name, plain());
        if f.cursor && ctx.has_focus() {
            cv.cursor(1, 0);
        }
    }

    fn focusable(Field f) -> bool {
        return true;
    }

    fn handle(Field f, Event e, Ctx ctx) -> bool {
        return match e {
            Event::Key(k) => {
                if k.char() != Option::None {
                    f.keys++;
                    return true;
                }
                return false;
            },
            Event::Mouse(_) => true,
            default => false,
        };
    }

    fn constraint(Field f) -> Constraint {
        return Constraint::Fixed(1);
    }
}

fn field(string name) -> Node {
    return mount(new Field(name, 0, false)).named(name);
}

// A vertical stack of children, for the tests.
class Col {
    pub kids: Vec<Node>,
    pub enters: int,
}

impl Component for Col {
    fn render(Col c, Canvas cv, Ctx ctx) {}

    fn children(Col c) -> Vec<Node> {
        return c.kids;
    }

    fn arrange(Col c, Rect area) -> Vec<Rect> {
        let cs: Vec<Constraint> = Vec::new();
        for k in c.kids {
            cs.push(k.constraint);
        }
        let sizes = split(area.h, cs, Vec::new(), 0);
        return stack_rects(area, false, sizes, 0, Vec::new(), Align::Stretch);
    }

    fn handle(Col c, Event e, Ctx ctx) -> bool {
        return match e {
            Event::Key(k) => {
                if k.key == Key::Enter {
                    c.enters++;
                    ctx.focus_next();
                    return true;
                }
                return false;
            },
            default => false,
        };
    }
}

fn col(Vec<Node> kids) -> Col {
    return new Col(kids, 0);
}

fn three() -> Vec<Node> {
    let kids: Vec<Node> = Vec::new();
    kids.push(field("a"));
    kids.push(field("b"));
    kids.push(field("c"));
    return kids;
}

test("parse_key round-trips describe") {
    assert!(describe(parse_key("ctrl+c")) == "ctrl+c");
    assert!(describe(parse_key("shift+tab")) == "shift+tab");
    assert!(describe(parse_key("f12")) == "f12");
    assert!(describe(parse_key("space")) == "space");
    assert!(describe(parse_key("x")) == "x");
    assert!(describe(parse_key("alt+enter")) == "alt+enter");
}

test("first draw paints, focuses the first field and then idles") {
    let h = harness(mount(col(three())), 6, 4);
    assert!(h.text() == ">a    \n b    \n c    \n      ");
    assert!(h.focused_id() == "a");
    assert!(h.draw() == "");
}

test("tab and shift-tab move focus, wrapping") {
    let h = harness(mount(col(three())), 6, 3);
    h.key("tab");
    assert!(h.focused_id() == "b");
    assert!(h.row(1) == ">b    ");
    h.keys("tab tab");
    assert!(h.focused_id() == "a");
    h.key("shift+tab");
    assert!(h.focused_id() == "c");
}

test("keys go to the focused node and bubble to its parents") {
    let c = col(three());
    let h = harness(mount(c), 6, 3);
    h.type_text("xy");
    let a = h.app.find("a");
    assert!(a != Option::None);
    h.key("enter");
    assert!(c.enters == 1);
    assert!(h.focused_id() == "b");
}

test("hidden and disabled nodes leave the focus chain") {
    let kids = three();
    let h = harness(mount(col(kids)), 6, 3);
    kids[1].hidden(true);
    kids[2].enabled(false);
    h.key("tab");
    assert!(h.focused_id() == "a");
    kids[0].hidden(true);
    h.app.invalidate();
    h.draw();
    assert!(h.focused_id() == "");
    kids[2].enabled(true);
    h.key("tab");
    assert!(h.focused_id() == "c");
}

test("clicks focus the node under the pointer") {
    let h = harness(mount(col(three())), 6, 3);
    h.click(2, 2);
    assert!(h.focused_id() == "c");
    h.click(0, 1);
    assert!(h.focused_id() == "b");
}

test("bindings, ctrl+c and quitting") {
    let h = harness(mount(col(three())), 6, 3);
    let hits = Ref::new(0);
    h
        .app
        .bind(
            "ctrl+q",
            fn (Ctx x) use (hits) {
                hits.set(hits.get() + 1);
                x.quit();
            },
        );
    assert!(!h.key("f5"));
    assert!(h.app.running);
    h.key("ctrl+q");
    assert!(hits.get() == 1);
    assert!(!h.app.running);
    let g = harness(mount(col(three())), 6, 3);
    g.key("ctrl+c");
    assert!(!g.app.running);
}

test("layers take the keyboard and give focus back") {
    let base = col(three());
    let h = harness(mount(base), 8, 3);
    h.key("tab");
    let pop: Vec<Node> = Vec::new();
    pop.push(field("p"));
    pop.push(field("q"));
    h.app.push_layer(mount(col(pop)));
    h.draw();
    assert!(h.focused_id() == "p");
    assert!(h.row(0) == ">p      ");
    assert!(h.row(2) == " c      ");
    h.keys("tab tab tab");
    assert!(h.focused_id() == "q");
    h.app.pop_layer();
    h.draw();
    assert!(h.focused_id() == "b");
    assert!(h.row(0) == " a      ");
}

test("timers run on tick and repeat") {
    let h = harness(mount(col(three())), 6, 3);
    let n = Ref::new(0);
    let c = h.app.ctx;
    c.every(100, fn (Ctx x) use (n) {
        n.set(n.get() + 1);
    });
    let once = c.after(50, fn (Ctx x) {
        x.focus_next();
    });
    assert!(h.app.wait_ms(0) == 50);
    h.advance(49);
    assert!(n.get() == 0);
    h.advance(1);
    assert!(h.focused_id() == "b");
    h.advance(50);
    assert!(n.get() == 1);
    h.advance(250);
    assert!(n.get() == 2);
    assert!(h.app.wait_ms(h.now) == 50);
}

test("cursor requests show the cursor; otherwise it is hidden") {
    let kids: Vec<Node> = Vec::new();
    kids.push(mount(new Field("a", 0, true)).named("a"));
    kids.push(field("b"));
    let h = harness(mount(col(kids)), 4, 2);
    assert!(h.out.ends_with("\e[1;2H\e[?25h"));
    assert!(h.app.cursor() == Option::Some((1, 0)));
    h.key("tab");
    assert!(h.out.ends_with("\e[?25l"));
    assert!(h.app.cursor() == Option::None);
}

test("resize relayouts") {
    let h = harness(mount(col(three())), 6, 3);
    h.resize(3, 2);
    assert!(h.text() == ">a \n b ");
}
