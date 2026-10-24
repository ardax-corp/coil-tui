use tests::assert;
use cell::Ref;
use tui::node::Node;
use tui::geom::Align;
use tui::testing::Harness;
use tui::testing::harness;
use tui::widgets::layout::row;
use tui::widgets::layout::column;
use tui::widgets::layout::stack;
use tui::widgets::layout::pad;
use tui::widgets::layout::center;
use tui::widgets::layout::align;
use tui::widgets::layout::spacer;
use tui::widgets::layout::block;
use tui::widgets::layout::flex;
use tui::widgets::layout::Block;
use tui::widgets::text::text;
use tui::widgets::text::text_fn;
use tui::widgets::text::rule;
use tui::widgets::text::Text;
use tui::node::mount;

test("column stacks auto-sized text and gives the rest to a spacer") {
    let h = harness(column([text("one"), text("two"), spacer(), text("end")]), 5, 5);
    assert!(h.text() == "one  \ntwo  \n     \n     \nend  ");
}

test("row with fixed, auto and fill children") {
    let h = harness(row([text("ab").fixed(4), text("cd"), text("ef").fill(1)]), 10, 1);
    assert!(h.row(0) == "ab  cdef  ");
}

test("percent widths and gaps") {
    let f = flex(true).spaced(1);
    f.add(text("x").percent(50));
    f.add(text("y").fill(1));
    let h = harness(mount(f), 11, 1);
    assert!(h.row(0) == "x     y    ");
}

test("hidden children take no space") {
    let mid = text("mid");
    let h = harness(column([text("a"), mid, text("b")]), 3, 3);
    assert!(h.text() == "a  \nmid\nb  ");
    mid.hidden(true);
    h.app.invalidate();
    h.draw();
    assert!(h.text() == "a  \nb  \n   ");
}

test("block draws a border and title around its child") {
    let h = harness(block("Hi", text("body")), 10, 3);
    assert!(h.text() == "┌ Hi ────┐\n│body    │\n└────────┘");
}

test("block measures to content inside a column") {
    let h = harness(column([block("", text("x")), text("after")]), 6, 5);
    assert!(h.text() == "┌────┐\n│x   │\n└────┘\nafter \n      ");
}

test("padding and centring") {
    let p = harness(pad(1, 2, text("x")), 5, 3);
    assert!(p.text() == "     \n  x  \n     ");
    let c = harness(center(text("ab")), 6, 3);
    assert!(c.text() == "      \n  ab  \n      ");
    let e = harness(align(Align::End, Align::End, text("ab")), 4, 2);
    assert!(e.text() == "    \n  ab");
}

test("stack paints later children on top") {
    let h = harness(stack([text("aaaa"), text("bb")]), 4, 1);
    assert!(h.row(0) == "bbaa");
}

test("text wraps, aligns and follows its source") {
    let w = harness(text("the quick brown fox"), 9, 3);
    assert!(w.text() == "the quick\nbrown fox\n         ");
    let a = harness(mount(Text::new("hi").aligned(Align::End)), 5, 1);
    assert!(a.row(0) == "   hi");
    let n = harness(mount(Text::new("abcdefgh").nowrap()), 5, 1);
    assert!(n.row(0) == "abcd…");
    let src = Ref::new("v1");
    let d = harness(text_fn(fn () use (src) => src.get()), 4, 1);
    assert!(d.row(0) == "v1  ");
    src.set("v2");
    d.app.invalidate();
    d.draw();
    assert!(d.row(0) == "v2  ");
}

test("rules") {
    let h = harness(column([rule(""), rule("Log")]), 8, 2);
    assert!(h.text() == "────────\n─ Log ──");
}

test("rounded, padded block with a centred title") {
    let b = Block::new("T", text("x")).rounded().padded(1).title_at(Align::Center);
    let h = harness(mount(b), 7, 5);
    assert!(
        h.text() == "╭─ T ─╮\n│     │\n│ x   │\n│     │\n╰─────╯",
    );
}
