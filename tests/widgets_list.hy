use tests::assert;
use cell::Ref;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::testing::Harness;
use tui::testing::harness;
use tui::layout::Constraint;
use tui::geom::Align;
use tui::widgets::layout::column;
use tui::widgets::input::button;
use tui::widgets::list::List;
use tui::widgets::list::Table;
use tui::widgets::list::TableColumn;
use tui::widgets::list::Selection;
use tui::widgets::list::list;
use tui::widgets::list::table_column;
use tui::widgets::list::selection;

fn items(int n) -> Vec<string> {
    let out: Vec<string> = Vec::new();
    let i = 0;
    while i < n {
        out.push("item " + show(i));
        i++;
    }
    return out;
}

test("selection keeps the cursor in view") {
    let s = selection();
    s.key("end", 10, 3);
    assert!(s.selected == 9);
    assert!(s.offset == 7);
    s.key("pageup", 10, 3);
    assert!(s.selected == 7);
    s.key("up", 10, 3);
    assert!(s.offset == 6);
    s.scroll(-10, 10, 3);
    assert!(s.offset == 0);
    assert!(s.selected == 2);
    assert!(!s.key("x", 10, 3));
    s.fit(0, 3);
    assert!(s.selected == 0);
}

test("list moves, scrolls and reports") {
    let l = list(items(5)).marked("> ");
    let seen = Ref::new(-1);
    let act = Ref::new(-1);
    l
        .on_select(fn (int i, Ctx c) use (seen) {
            seen.set(i);
        })
        .on_activate(fn (int i, Ctx c) use (act) {
            act.set(i);
        });
    let h = harness(mount(l), 10, 3);
    assert!(h.text() == "> item 0 ┃\n  item 1 │\n  item 2 │");
    h.keys("down down down");
    assert!(seen.get() == 3);
    assert!(h.text() == "  item 1 │\n  item 2 ┃\n> item 3 │");
    h.key("enter");
    assert!(act.get() == 3);
    assert!(l.value() == "item 3");
    h.wheel(0, 0, true);
    assert!(l.sel.offset == 0);
    assert!(l.selected() == 2);
    h.click(0, 0);
    assert!(l.selected() == 0);
    h.click(0, 0);
    assert!(act.get() == 0);
}

test("list highlights the selected row differently without focus") {
    let l = list(items(2));
    let h = harness(column([mount(l).fixed(2), button("b", fn (Ctx c) {})]), 6, 3);
    assert!(h.cell(0, 0).style.eq(h.app.ctx.theme.selection));
    h.key("tab");
    assert!(h.cell(0, 0).style.eq(h.app.ctx.theme.selection_unfocused));
    assert!(h.cell(0, 1).style.eq(h.app.ctx.theme.text));
}

test("table columns, header and selection") {
    let cols: Vec<TableColumn> = [
        table_column("Name", Constraint::Auto),
        new TableColumn("Size", Constraint::Fixed(5), Align::End),
        table_column("Note", Constraint::Fill(1)),
    ];
    let rows: Vec<Vec<string>> = [["a.txt", "12", "hello"], ["bb.md", "3400", "world"]];
    let t = Table::new(cols, rows);
    let picked = Ref::new(-1);
    t.on_select(fn (int i, Ctx c) use (picked) {
        picked.set(i);
    });
    let h = harness(mount(t), 20, 3);
    assert!(h.text() == "Name   Size Note    \na.txt    12 hello   \nbb.md  3400 world   ");
    h.key("down");
    assert!(picked.get() == 1);
    h.click(0, 1);
    assert!(t.selected() == 0);
    assert!(picked.get() == 0);
}
