use tests::assert;
use cell::Ref;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::testing::Harness;
use tui::testing::harness;
use tui::widgets::layout::column;
use tui::widgets::text::text;
use tui::widgets::input::button;
use tui::widgets::status::Gauge;
use tui::widgets::status::Spinner;
use tui::widgets::status::KeyHints;
use tui::widgets::status::gauge;
use tui::widgets::status::spinner;
use tui::widgets::status::key_hints;
use tui::widgets::dialog::dialog;
use tui::widgets::dialog::alert;
use tui::widgets::dialog::confirm;
use tui::widgets::dialog::menu;

test("gauge fills by eighths and labels the percentage") {
    let g = gauge(1, 4);
    let h = harness(mount(g), 12, 1);
    assert!(h.row(0) == "██       25%");
    g.set(4);
    h.app.invalidate();
    h.draw();
    assert!(h.row(0) == "███████ 100%");
}

test("spinner ticks on timers and stops") {
    let s = spinner("Loading");
    let h = harness(mount(s), 10, 1);
    assert!(h.row(0) == "⠋ Loading ");
    h.advance(80);
    assert!(h.row(0) == "⠙ Loading ");
    h.advance(160);
    // One frame per tick, however late the tick: no catch-up bursts.
    assert!(s.frame == 2);
    s.stop(h.app.ctx);
    h.advance(400);
    assert!(h.row(0) == "Loading   ");
    assert!(h.app.wait_ms(h.now) == -1);
}

test("key hints") {
    let h = harness(mount(key_hints().add("q", "quit").add("^S", "save")), 16, 1);
    assert!(h.row(0) == "q quit  ^S save ");
}

test("alert opens on top and closes with its button or esc") {
    let opener = button("Open", fn (Ctx c) {
        alert(c, "Note", "Saved");
    }).named("open");
    let h = harness(column([opener]), 20, 9);
    h.key("enter");
    assert!(h.app.layer_count() == 2);
    assert!(
        h.text() == "[ Open ]            \n    ╭ Note ───╮     \n    │         │     \n    │ Saved   │     \n    │  [ OK ] │     \n    │         │     \n    ╰─────────╯     \n                    \n                    ",
    );
    h.key("enter");
    assert!(h.app.layer_count() == 1);
    assert!(h.focused_id() == "open");
    h.key("enter");
    h.key("esc");
    assert!(h.app.layer_count() == 1);
}

test("confirm answers yes or no") {
    let ans = Ref::new(0);
    let opener = button(
        "Ask",
        fn (Ctx c) use (ans) {
            confirm(
                c,
                "Sure?",
                "Delete it",
                fn (bool yes, Ctx x) use (ans) {
                    if yes {
                        ans.set(1);
                    } else {
                        ans.set(2);
                    }
                },
            );
        },
    );
    let h = harness(column([opener]), 24, 9);
    h.key("enter");
    h.key("enter");
    assert!(ans.get() == 1);
    h.key("enter");
    h.keys("tab enter");
    assert!(ans.get() == 2);
    assert!(h.app.layer_count() == 1);
}

test("menu picks an item") {
    let got = Ref::new(-1);
    let opener = button(
        "Menu",
        fn (Ctx c) use (got) {
            let items: Vec<string> = ["Open", "Save", "Quit"];
            menu(
                c,
                2,
                1,
                items,
                fn (int i, Ctx x) use (got) {
                    got.set(i);
                },
            );
        },
    );
    let h = harness(column([opener]), 12, 6);
    h.key("enter");
    assert!(h.row(1) == "  ┌─────┐   ");
    assert!(h.row(2) == "  │Open │   ");
    h.keys("down enter");
    assert!(got.get() == 1);
    assert!(h.app.layer_count() == 1);
}
