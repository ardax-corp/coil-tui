use tests::assert;
use cell::Ref;
use text::Searchable;
use tui::node::Node;
use tui::node::Ctx;
use tui::node::mount;
use tui::testing::Harness;
use tui::testing::harness;
use tui::widgets::layout::row;
use tui::widgets::layout::column;
use tui::widgets::text::text;
use tui::widgets::input::Button;
use tui::widgets::input::Checkbox;
use tui::widgets::input::RadioGroup;
use tui::widgets::input::TextInput;
use tui::widgets::input::button;
use tui::widgets::input::checkbox;
use tui::widgets::input::radio_group;
use tui::widgets::input::text_input;

test("buttons press on enter, space and click") {
    let n = Ref::new(0);
    let h = harness(button("OK", fn (Ctx c) use (n) {
        n.set(n.get() + 1);
    }), 8, 1);
    assert!(h.row(0) == "[ OK ]  ");
    h.key("enter");
    h.key("space");
    h.click(1, 0);
    assert!(n.get() == 3);
    assert!(!h.key("x"));
}

test("checkbox toggles and reports") {
    let last = Ref::new(false);
    let h = harness(
        checkbox("Agree", false, fn (bool v, Ctx c) use (last) {
            last.set(v);
        }),
        10,
        1,
    );
    assert!(h.row(0) == "[ ] Agree ");
    h.key("space");
    assert!(h.row(0) == "[x] Agree ");
    assert!(last.get());
    h.click(0, 0);
    assert!(h.row(0) == "[ ] Agree ");
    assert!(!last.get());
}

test("radio group moves with arrows and clicks") {
    let colours: Vec<string> = ["red", "green", "blue"];
    let r = RadioGroup::new(colours, 0);
    let picked = Ref::new(-1);
    r.on_change(fn (int i, Ctx c) use (picked) {
        picked.set(i);
    });
    let h = harness(mount(r), 9, 3);
    assert!(h.text() == "(•) red  \n( ) green\n( ) blue ");
    h.key("down");
    assert!(r.value() == "green");
    assert!(picked.get() == 1);
    assert!(h.key("end"));
    assert!(!h.key("down"));
    assert!(r.selected == 2);
    h.click(1, 0);
    assert!(r.value() == "red");
    assert!(h.row(0) == "(•) red  ");
}

test("text input edits, shows the cursor and reports changes") {
    let t = text_input("name");
    let changes = Ref::new(0);
    let submitted = Ref::new("");
    t
        .on_change(
            fn (string s, Ctx c) use (changes) {
                changes.set(changes.get() + 1);
            },
        )
        .on_submit(fn (string s, Ctx c) use (submitted) {
            submitted.set(s);
        });
    let h = harness(mount(t), 8, 1);
    assert!(h.row(0) == "name    ");
    assert!(h.app.cursor() == Option::Some((0, 0)));
    h.type_text("hello");
    assert!(h.row(0) == "hello   ");
    assert!(h.app.cursor() == Option::Some((5, 0)));
    h.keys("left left backspace");
    assert!(t.value() == "helo");
    assert!(changes.get() == 6);
    h.key("enter");
    assert!(submitted.get() == "helo");
    assert!(t.value() == "helo");
    h.paste(" world");
    assert!(t.value() == "he worldlo");
}

test("text input scrolls and masks") {
    let t = text_input("").masked("*");
    let h = harness(mount(t), 4, 1);
    h.type_text("secret");
    assert!(h.row(0) == "*** ");
    assert!(t.value() == "secret");
}

test("tab leaves a text input; clear on submit") {
    let a = text_input("").clearing();
    let got = Ref::new("");
    a.on_submit(fn (string s, Ctx c) use (got) {
        got.set(s);
    });
    let h = harness(column([mount(a).named("a"), mount(text_input("")).named("b")]), 6, 2);
    h.type_text("x");
    h.key("enter");
    assert!(got.get() == "x");
    assert!(a.value() == "");
    h.key("tab");
    assert!(h.focused_id() == "b");
    h.key("ctrl+c");
    assert!(!h.app.running);
}

test("a small form") {
    let name = text_input("Name");
    let agree = Checkbox::new("Subscribe", false);
    let sent = Ref::new("");
    let form = column(
        [
            row([text("Name: ").fixed(6), mount(name).fill(1)]),
            mount(agree),
            button(
                "Send",
                fn (Ctx c) use (name, agree, sent) {
                    let s = name.value();
                    if agree.checked {
                        s = s + "+";
                    }
                    sent.set(s);
                    c.quit();
                },
            ),
        ],
    );
    let h = harness(form, 16, 3);
    assert!(h.text() == "Name: Name      \n[ ] Subscribe   \n[ Send ]        ");
    h.type_text("Ada");
    h.keys("tab space tab enter");
    assert!(sent.get() == "Ada+");
    assert!(!h.app.running);
}
