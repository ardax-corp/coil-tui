use tests::assert;
use tui::node::Component;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::node::ctx;
use tui::node::set_current;
use tui::canvas::Canvas;
use tui::canvas::canvas;
use tui::canvas::frame;
use tui::geom::Rect;
use tui::geom::Size;
use tui::geom::rect;
use tui::layout::Constraint;
use cli::screen::buffer;
use cli::style::plain;
use cli::keys::Event;
use cli::keys::Key;
use cli::keys::key;

class Label {
    pub text: string,
    pub hits: int,
}

impl Component for Label {
    fn render(Label l, Canvas cv, Ctx ctx) {
        cv.put(0, 0, l.text, plain());
    }

    fn handle(Label l, Event e, Ctx ctx) -> bool {
        l.hits++;
        return true;
    }

    fn constraint(Label l) -> Constraint {
        return Constraint::Fixed(1);
    }
}

test("mount forwards to the component") {
    let l = new Label("hi", 0);
    let n = mount(l);
    let c = ctx();
    set_current(c);
    let cv = canvas(frame(buffer(4, 1)));
    n.render(cv);
    assert!(cv.frame.buf.row_text(0) == "hi  ");
    assert!(n.handle(key(Key::Enter, 0)));
    assert!(l.hits == 1);
    assert!(!n.can_focus());
    assert!(n.children().len() == 0);
    let m = n.measure(new Size(3, 3));
    assert!(m.w == 3);
    let fixed = match n.constraint {
        Constraint::Fixed(k) => k,
        default => -1,
    };
    assert!(fixed == 1);
    let nn = n.named("x").percent(50).hidden(true);
    assert!(nn.id == "x");
    assert!(!nn.visible);
}

test("timers and focus helpers") {
    let c = ctx();
    let a = mount(new Label("a", 0));
    assert!(!c.has_focus());
    c.focused = Option::Some(a);
    c.current = Option::Some(a);
    assert!(c.has_focus());
    assert!(c.is_focused(a));
    assert!(c.next_due() == Option::None);
    c.now = 100;
    let t1 = c.after(50, fn (Ctx x) {
        x.quit();
    });
    let t2 = c.every(20, fn (Ctx x) {
        x.redraw();
    });
    assert!(c.next_due() == Option::Some(120));
    c.cancel(t2);
    assert!(c.next_due() == Option::Some(150));
    assert!(t1 != t2);
}
