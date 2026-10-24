use tests::assert;
use cell::Ref;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::testing::Harness;
use tui::testing::harness;
use tui::widgets::layout::column;
use tui::widgets::layout::block;
use tui::widgets::text::text;
use tui::widgets::input::button;
use tui::widgets::input::text_input;
use tui::widgets::scroll::Scroll;
use tui::widgets::scroll::scroll;
use tui::widgets::tabs::Tabs;
use tui::widgets::tabs::tabs;

fn lines(int n) -> Vec<Node> {
    let out: Vec<Node> = Vec::new();
    let i = 0;
    while i < n {
        out.push(text("line " + show(i)));
        i++;
    }
    return out;
}

test("scroll shows a window onto tall content") {
    let s = Scroll::new(column(lines(10)));
    let h = harness(mount(s), 8, 3);
    assert!(h.text() == "line 0 ┃\nline 1 │\nline 2 │");
    h.key("down");
    assert!(h.row(0) == "line 1 ┃");
    h.key("pagedown");
    assert!(s.offset == 3);
    h.key("end");
    assert!(h.row(2) == "line 9 ┃");
    h.wheel(0, 0, true);
    assert!(s.offset == 4);
    h.key("home");
    assert!(s.offset == 0);
}

test("scroll follows focus inside it") {
    let kids = lines(6);
    kids.push(mount(text_input("")).named("deep"));
    let s = Scroll::new(column(kids));
    let h = harness(column([button("top", fn (Ctx c) {}).named("top"), mount(s).fixed(3)]), 10, 4);
    assert!(h.focused_id() == "top");
    h.key("tab");
    assert!(h.focused_id() == "deep");
    assert!(s.offset == 4);
    assert!(h.app.cursor() == Option::Some((0, 3)));
}

test("tabs switch pages") {
    let pages: Vec<Node> = [text("first page"), mount(text_input("x")).named("in")];
    let titles: Vec<string> = ["One", "Two"];
    let t = Tabs::new(titles, pages);
    let changed = Ref::new(-1);
    t.on_change(fn (int i, Ctx c) use (changed) {
        changed.set(i);
    });
    let h = harness(mount(t), 12, 2);
    assert!(h.text() == " One │ Two  \nfirst page  ");
    h.key("right");
    assert!(changed.get() == 1);
    assert!(h.row(1) == "x           ");
    h.key("tab");
    assert!(h.focused_id() == "in");
    h.key("ctrl+pageup");
    assert!(t.active == 0);
    assert!(h.focused_id() != "in");
    h.click(8, 0);
    assert!(t.active == 1);
}
